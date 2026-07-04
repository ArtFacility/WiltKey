package main

// Firebase Cloud Messaging sender for the Play-flavor "wake-up ping".
//
// This is a *dumb pipe*: the relay sends a content-free, data-only high-priority
// message carrying at most the sender's key hash (so the client can deep-link).
// No message content ever passes through Google — the encrypted payload stays
// queued on the relay until the client connects and pulls it. The whole thing is
// implemented against the stdlib (service-account JWT -> OAuth2 access token ->
// FCM HTTP v1) so the relay pulls in NO new third-party dependencies.
//
// Configuration is a single env var, FCM_CREDENTIALS_FILE, pointing at a Firebase
// service-account JSON. When it's unset or unreadable the sender is disabled and
// every Send() is a silent no-op, so the FOSS/self-hosted relay runs unchanged.

import (
	"bytes"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

// errTokenUnregistered signals that FCM rejected the token as gone (app
// uninstalled / token rotated). The caller drops it from Redis so we stop trying.
var errTokenUnregistered = errors.New("fcm token unregistered")

const fcmScope = "https://www.googleapis.com/auth/firebase.messaging"

type serviceAccount struct {
	ProjectID   string `json:"project_id"`
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
	TokenURI    string `json:"token_uri"`
}

// PushSender holds the parsed service account + a cached OAuth2 access token.
type PushSender struct {
	enabled    bool
	sa         serviceAccount
	privKey    *rsa.PrivateKey
	httpClient *http.Client

	mu          sync.Mutex
	accessToken string
	tokenExpiry time.Time
}

// NewPushSender loads FCM credentials from FCM_CREDENTIALS_FILE. Any problem
// (unset var, missing file, bad JSON, bad key) logs a warning and returns a
// disabled sender — the relay keeps working, it just can't send wake-up pings.
func NewPushSender() *PushSender {
	path := strings.TrimSpace(os.Getenv("FCM_CREDENTIALS_FILE"))
	if path == "" {
		log.Printf("[Push] FCM_CREDENTIALS_FILE not set — FCM wake-up push disabled (FOSS/self-hosted mode).")
		return &PushSender{enabled: false}
	}

	raw, err := os.ReadFile(path)
	if err != nil {
		log.Printf("[Push] Could not read FCM_CREDENTIALS_FILE %q: %v — push disabled.", path, err)
		return &PushSender{enabled: false}
	}

	var sa serviceAccount
	if err := json.Unmarshal(raw, &sa); err != nil {
		log.Printf("[Push] Malformed service-account JSON: %v — push disabled.", err)
		return &PushSender{enabled: false}
	}
	if sa.ProjectID == "" || sa.ClientEmail == "" || sa.PrivateKey == "" {
		log.Printf("[Push] Service-account JSON missing project_id/client_email/private_key — push disabled.")
		return &PushSender{enabled: false}
	}
	if sa.TokenURI == "" {
		sa.TokenURI = "https://oauth2.googleapis.com/token"
	}

	key, err := parseRSAPrivateKey(sa.PrivateKey)
	if err != nil {
		log.Printf("[Push] Could not parse service-account private key: %v — push disabled.", err)
		return &PushSender{enabled: false}
	}

	log.Printf("[Push] FCM wake-up push enabled for project %s.", sa.ProjectID)
	return &PushSender{
		enabled:    true,
		sa:         sa,
		privKey:    key,
		httpClient: &http.Client{Timeout: 15 * time.Second},
	}
}

// Enabled reports whether wake-up pushes can be sent.
func (p *PushSender) Enabled() bool { return p != nil && p.enabled }

func parseRSAPrivateKey(pemStr string) (*rsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		return nil, errors.New("no PEM block found")
	}
	// Google service accounts ship PKCS#8 ("PRIVATE KEY"); fall back to PKCS#1.
	if k, err := x509.ParsePKCS8PrivateKey(block.Bytes); err == nil {
		if rsaKey, ok := k.(*rsa.PrivateKey); ok {
			return rsaKey, nil
		}
		return nil, errors.New("service-account key is not RSA")
	}
	return x509.ParsePKCS1PrivateKey(block.Bytes)
}

// getAccessToken returns a cached OAuth2 access token, minting a fresh one via a
// signed JWT assertion when the cache is empty or near expiry.
func (p *PushSender) getAccessToken() (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.accessToken != "" && time.Now().Before(p.tokenExpiry) {
		return p.accessToken, nil
	}

	now := time.Now()
	header := base64URL(`{"alg":"RS256","typ":"JWT"}`)
	claims := base64URL(fmt.Sprintf(
		`{"iss":%q,"scope":%q,"aud":%q,"iat":%d,"exp":%d}`,
		p.sa.ClientEmail, fcmScope, p.sa.TokenURI, now.Unix(), now.Add(time.Hour).Unix(),
	))
	signingInput := header + "." + claims

	hashed := sha256.Sum256([]byte(signingInput))
	sig, err := rsa.SignPKCS1v15(rand.Reader, p.privKey, crypto.SHA256, hashed[:])
	if err != nil {
		return "", fmt.Errorf("sign jwt: %w", err)
	}
	assertion := signingInput + "." + base64.RawURLEncoding.EncodeToString(sig)

	form := url.Values{}
	form.Set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer")
	form.Set("assertion", assertion)

	resp, err := p.httpClient.PostForm(p.sa.TokenURI, form)
	if err != nil {
		return "", fmt.Errorf("token request: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("token endpoint status %d: %s", resp.StatusCode, string(body))
	}

	var tok struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int64  `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &tok); err != nil {
		return "", fmt.Errorf("decode token response: %w", err)
	}
	if tok.AccessToken == "" {
		return "", errors.New("empty access token")
	}

	p.accessToken = tok.AccessToken
	// Refresh a minute early to absorb clock skew / round-trips.
	p.tokenExpiry = now.Add(time.Duration(tok.ExpiresIn-60) * time.Second)
	return p.accessToken, nil
}

// Send delivers a content-free, high-priority data ping to one device token.
// [senderID] is the sender's key hash (already a one-way hash, not identity) so
// the client can deep-link; it's the only field that ever reaches Google.
// Returns errTokenUnregistered when the token is dead so the caller can prune it.
func (p *PushSender) Send(token string, senderID string) error {
	if !p.Enabled() {
		return nil
	}

	accessToken, err := p.getAccessToken()
	if err != nil {
		return err
	}

	payload := map[string]any{
		"message": map[string]any{
			"token": token,
			// Data-only (no "notification" key) so the client's own service posts
			// the alert — that keeps the content generic and lets us deep-link.
			"data": map[string]string{
				"sender_id": senderID,
			},
			"android": map[string]any{
				"priority": "HIGH",
			},
		},
	}
	body, _ := json.Marshal(payload)

	endpoint := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", p.sa.ProjectID)
	req, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)

	switch resp.StatusCode {
	case http.StatusOK:
		return nil
	case http.StatusNotFound:
		// 404 == the registration token is no longer valid (app uninstalled etc.).
		return errTokenUnregistered
	default:
		// 400 UNREGISTERED / INVALID_ARGUMENT for a stale token also warrants a prune.
		if strings.Contains(string(respBody), "UNREGISTERED") {
			return errTokenUnregistered
		}
		return fmt.Errorf("fcm send status %d: %s", resp.StatusCode, string(respBody))
	}
}

func base64URL(s string) string {
	return base64.RawURLEncoding.EncodeToString([]byte(s))
}
