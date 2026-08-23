package main

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

const integrityScope = "https://www.googleapis.com/auth/playintegrity"

// Attestation validity duration (7 days)
const kAttestationTTL = 7 * 24 * time.Hour

// Challenge TTL (5 minutes)
const kChallengeTTL = 5 * time.Minute

// PlayIntegrityVerifier resolves and verifies Play Integrity tokens.
type PlayIntegrityVerifier struct {
	enabled     bool
	packageName string
	tokens      *googleTokenSource
	httpClient  *http.Client
	relayPriv   ed25519.PrivateKey
	relayPub    ed25519.PublicKey
}

var playIntegrityVerifier = &PlayIntegrityVerifier{}

// NewPlayIntegrityVerifier initializes the Google Play Integrity verifier.
func NewPlayIntegrityVerifier() *PlayIntegrityVerifier {
	// Initialize relay attestation signing key
	privKeyHex := strings.TrimSpace(os.Getenv("RELAY_ATTESTATION_KEY"))
	var priv ed25519.PrivateKey
	var pub ed25519.PublicKey

	if privKeyHex != "" {
		keyBytes, err := hex.DecodeString(privKeyHex)
		if err == nil && len(keyBytes) == ed25519.PrivateKeySize {
			priv = ed25519.PrivateKey(keyBytes)
			pub = priv.Public().(ed25519.PublicKey)
			log.Printf("[Integrity] Loaded relay attestation signing key: pubkey=%s", hex.EncodeToString(pub))
		} else {
			log.Printf("[Integrity] WARNING: Invalid RELAY_ATTESTATION_KEY format/size — generating ephemeral signing key.")
		}
	}

	if priv == nil {
		var err error
		pub, priv, err = ed25519.GenerateKey(rand.Reader)
		if err != nil {
			log.Fatalf("[Integrity] Failed to generate ephemeral relay key: %v", err)
		}
		log.Printf("[Integrity] Generated ephemeral relay attestation signing key: pubkey=%s", hex.EncodeToString(pub))
	}

	path := strings.TrimSpace(os.Getenv("PLAY_CREDENTIALS_FILE"))
	if path == "" {
		path = strings.TrimSpace(os.Getenv("INTEGRITY_CREDENTIALS_FILE"))
	}

	if path == "" {
		log.Printf("[Integrity] PLAY_CREDENTIALS_FILE / INTEGRITY_CREDENTIALS_FILE not set — Play Integrity verification DISABLED (self-hosted mode).")
		return &PlayIntegrityVerifier{
			relayPriv: priv,
			relayPub:  pub,
		}
	}

	pkg := strings.TrimSpace(os.Getenv("PLAY_PACKAGE_NAME"))
	if pkg == "" {
		pkg = "xyz.artfacility.wiltkey"
	}

	raw, err := os.ReadFile(path)
	if err != nil {
		log.Printf("[Integrity] Cannot read credentials at %s: %v — Play Integrity verification DISABLED.", path, err)
		return &PlayIntegrityVerifier{
			relayPriv: priv,
			relayPub:  pub,
		}
	}

	var sa serviceAccount
	if err := json.Unmarshal(raw, &sa); err != nil {
		log.Printf("[Integrity] Malformed service-account JSON: %v — verification disabled.", err)
		return &PlayIntegrityVerifier{relayPriv: priv, relayPub: pub}
	}
	if sa.ClientEmail == "" || sa.PrivateKey == "" {
		log.Printf("[Integrity] Service-account JSON missing client_email/private_key — verification disabled.")
		return &PlayIntegrityVerifier{relayPriv: priv, relayPub: pub}
	}
	if sa.TokenURI == "" {
		sa.TokenURI = "https://oauth2.googleapis.com/token"
	}

	key, err := parseRSAPrivateKey(sa.PrivateKey)
	if err != nil {
		log.Printf("[Integrity] Could not parse service-account private key: %v — verification disabled.", err)
		return &PlayIntegrityVerifier{relayPriv: priv, relayPub: pub}
	}

	ts := &googleTokenSource{
		sa:         sa,
		privKey:    key,
		scope:      integrityScope,
		httpClient: &http.Client{Timeout: 15 * time.Second},
	}

	log.Printf("[Integrity] Google Play Integrity verification ENABLED for package %s (service account %s)", pkg, ts.sa.ClientEmail)
	return &PlayIntegrityVerifier{
		enabled:     true,
		packageName: pkg,
		tokens:      ts,
		httpClient:  &http.Client{Timeout: 15 * time.Second},
		relayPriv:   priv,
		relayPub:    pub,
	}
}

// PlayIntegrityTokenResponse represents the payload returned by Google Play Integrity API.
type PlayIntegrityTokenResponse struct {
	TokenPayloadExternal struct {
		RequestDetails struct {
			RequestPackageName string `json:"requestPackageName"`
			Nonce              string `json:"nonce"`
			TimestampMillis    string `json:"timestampMillis"`
		} `json:"requestDetails"`
		AppIntegrity struct {
			AppRecognitionVerdict   string   `json:"appRecognitionVerdict"`
			CertificateSha256Digest []string `json:"certificateSha256Digest"`
			VersionCode             string   `json:"versionCode"`
		} `json:"appIntegrity"`
		DeviceIntegrity struct {
			DeviceRecognitionVerdict []string `json:"deviceRecognitionVerdict"`
		} `json:"deviceIntegrity"`
		AppLicensingVerdict string `json:"appLicensingVerdict"`
	} `json:"tokenPayloadExternal"`
	Error *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Status  string `json:"status"`
	} `json:"error,omitempty"`
}

// VerifyIntegrityToken sends the token to Google Play Integrity API for decoding and validation.
func (v *PlayIntegrityVerifier) VerifyIntegrityToken(token, expectedNonce string) (bool, error) {
	if !v.enabled {
		return false, errors.New("play integrity verifier is not enabled on this relay")
	}

	accessToken, err := v.tokens.get()
	if err != nil {
		return false, fmt.Errorf("failed to obtain Google access token: %w", err)
	}

	apiURL := fmt.Sprintf("https://playintegrity.googleapis.com/v1/%s:decodeIntegrityToken", v.packageName)
	reqBody, _ := json.Marshal(map[string]string{
		"integrity_token": token,
	})

	req, err := http.NewRequest(http.MethodPost, apiURL, bytes.NewReader(reqBody))
	if err != nil {
		return false, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")

	res, err := v.httpClient.Do(req)
	if err != nil {
		return false, fmt.Errorf("call play integrity api: %w", err)
	}
	defer res.Body.Close()

	body, err := io.ReadAll(res.Body)
	if err != nil {
		return false, fmt.Errorf("read response: %w", err)
	}

	if res.StatusCode != http.StatusOK {
		return false, fmt.Errorf("google api returned status %d: %s", res.StatusCode, string(body))
	}

	var parsed PlayIntegrityTokenResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return false, fmt.Errorf("unmarshal response: %w", err)
	}

	if parsed.Error != nil {
		return false, fmt.Errorf("play integrity error: %s (code %d)", parsed.Error.Message, parsed.Error.Code)
	}

	// 1. Verify package name
	if parsed.TokenPayloadExternal.RequestDetails.RequestPackageName != v.packageName {
		return false, fmt.Errorf("package name mismatch: got %s, expected %s",
			parsed.TokenPayloadExternal.RequestDetails.RequestPackageName, v.packageName)
	}

	// 2. Verify nonce (base64 standard or URL-safe)
	actualNonce := parsed.TokenPayloadExternal.RequestDetails.Nonce
	if actualNonce != expectedNonce {
		// Also compare decoded bytes in case of alternate base64 encoding
		actBytes, _ := base64.StdEncoding.DecodeString(actualNonce)
		if len(actBytes) == 0 {
			actBytes, _ = base64.URLEncoding.DecodeString(actualNonce)
		}
		expBytes, _ := base64.StdEncoding.DecodeString(expectedNonce)
		if len(expBytes) == 0 {
			expBytes, _ = base64.URLEncoding.DecodeString(expectedNonce)
		}
		if len(actBytes) == 0 || len(expBytes) == 0 || !bytes.Equal(actBytes, expBytes) {
			return false, fmt.Errorf("nonce mismatch: got %s, expected %s", actualNonce, expectedNonce)
		}
	}

	// 3. Verify app recognition verdict (must match official Play Store build)
	appVerdict := parsed.TokenPayloadExternal.AppIntegrity.AppRecognitionVerdict
	if appVerdict != "PLAY_RECOGNIZED" {
		return false, fmt.Errorf("app recognition verdict is %s (expected PLAY_RECOGNIZED)", appVerdict)
	}

	// 4. Verify device integrity verdict
	deviceVerdicts := parsed.TokenPayloadExternal.DeviceIntegrity.DeviceRecognitionVerdict
	meetsIntegrity := false
	for _, dv := range deviceVerdicts {
		if dv == "MEETS_DEVICE_INTEGRITY" || dv == "MEETS_STRONG_INTEGRITY" || dv == "MEETS_BASIC_INTEGRITY" {
			meetsIntegrity = true
			break
		}
	}
	if !meetsIntegrity {
		return false, fmt.Errorf("device integrity failed: verdicts=%v", deviceVerdicts)
	}

	return true, nil
}

// SignAttestation generates an Ed25519 signature over canonical attestation data.
func (v *PlayIntegrityVerifier) SignAttestation(userID, clientType string, issuedAt, expiresAt int64) string {
	message := fmt.Sprintf("WILTKEY_ATTESTATION:%s:%s:%d:%d", userID, clientType, issuedAt, expiresAt)
	sig := ed25519.Sign(v.relayPriv, []byte(message))
	return hex.EncodeToString(sig)
}

// PublicKeyHex returns the hex-encoded Ed25519 public key of the relay.
func (v *PlayIntegrityVerifier) PublicKeyHex() string {
	return hex.EncodeToString(v.relayPub)
}

// Helper to compute expected nonce hash
func ComputeIntegrityNonce(serverNonce, keyHash string) string {
	combined := fmt.Sprintf("%s:%s", serverNonce, keyHash)
	hash := sha256.Sum256([]byte(combined))
	return base64.StdEncoding.EncodeToString(hash[:])
}
