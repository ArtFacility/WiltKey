package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/gorilla/websocket"
)

// solvePoWForTest finds a nonce the relay's VerifyPoW accepts — the same loop
// the Flutter client runs (pow_solver.dart).
func solvePoWForTest(challenge, payload string, difficulty int) int64 {
	for n := int64(0); ; n++ {
		if VerifyPoW(challenge, n, payload, difficulty) {
			return n
		}
	}
}

// authWSForTest performs the full device-token handshake against a relay. With
// token == "" it walks the issuance path (tokenless AUTH → TOKEN_CHALLENGE →
// solve → AUTH_TOKEN_ISSUE → AUTH_OK) and returns the minted raw token;
// otherwise it presents the token (signature covers challenge||token) and
// expects a direct AUTH_OK.
func authWSForTest(t *testing.T, wsURL, pubHex string, priv ed25519.PrivateKey, token string) (*websocket.Conn, string) {
	t.Helper()
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("failed to dial WS: %v", err)
	}
	var ch WSMessage
	if err := conn.ReadJSON(&ch); err != nil {
		t.Fatalf("failed to read challenge: %v", err)
	}
	hasTok := token != ""
	payload := ch.Challenge
	if hasTok {
		payload += token
	}
	sig := ed25519.Sign(priv, []byte(payload))
	if err := conn.WriteJSON(WSMessage{
		Type:        "AUTH",
		Pubkey:      pubHex,
		Signature:   hex.EncodeToString(sig),
		DeviceToken: token,
	}); err != nil {
		t.Fatalf("failed to send AUTH: %v", err)
	}
	if !hasTok {
		var tc WSMessage
		if err := conn.ReadJSON(&tc); err != nil || tc.Type != "TOKEN_CHALLENGE" {
			t.Fatalf("expected TOKEN_CHALLENGE, got %+v (err %v)", tc, err)
		}
		nonce := solvePoWForTest(ch.Challenge, pubHex, tc.Difficulty)
		if err := conn.WriteJSON(WSMessage{Type: "AUTH_TOKEN_ISSUE", PowNonce: nonce}); err != nil {
			t.Fatalf("failed to send AUTH_TOKEN_ISSUE: %v", err)
		}
	}
	var ok WSMessage
	if err := conn.ReadJSON(&ok); err != nil || ok.Type != "AUTH_OK" {
		t.Fatalf("expected AUTH_OK, got %+v (err %v)", ok, err)
	}
	return conn, ok.DeviceToken
}

func setupTokenTestEnv(t *testing.T) (*httptest.Server, string) {
	t.Helper()
	testRdb, err := NewRedisClient("localhost:6379")
	if err != nil || testRdb.IsMemory() {
		t.Skip("Skipping device-token test: Redis not running on localhost:6379")
		return nil, ""
	}
	t.Cleanup(func() { testRdb.Close() })
	rdb = testRdb

	pgURL := os.Getenv("POSTGRES_URL")
	if pgURL == "" {
		pgURL = "postgres://wiltkey:wiltkey@localhost:5432/wiltkey?sslmode=disable"
	}
	testPg, err := NewPostgresClient(pgURL)
	if err != nil {
		t.Skipf("Skipping device-token test: Postgres not running (%v)", err)
		return nil, ""
	}
	t.Cleanup(func() { testPg.Close() })
	pg = testPg

	rdb.FlushAll()
	pg.db.Exec("DELETE FROM device_tokens")

	hub := NewHub(rdb, NewPushSender())
	go hub.Run()

	mux := http.NewServeMux()
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		ServeWS(hub, w, r)
	})
	server := httptest.NewServer(mux)
	t.Cleanup(server.Close)

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
	return server, wsURL
}

func newTestIdentity(t *testing.T) (pubHex string, priv ed25519.PrivateKey, userID string) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	return hex.EncodeToString(pub), priv, GenerateUserID(pub)
}

func TestDeviceTokenIssuanceAndBypass(t *testing.T) {
	_, wsURL := setupTokenTestEnv(t)
	pubHex, priv, _ := newTestIdentity(t)

	// 1. Token-less connect → issuance dance → AUTH_OK carrying a token.
	conn, token := authWSForTest(t, wsURL, pubHex, priv, "")
	defer conn.Close()
	if token == "" {
		t.Fatalf("expected a minted device token in AUTH_OK")
	}

	// 2. Reconnect presenting the token (challenge-bound signature) → direct
	//    AUTH_OK, no refresh this early in the TTL.
	conn2, refreshed := authWSForTest(t, wsURL, pubHex, priv, token)
	defer conn2.Close()
	if refreshed != "" {
		t.Fatalf("token should not rotate this early, got a refresh")
	}

	// 3. Token bound to a DIFFERENT identity must be rejected.
	otherPub, otherPriv, _ := newTestIdentity(t)
	conn3, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn3.Close()
	var ch WSMessage
	if err := conn3.ReadJSON(&ch); err != nil {
		t.Fatalf("challenge: %v", err)
	}
	sig := ed25519.Sign(otherPriv, []byte(ch.Challenge+token))
	conn3.WriteJSON(WSMessage{
		Type: "AUTH", Pubkey: otherPub,
		Signature: hex.EncodeToString(sig), DeviceToken: token,
	})
	var rej WSMessage
	if err := conn3.ReadJSON(&rej); err != nil || rej.Type != "AUTH_REJECTED" {
		t.Fatalf("expected AUTH_REJECTED for cross-identity token, got %+v (err %v)", rej, err)
	}
}

func TestDeviceTokenRotationOverlapAndRevoke(t *testing.T) {
	_, wsURL := setupTokenTestEnv(t)
	pubHex, priv, _ := newTestIdentity(t)

	conn, token := authWSForTest(t, wsURL, pubHex, priv, "")
	conn.Close()

	// Force the token into the refresh window → next auth must carry a NEW
	// token, and the old one must keep working (overlap).
	pg.db.Exec(`UPDATE device_tokens SET token_expires_at = NOW() + interval '3 days' WHERE user_id = $1`, GenerateUserID(decodeHex(t, pubHex)))
	conn2, refreshed := authWSForTest(t, wsURL, pubHex, priv, token)
	defer conn2.Close()
	if refreshed == "" || refreshed == token {
		t.Fatalf("expected a rotated token in AUTH_OK, got %q", refreshed)
	}

	// Overlap: the OLD token is still accepted (and forces a refresh).
	conn3, refreshedOld := authWSForTest(t, wsURL, pubHex, priv, token)
	conn3.Close()
	if refreshedOld == "" {
		t.Fatalf("overlap token should trigger an immediate refresh")
	}

	// Revocation kills both.
	if err := pg.RevokeDeviceToken(GenerateUserID(decodeHex(t, pubHex))); err != nil {
		t.Fatalf("revoke: %v", err)
	}
	conn4, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn4.Close()
	var ch WSMessage
	if err := conn4.ReadJSON(&ch); err != nil {
		t.Fatalf("challenge: %v", err)
	}
	sig := ed25519.Sign(priv, []byte(ch.Challenge+refreshed))
	conn4.WriteJSON(WSMessage{
		Type: "AUTH", Pubkey: pubHex,
		Signature: hex.EncodeToString(sig), DeviceToken: refreshed,
	})
	var rej WSMessage
	if err := conn4.ReadJSON(&rej); err != nil || rej.Type != "AUTH_REJECTED" {
		t.Fatalf("expected AUTH_REJECTED after revocation, got %+v (err %v)", rej, err)
	}
}

func TestDeviceTokenBadPoWAndCap(t *testing.T) {
	_, wsURL := setupTokenTestEnv(t)
	pubHex, priv, _ := newTestIdentity(t)

	// Bad PoW → AUTH_REJECTED pow_invalid.
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	var ch WSMessage
	if err := conn.ReadJSON(&ch); err != nil {
		t.Fatalf("challenge: %v", err)
	}
	sig := ed25519.Sign(priv, []byte(ch.Challenge))
	conn.WriteJSON(WSMessage{Type: "AUTH", Pubkey: pubHex, Signature: hex.EncodeToString(sig)})
	var tc WSMessage
	if err := conn.ReadJSON(&tc); err != nil || tc.Type != "TOKEN_CHALLENGE" {
		t.Fatalf("expected TOKEN_CHALLENGE, got %+v (err %v)", tc, err)
	}
	badNonce := solvePoWForTest(ch.Challenge, "wrongpayload", tc.Difficulty)
	conn.WriteJSON(WSMessage{Type: "AUTH_TOKEN_ISSUE", PowNonce: badNonce})
	var rej WSMessage
	if err := conn.ReadJSON(&rej); err != nil || rej.Type != "AUTH_REJECTED" || rej.Message != "pow_invalid" {
		t.Fatalf("expected pow_invalid rejection, got %+v (err %v)", rej, err)
	}
	conn.Close()

	// Issuance cap: mint up to the cap, then the next one is refused.
	oldCap := issuanceDailyIPCap
	issuanceDailyIPCap = 2
	defer func() { issuanceDailyIPCap = oldCap }()

	_, tok1 := authWSForTest(t, wsURL, pubHex, priv, "")
	if tok1 == "" {
		t.Fatalf("first mint should succeed")
	}
	_, tok2 := authWSForTest(t, wsURL, pubHex, priv, "")
	if tok2 == "" {
		t.Fatalf("second mint should succeed")
	}
	conn2, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn2.Close()
	if err := conn2.ReadJSON(&ch); err != nil {
		t.Fatalf("challenge: %v", err)
	}
	sig = ed25519.Sign(priv, []byte(ch.Challenge))
	conn2.WriteJSON(WSMessage{Type: "AUTH", Pubkey: pubHex, Signature: hex.EncodeToString(sig)})
	if err := conn2.ReadJSON(&tc); err != nil || tc.Type != "TOKEN_CHALLENGE" {
		t.Fatalf("expected TOKEN_CHALLENGE, got %+v (err %v)", tc, err)
	}
	nonce := solvePoWForTest(ch.Challenge, pubHex, tc.Difficulty)
	conn2.WriteJSON(WSMessage{Type: "AUTH_TOKEN_ISSUE", PowNonce: nonce})
	var rej2 WSMessage
	if err := conn2.ReadJSON(&rej2); err != nil || rej2.Type != "AUTH_REJECTED" || rej2.Message != "issuance_rate_limited" {
		t.Fatalf("expected issuance_rate_limited, got %+v (err %v)", rej2, err)
	}
}

func decodeHex(t *testing.T, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(s)
	if err != nil {
		t.Fatalf("bad hex: %v", err)
	}
	return b
}
