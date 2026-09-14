package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log"
	"os"
	"time"

	"github.com/gorilla/websocket"

	"wiltkey_server/internal/cryptoops"
)

// Human-verification challenge (Phase 2): a strip-slide drag puzzle rendered
// CLIENT-SIDE from a server-provided seed. The relay never renders anything —
// it only derives the expected answer from the same seed and compares the
// client's submission. Threat model (see HUMAN_VERIFICATION_DESIGN.md): this
// defeats casual scripts and generic screenshot-driven agents; a determined
// solver who ports the answer derivation beats it. Strikes + the per-IP daily
// issuance cap are the real backstop.
//
// Mechanic: the client deterministically builds a 10×10 pixel sprite from the
// seed, slices it into [strips] vertical strips, and displays them rotated by
// k = sha256(seed+"k")[0] % strips. The user drags a scrubber to apply an
// extra rotation u (0..strips-1); the sprite locks in when k+u ≡ 0 (mod
// strips), i.e. u = (-k) mod strips. The client submits u; the relay accepts
// only the value PuzzleAnswerFromSeed computes. A blind guess therefore
// succeeds ~1/strips per dance, and each wrong guess burns a strike
// (3/hour → 30min cooldown, no IP ban).
//
// All state lives in the synchronous issuance handshake on one socket — no
// DB table. Cross-request counters (strikes/cooldown) are Redis-only; this
// assumes the single-relay deployment (documented limitation).

// Puzzle mode (WK_CHALLENGE_MODE): off = never challenge (default; also what
// the test relay runs so sectest stays scriptable); adaptive = challenge every
// issuance EXCEPT the first per IP per day; always = challenge every issuance.
var challengeMode = "off"

const (
	puzzleStrips           = cryptoops.PuzzleStrips
	puzzleSolutionDeadline = 90 * time.Second
	puzzleTTLSeconds       = 90
)

var errPuzzleSolution = errors.New("human challenge failed")

// PuzzleAnswerFromSeed derives the expected user rotation u for a seed.
// Thin wrapper — the canonical implementation lives in internal/cryptoops so
// the local puzzle tester (cmd/puzzleplay) shares the exact math. Golden
// vectors: puzzle_test.go ↔ the Dart mirror (puzzle_golden_test.dart).
func PuzzleAnswerFromSeed(seed string, strips int) int {
	return cryptoops.PuzzleAnswerFromSeed(seed, strips)
}

// puzzleRequiredForClient decides whether THIS issuance must pass the human
// challenge. Caps are client-advertised (AUTH client_caps); see
// challengeUpgradeRequired for the enforcement flip that stops cap-stripping
// bots from downgrading to the PoW-only path.
func puzzleRequiredForClient(clientCaps []string, ip string) bool {
	if !clientAdvertisesChallenge(clientCaps) {
		return false
	}
	if challengeMode == "always" {
		return true
	}
	// adaptive: the FIRST issuance per IP per day stays PoW-only. Peek the
	// pre-increment counter (AllowIssuance increments later, after the
	// challenge passes, so failed puzzles never burn daily quota).
	// KNOWN TOCTOU (review 2026-09-06, accepted for v1): N parallel connects
	// from one IP all peek 0 and all skip — bounded by the daily cap's
	// atomic INCR. Track for an atomic check-and-increment later.
	count, err := rdb.IssuanceCountToday(ip)
	if err != nil {
		// Fail OPEN here (serve the challenge) — the strict fail-closed
		// path is AllowIssuance itself right before minting.
		log.Printf("[Challenge] Issuance peek failed for %s: %v — requiring challenge", ip, err)
		return true
	}
	return count >= 1
}

// challengeUpgradeRequired reports when the relay MUST refuse issuance from
// clients that don't advertise the human_challenge cap. Without this, a bot
// farm simply strips the cap string and downgrades to PoW-only forever.
// Enabled whenever the challenge mode is on — safe because the no-backcompat
// release model ships app + relay together (old apps only exist before the
// flip, and the website force-update catches them).
func challengeUpgradeRequired(clientCaps []string) bool {
	if challengeMode == "off" {
		return false
	}
	return !clientAdvertisesChallenge(clientCaps)
}

func clientAdvertisesChallenge(clientCaps []string) bool {
	for _, c := range clientCaps {
		if c == "human_challenge" {
			return true
		}
	}
	return false
}

// runPuzzleChallenge presents the puzzle and verifies the solution on the
// (already PoW-verified) connection. Returns nil when the user solved it;
// non-nil otherwise (caller sends AUTH_REJECTED challenge_failed and closes).
func runPuzzleChallenge(conn *websocket.Conn, ip string) (err error) {
	seed, err := randomHex(16)
	if err != nil {
		return err
	}
	challengeID, err := randomHex(16)
	if err != nil {
		return err
	}

	frame := WSMessage{
		Type:         "AUTH_CHALLENGE_REQUIRED",
		ChallengeID:  challengeID,
		PuzzleSeed:   seed,
		PuzzleKind:   "strip_slide",
		PuzzleStrips: puzzleStrips,
		TTL:          puzzleTTLSeconds,
	}
	frameBytes, _ := json.Marshal(frame)
	if err := conn.WriteMessage(websocket.TextMessage, frameBytes); err != nil {
		return err
	}

	// Generous window: a human has to see, drag and confirm. Bots get at
	// most ONE guess per socket at ~1/5 odds before the dance restarts.
	conn.SetReadDeadline(time.Now().Add(puzzleSolutionDeadline))
	_, solutionBytes, err := conn.ReadMessage()
	if err != nil {
		return err
	}
	var sol WSMessage
	if jsonErr := json.Unmarshal(solutionBytes, &sol); jsonErr != nil ||
		sol.Type != "AUTH_CHALLENGE_SOLUTION" {
		// Unparseable garbage: no strike (could be a stray frame), just fail.
		return errPuzzleSolution
	}

	// Everything below is a WELL-FORMED solution attempt — a wrong answer
	// AND a replayed/forged challenge id both count as strikes (review
	// 2026-09-06: the id-mismatch probe was previously strike-blind).
	if sol.ChallengeID != challengeID {
		registerChallengeStrikeForRejection(ip)
		log.Printf("[Auth Rejected] Human challenge id mismatch for %s", ip)
		return errPuzzleSolution
	}

	expected := PuzzleAnswerFromSeed(seed, puzzleStrips)
	if sol.PuzzleAnswer == nil || *sol.PuzzleAnswer != expected {
		registerChallengeStrikeForRejection(ip)
		log.Printf("[Auth Rejected] Human challenge failed for %s", ip)
		return errPuzzleSolution
	}
	log.Printf("[Challenge] Solved by %s", ip)
	return nil
}

// registerChallengeStrikeForRejection counts a failed attempt and arms the
// cooldown at 3 strikes within the hour (3/h → 30min, no IP ban).
func registerChallengeStrikeForRejection(ip string) {
	strikes, err := rdb.RegisterChallengeStrike(ip)
	if err != nil {
		log.Printf("[Challenge] Strike registration failed for %s: %v", ip, err)
		return
	}
	if strikes >= 3 {
		if cerr := rdb.SetChallengeCooldown(ip, 30*time.Minute); cerr == nil {
			log.Printf("[Challenge] Cooldown armed for %s (strikes %d)", ip, strikes)
		}
	}
}

// initChallengeEnv parses WK_CHALLENGE_MODE at boot (default off).
func initChallengeEnv() {
	switch m := os.Getenv("WK_CHALLENGE_MODE"); m {
	case "", "off":
		challengeMode = "off"
	case "adaptive":
		challengeMode = "adaptive"
	case "always":
		challengeMode = "always"
	default:
		log.Printf("Warning: invalid WK_CHALLENGE_MODE %q — keeping %q", m, challengeMode)
	}
}

// randomHex returns 2*n hex chars. Fail-CLOSED: a security gate must never
// proceed on a known/predictable challenge (review 2026-09-06), so callers
// abort the dance on error.
func randomHex(nBytes int) (string, error) {
	b := make([]byte, nBytes)
	if _, err := rand.Read(b); err != nil {
		log.Printf("[Challenge] random read failed: %v", err)
		return "", err
	}
	return hex.EncodeToString(b), nil
}
