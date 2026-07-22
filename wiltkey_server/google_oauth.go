package main

// Minimal Google service-account OAuth2 token source (stdlib only).
//
// Signs a JWT assertion with the service account's RSA key, exchanges it for an
// access token, and caches that token until just before it expires. Shared by
// any Google API the relay talks to; see play_billing.go.

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sync"
	"time"
)

// googleTokenSource mints and caches access tokens for one scope.
type googleTokenSource struct {
	sa         serviceAccount
	privKey    *rsa.PrivateKey
	scope      string
	httpClient *http.Client

	mu     sync.Mutex
	token  string
	expiry time.Time
}

// get returns a cached access token, minting a fresh one when the cache is empty
// or near expiry. Safe for concurrent use.
func (g *googleTokenSource) get() (string, error) {
	g.mu.Lock()
	defer g.mu.Unlock()

	if g.token != "" && time.Now().Before(g.expiry) {
		return g.token, nil
	}

	now := time.Now()
	header := base64URL(`{"alg":"RS256","typ":"JWT"}`)
	claims := base64URL(fmt.Sprintf(
		`{"iss":%q,"scope":%q,"aud":%q,"iat":%d,"exp":%d}`,
		g.sa.ClientEmail, g.scope, g.sa.TokenURI, now.Unix(), now.Add(time.Hour).Unix(),
	))
	signingInput := header + "." + claims

	hashed := sha256.Sum256([]byte(signingInput))
	sig, err := rsa.SignPKCS1v15(rand.Reader, g.privKey, crypto.SHA256, hashed[:])
	if err != nil {
		return "", fmt.Errorf("sign jwt: %w", err)
	}
	assertion := signingInput + "." + base64.RawURLEncoding.EncodeToString(sig)

	form := url.Values{}
	form.Set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer")
	form.Set("assertion", assertion)

	resp, err := g.httpClient.PostForm(g.sa.TokenURI, form)
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

	g.token = tok.AccessToken
	// Refresh a minute early to absorb clock skew / round-trips.
	g.expiry = now.Add(time.Duration(tok.ExpiresIn-60) * time.Second)
	return g.token, nil
}
