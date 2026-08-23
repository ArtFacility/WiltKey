package main

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestPlayIntegritySigningAndNonce(t *testing.T) {
	verifier := NewPlayIntegrityVerifier()
	if verifier == nil {
		t.Fatal("expected non-nil verifier")
	}

	keyHash := "test_key_hash_1234567890abcdef"
	serverNonce := "0123456789abcdef0123456789abcdef"

	nonce := ComputeIntegrityNonce(serverNonce, keyHash)
	if nonce == "" {
		t.Fatal("expected non-empty computed nonce")
	}

	issuedAt := time.Now().Unix()
	expiresAt := time.Now().Add(kAttestationTTL).Unix()
	sigHex := verifier.SignAttestation(keyHash, "play_plus", issuedAt, expiresAt)

	if sigHex == "" {
		t.Fatal("expected non-empty attestation signature")
	}

	sigBytes, err := hex.DecodeString(sigHex)
	if err != nil || len(sigBytes) != ed25519.SignatureSize {
		t.Fatalf("invalid signature format/length: %v", err)
	}

	expectedMessage := fmt.Sprintf("WILTKEY_ATTESTATION:%s:%s:%d:%d", keyHash, "play_plus", issuedAt, expiresAt)
	if !ed25519.Verify(verifier.relayPub, []byte(expectedMessage), sigBytes) {
		t.Fatal("signature verification failed against relay public key")
	}
}

func TestIntegrityChallengeAndAttestFlow(t *testing.T) {
	// Setup in-memory redis and verifier
	rdb = &RedisClient{
		isMemory:           true,
		memoryQueue:        make(map[string][]memoryZ),
		memoryBlocks:       make(map[string]time.Time),
		memoryPoW:          make(map[string]powChallenge),
		memoryNonces:       make(map[string]time.Time),
		memoryBans:         make(map[string]time.Time),
		memoryFails:        make(map[string]ipFail),
		memoryRate:         make(map[string]int64),
		memoryPairings:     make(map[string]memoryPairing),
		memoryTunnels:      make(map[string]string),
		memoryTunnelBytes:  make(map[string]int64),
		memoryNukes:        make(map[string]ipFail),
		memoryPushTokens:   make(map[string]string),
		memoryEntitlements: make(map[string]string),
	}
	playIntegrityVerifier = NewPlayIntegrityVerifier()

	// Generate client keypair
	clientPub, clientPriv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("failed to generate client keypair: %v", err)
	}
	clientPubHex := hex.EncodeToString(clientPub)
	clientHashArr := sha256.Sum256(clientPub)
	clientKeyHash := hex.EncodeToString(clientHashArr[:])

	// 1. Request Challenge
	now := time.Now().Unix()
	challengeMsg := fmt.Sprintf("INTEGRITY_CHALLENGE:%s:%d", clientKeyHash, now)
	challengeSig := hex.EncodeToString(ed25519.Sign(clientPriv, []byte(challengeMsg)))

	challengeReqBody, _ := json.Marshal(IntegrityChallengeRequest{
		UserID:    clientKeyHash,
		Pubkey:    clientPubHex,
		Signature: challengeSig,
		Timestamp: now,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/integrity/challenge", bytes.NewReader(challengeReqBody))
	w := httptest.NewRecorder()
	handleIntegrityChallenge(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected challenge status 200, got %d: %s", w.Code, w.Body.String())
	}

	var challengeResp struct {
		ServerNonce   string `json:"server_nonce"`
		ExpectedNonce string `json:"expected_nonce"`
		Timestamp     int64  `json:"timestamp"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &challengeResp); err != nil {
		t.Fatalf("failed to parse challenge response: %v", err)
	}

	if challengeResp.ServerNonce == "" || challengeResp.ExpectedNonce == "" {
		t.Fatal("expected non-empty nonces from challenge response")
	}

	// 2. Submit Attestation
	mockToken := "mock_integrity_token_for_self_hosted_tests"
	tokenHashArr := sha256.Sum256([]byte(mockToken))
	tokenHash := hex.EncodeToString(tokenHashArr[:])

	attestNow := time.Now().Unix()
	attestMsg := fmt.Sprintf("INTEGRITY_ATTEST:%s:%s:%d", clientKeyHash, tokenHash, attestNow)
	attestSig := hex.EncodeToString(ed25519.Sign(clientPriv, []byte(attestMsg)))

	attestReqBody, _ := json.Marshal(IntegrityAttestRequest{
		UserID:         clientKeyHash,
		Pubkey:         clientPubHex,
		IntegrityToken: mockToken,
		Signature:      attestSig,
		Timestamp:      attestNow,
	})

	attestReq := httptest.NewRequest(http.MethodPost, "/api/v1/integrity/attest", bytes.NewReader(attestReqBody))
	attestW := httptest.NewRecorder()
	handleIntegrityAttest(attestW, attestReq)

	if attestW.Code != http.StatusOK {
		t.Fatalf("expected attest status 200, got %d: %s", attestW.Code, attestW.Body.String())
	}

	var attestResp struct {
		UserID         string `json:"user_id"`
		ClientType     string `json:"client_type"`
		IssuedAt       int64  `json:"issued_at"`
		ExpiresAt      int64  `json:"expires_at"`
		RelaySignature string `json:"relay_signature"`
		RelayPublicKey string `json:"relay_public_key"`
	}
	if err := json.Unmarshal(attestW.Body.Bytes(), &attestResp); err != nil {
		t.Fatalf("failed to parse attest response: %v", err)
	}

	if attestResp.UserID != clientKeyHash {
		t.Fatalf("user_id mismatch: expected %s, got %s", clientKeyHash, attestResp.UserID)
	}
	if attestResp.ClientType != "play_official" {
		t.Fatalf("expected client_type play_official, got %s", attestResp.ClientType)
	}
	if attestResp.RelaySignature == "" {
		t.Fatal("expected non-empty relay signature")
	}

	// Verify relay signature
	relayPubBytes, _ := hex.DecodeString(attestResp.RelayPublicKey)
	sigBytes, _ := hex.DecodeString(attestResp.RelaySignature)
	msgToVerify := fmt.Sprintf("WILTKEY_ATTESTATION:%s:%s:%d:%d", attestResp.UserID, attestResp.ClientType, attestResp.IssuedAt, attestResp.ExpiresAt)
	if !ed25519.Verify(relayPubBytes, []byte(msgToVerify), sigBytes) {
		t.Fatal("returned attestation signature is invalid")
	}

	// 3. Query Query Endpoint
	queryReq := httptest.NewRequest(http.MethodGet, "/api/v1/integrity/query?user_id=unknown_user_123", nil)
	queryW := httptest.NewRecorder()
	handleIntegrityQuery(queryW, queryReq)

	var queryResp struct {
		UserID     string `json:"user_id"`
		ClientType string `json:"client_type"`
	}
	json.Unmarshal(queryW.Body.Bytes(), &queryResp)
	if queryResp.ClientType != "tinkerer" {
		t.Fatalf("expected fallback tinkerer for unknown user, got %s", queryResp.ClientType)
	}
}
