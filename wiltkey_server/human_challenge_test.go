package main

import (
	"crypto/ed25519"
	"encoding/hex"
	"testing"

	"github.com/gorilla/websocket"
)

// Human-verification challenge tests. Run like device_token_test.go: they
// need Redis + Postgres locally (or on the deploy box) and SKIP otherwise.

// dialAndAuthWithCaps performs the token-less dance with client_caps and a
// puzzle-solver hook. solvePuzzle receives (challengeID, seed, strips) and
// returns (answerToSubmit, challengeIDOverride) — a nil answer submits
// nothing (exposing the 90s read-deadline path), a non-empty override lets a
// test claim a wrong/replayed challenge id. Returns the connection plus
// whatever frame followed the issuance attempt (AUTH_OK or AUTH_REJECTED).
func dialAndAuthWithCaps(
	t *testing.T,
	wsURL, pubHex string,
	priv ed25519.PrivateKey,
	caps []string,
	solvePuzzle func(challengeID, seed string, strips int) (*int, string),
) (*websocket.Conn, WSMessage) {
	t.Helper()
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	var ch WSMessage
	if err := conn.ReadJSON(&ch); err != nil || ch.Type != "CHALLENGE" {
		t.Fatalf("challenge: %+v (err %v)", ch, err)
	}
	sig := ed25519.Sign(priv, []byte(ch.Challenge))
	if err := conn.WriteJSON(WSMessage{
		Type: "AUTH", Pubkey: pubHex,
		Signature:  hex.EncodeToString(sig),
		ClientCaps: caps,
	}); err != nil {
		t.Fatalf("auth write: %v", err)
	}
	var tc WSMessage
	if err := conn.ReadJSON(&tc); err != nil || tc.Type != "TOKEN_CHALLENGE" {
		t.Fatalf("expected TOKEN_CHALLENGE, got %+v (err %v)", tc, err)
	}
	nonce := solvePoWForTest(ch.Challenge, pubHex, tc.Difficulty)
	if err := conn.WriteJSON(WSMessage{Type: "AUTH_TOKEN_ISSUE", PowNonce: nonce}); err != nil {
		t.Fatalf("issue write: %v", err)
	}

	if solvePuzzle == nil {
		var done WSMessage
		if err := conn.ReadJSON(&done); err != nil {
			t.Fatalf("post-issue read: %v", err)
		}
		return conn, done
	}

	// Either a challenge frame or the direct outcome (mode off / no cap).
	var next WSMessage
	if err := conn.ReadJSON(&next); err != nil {
		t.Fatalf("post-issue read: %v", err)
	}
	if next.Type != "AUTH_CHALLENGE_REQUIRED" {
		return conn, next
	}
	answer, idOverride := solvePuzzle(next.ChallengeID, next.PuzzleSeed, next.PuzzleStrips)
	if answer == nil {
		return conn, next
	}
	claimedID := next.ChallengeID
	if idOverride != "" {
		claimedID = idOverride
	}
	if err := conn.WriteJSON(WSMessage{
		Type:         "AUTH_CHALLENGE_SOLUTION",
		ChallengeID:  claimedID,
		PuzzleAnswer: answer,
	}); err != nil {
		t.Fatalf("solution write: %v", err)
	}
	var done WSMessage
	if err := conn.ReadJSON(&done); err != nil {
		t.Fatalf("post-solution read: %v", err)
	}
	return conn, done
}

func setChallengeModeForTest(t *testing.T, mode string) {
	t.Helper()
	prev := challengeMode
	challengeMode = mode
	t.Cleanup(func() { challengeMode = prev })
}

func correctPuzzleSolver(challengeID, seed string, strips int) (*int, string) {
	a := PuzzleAnswerFromSeed(seed, strips)
	return &a, ""
}

func TestChallengeSolveFlow(t *testing.T) {
	_, wsURL := setupTokenTestEnv(t)
	setChallengeModeForTest(t, "always")
	pubHex, priv, _ := newTestIdentity(t)

	conn, done := dialAndAuthWithCaps(t, wsURL, pubHex, priv,
		[]string{"human_challenge"}, correctPuzzleSolver)
	defer conn.Close()
	if done.Type != "AUTH_OK" || done.DeviceToken == "" {
		t.Fatalf("solved challenge should mint a token, got %+v", done)
	}
}

func TestChallengeWrongAnswerStrikesAndCooldown(t *testing.T) {
	_, wsURL := setupTokenTestEnv(t)
	setChallengeModeForTest(t, "always")
	pubHex, priv, _ := newTestIdentity(t)
	wrongPuzzleSolver := func(challengeID, seed string, strips int) (*int, string) {
		a := (PuzzleAnswerFromSeed(seed, strips) + 1) % strips
		return &a, ""
	}

	for i := 0; i < 3; i++ {
		conn, done := dialAndAuthWithCaps(t, wsURL, pubHex, priv,
			[]string{"human_challenge"}, wrongPuzzleSolver)
		if done.Type != "AUTH_REJECTED" || done.Message != "challenge_failed" {
			conn.Close()
			t.Fatalf("attempt %d: expected challenge_failed, got %+v", i+1, done)
		}
		conn.Close()
	}

	// 3 strikes/h → the next attempt is refused outright (cooldown), no
	// puzzle frame, no IP ban.
	conn, done := dialAndAuthWithCaps(t, wsURL, pubHex, priv,
		[]string{"human_challenge"}, nil)
	defer conn.Close()
	if done.Type != "AUTH_REJECTED" || done.Message != "challenge_cooldown" {
		t.Fatalf("expected challenge_cooldown after 3 strikes, got %+v", done)
	}
}

func TestChallengeReplayIDRejected(t *testing.T) {
	_, wsURL := setupTokenTestEnv(t)
	setChallengeModeForTest(t, "always")
	pubHex, priv, _ := newTestIdentity(t)

	// Solve correctly but claim a DIFFERENT challenge id (replay shape) —
	// the id binding must reject it even with a correct answer.
	replaySolver := func(challengeID, seed string, strips int) (*int, string) {
		a := PuzzleAnswerFromSeed(seed, strips)
		return &a, "deadbeefdeadbeefdeadbeefdeadbeef"
	}
	conn, done := dialAndAuthWithCaps(t, wsURL, pubHex, priv,
		[]string{"human_challenge"}, replaySolver)
	defer conn.Close()
	if done.Type != "AUTH_REJECTED" || done.Message != "challenge_failed" {
		t.Fatalf("mismatched challenge_id must fail, got %+v", done)
	}
}

func TestChallengeCapNegotiation(t *testing.T) {
	_, wsURL := setupTokenTestEnv(t)
	setChallengeModeForTest(t, "always")
	pubHex, priv, _ := newTestIdentity(t)

	// Enforcement flip (review 2026-09-06 HIGH): in `always` mode a client
	// that does NOT advertise the cap is REFUSED — a bot farm must not be
	// able to strip the cap string and downgrade to PoW-only.
	conn, done := dialAndAuthWithCaps(t, wsURL, pubHex, priv, nil, nil)
	defer conn.Close()
	if done.Type != "AUTH_REJECTED" || done.Message != "challenge_upgrade_required" {
		t.Fatalf("cap-less client must be refused while mode=always, got %+v", done)
	}
}

func TestChallengeOffModePoWOnly(t *testing.T) {
	_, wsURL := setupTokenTestEnv(t)
	// challengeMode defaults to "off" (setupTokenTestEnv doesn't change it).
	pubHex, priv, _ := newTestIdentity(t)

	// Off mode: no caps, no puzzle — the plain PoW issuance path.
	conn, done := dialAndAuthWithCaps(t, wsURL, pubHex, priv, nil, nil)
	defer conn.Close()
	if done.Type != "AUTH_OK" || done.DeviceToken == "" {
		t.Fatalf("mode=off should mint via PoW alone, got %+v", done)
	}
}

func TestAdaptiveFirstIssuanceFree(t *testing.T) {
	_, wsURL := setupTokenTestEnv(t)
	setChallengeModeForTest(t, "adaptive")
	pubHex, priv, _ := newTestIdentity(t)

	// First issuance of the day: PoW-only, no puzzle frame.
	conn, done := dialAndAuthWithCaps(t, wsURL, pubHex, priv,
		[]string{"human_challenge"}, correctPuzzleSolver)
	if done.Type != "AUTH_OK" {
		t.Fatalf("first adaptive issuance should skip the puzzle, got %+v", done)
	}
	conn.Close()

	// Second issuance from the same IP today: challenged, then minted.
	pub2, priv2, _ := newTestIdentity(t)
	conn2, done2 := dialAndAuthWithCaps(t, wsURL, pub2, priv2,
		[]string{"human_challenge"}, correctPuzzleSolver)
	defer conn2.Close()
	if done2.Type != "AUTH_OK" || done2.DeviceToken == "" {
		t.Fatalf("second adaptive issuance should challenge then mint, got %+v", done2)
	}
}
