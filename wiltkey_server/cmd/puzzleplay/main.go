// DEV-ONLY endless human-verification puzzle relay (Phase 2 tester).
//
// Build & run (from wiltkey_server/):
//
//	go run ./cmd/puzzleplay
//
// Then point the app's dev-relay setting at http://<this-host>:8095 (the
// client converts to ws:// itself) and watch the console: the app loops
// connect → real CHALLENGE/AUTH → trivial PoW → puzzle → solve → AUTH_OK.
//
// Two deliberate tester behaviors make the loop ENDLESS:
//  1. AUTH_OK carries NO device_token — the client stays token-less, so
//     every reconnect walks the full issuance dance again.
//  2. After a solved puzzle the socket closes after a short beat, so the
//     client auto-reconnects into the next round. A WRONG answer does NOT
//     close: a fresh puzzle is served immediately on the same socket so
//     practice flows uninterrupted (the real relay closes + strikes).
//
// It imports the relay's REAL PoW + puzzle math (internal/cryptoops) — the
// same functions the shipped relay runs — so the crypto under test is the
// shipping math. The frame structs below are a deliberate minimal subset of
// the relay's WSMessage (drift there surfaces instantly as a broken dance).
//
// The app's HTTP-side calls (queue/status poll, file tokens) hit this
// tester's 404s — harmless noise.
package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"

	"wiltkey_server/internal/cryptoops"
)

const puzzleStrips = cryptoops.PuzzleStrips
const puzzleSolutionDeadline = 90 * time.Second

var (
	playAddr        string
	playDifficulty  int
	roundsPresented atomic.Int64
	roundsSolved    atomic.Int64
	roundsFailed    atomic.Int64
)

// Minimal frame subset of the relay's WSMessage (json tags must match).
type wsFrame struct {
	Type         string `json:"type"`
	Challenge    string `json:"challenge,omitempty"`
	Pubkey       string `json:"pubkey,omitempty"`
	Signature    string `json:"signature,omitempty"`
	UserID       string `json:"user_id,omitempty"`
	DeviceToken  string `json:"device_token,omitempty"`
	PowNonce     int64  `json:"pow_nonce,omitempty"`
	Difficulty   int    `json:"difficulty,omitempty"`
	ChallengeID  string `json:"challenge_id,omitempty"`
	PuzzleSeed   string `json:"seed,omitempty"`
	PuzzleKind   string `json:"kind,omitempty"`
	PuzzleStrips int    `json:"strips,omitempty"`
	PuzzleAnswer *int   `json:"answer,omitempty"`
	Message      string `json:"message,omitempty"`
}

func puzzleplayMain() {
	flag.StringVar(&playAddr, "addr", ":8095", "listen address")
	flag.IntVar(&playDifficulty, "difficulty", 1, "PoW difficulty (keep tiny — the puzzle is the point)")
	flag.Parse()

	upgrader := websocket.Upgrader{CheckOrigin: func(*http.Request) bool { return true }}
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		puzzleplayWS(w, r, upgrader)
	})
	log.Printf("[puzzleplay] endless puzzle relay on %s — set the app dev relay to http://<host>%s", playAddr, playAddr)
	log.Printf("[puzzleplay] PoW difficulty %d (~16^%d hashes per round — instant)", playDifficulty, playDifficulty)
	log.Fatal(http.ListenAndServe(playAddr, mux))
}

func puzzleplayWS(w http.ResponseWriter, r *http.Request, upgrader websocket.Upgrader) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()
	ip := r.RemoteAddr
	log.Printf("[puzzleplay] + connect from %s", ip)

	// 1. CHALLENGE
	challengeHex := randomHex(32)
	writeFrame(conn, wsFrame{Type: "CHALLENGE", Challenge: challengeHex})

	// 2. AUTH (token-less expected; signature verified like the real relay)
	conn.SetReadDeadline(time.Now().Add(10 * time.Second))
	_, msgBytes, err := conn.ReadMessage()
	if err != nil {
		return
	}
	var authMsg wsFrame
	if err := json.Unmarshal(msgBytes, &authMsg); err != nil || authMsg.Type != "AUTH" {
		return
	}
	pubKeyBytes, err := hex.DecodeString(authMsg.Pubkey)
	if err != nil || len(pubKeyBytes) != ed25519.PublicKeySize {
		return
	}
	sig, err := hex.DecodeString(authMsg.Signature)
	if err != nil {
		return
	}
	if !ed25519.Verify(ed25519.PublicKey(pubKeyBytes), []byte(challengeHex), sig) {
		log.Printf("[puzzleplay] bad signature from %s — closing", ip)
		return
	}
	userID := userIDFromPubkey(authMsg.Pubkey)

	// 3. TOKEN_CHALLENGE (tiny difficulty)
	writeFrame(conn, wsFrame{
		Type: "TOKEN_CHALLENGE", Challenge: challengeHex, Difficulty: playDifficulty,
	})
	conn.SetReadDeadline(time.Now().Add(120 * time.Second))
	_, msgBytes, err = conn.ReadMessage()
	if err != nil {
		return
	}
	var issueMsg wsFrame
	if err := json.Unmarshal(msgBytes, &issueMsg); err != nil || issueMsg.Type != "AUTH_TOKEN_ISSUE" {
		return
	}
	if !cryptoops.VerifyPoW(challengeHex, issueMsg.PowNonce, authMsg.Pubkey, playDifficulty) {
		log.Printf("[puzzleplay] bad PoW from %s — closing", ip)
		return
	}

	// 4. Endless puzzle rounds on this socket.
	for {
		seed := randomHex(16)
		challengeID := randomHex(16)
		roundsPresented.Add(1)
		roundStart := time.Now()

		writeFrame(conn, wsFrame{
			Type:         "AUTH_CHALLENGE_REQUIRED",
			ChallengeID:  challengeID,
			PuzzleSeed:   seed,
			PuzzleKind:   "strip_slide",
			PuzzleStrips: puzzleStrips,
		})
		log.Printf("[puzzleplay] round %d → seed %s… (solve it in the app!)",
			roundsPresented.Load(), seed[:12])

		conn.SetReadDeadline(time.Now().Add(puzzleSolutionDeadline))
		_, solBytes, err := conn.ReadMessage()
		if err != nil {
			log.Printf("[puzzleplay] - disconnected (%v) | solved %d / failed %d / %d rounds",
				err, roundsSolved.Load(), roundsFailed.Load(), roundsPresented.Load())
			return
		}
		var sol wsFrame
		if jsonErr := json.Unmarshal(solBytes, &sol); jsonErr != nil ||
			sol.Type != "AUTH_CHALLENGE_SOLUTION" || sol.ChallengeID != challengeID {
			failRound(conn, ip, seed, "malformed solution")
			continue
		}
		expected := cryptoops.PuzzleAnswerFromSeed(seed, puzzleStrips)
		if sol.PuzzleAnswer == nil || *sol.PuzzleAnswer != expected {
			failRound(conn, ip, seed, "wrong answer")
			continue
		}

		roundsSolved.Add(1)
		took := time.Since(roundStart)
		log.Printf("[puzzleplay] ✓ solved in %.1fs | solved %d / failed %d / %d rounds",
			took.Seconds(), roundsSolved.Load(), roundsFailed.Load(), roundsPresented.Load())

		// AUTH_OK WITHOUT a token keeps the client on the issuance path
		// forever. Then a short beat, close, and the client reconnects for
		// the next round (exercising the full dance each time).
		writeFrame(conn, wsFrame{Type: "AUTH_OK", UserID: userID})
		time.Sleep(1500 * time.Millisecond)
		return // deferred Close → client reconnects → next round
	}
}

// failRound reports the miss, reveals the expected answer for debugging, and
// serves the NEXT puzzle on the same socket (practice loop stays unbroken).
func failRound(conn *websocket.Conn, ip, seed, why string) {
	roundsFailed.Add(1)
	log.Printf("[puzzleplay] ✗ %s by %s | expected %d | solved %d / failed %d",
		why, ip, cryptoops.PuzzleAnswerFromSeed(seed, puzzleStrips),
		roundsSolved.Load(), roundsFailed.Load())
	writeFrame(conn, wsFrame{Type: "AUTH_REJECTED", Message: "challenge_failed"})
}

func writeFrame(conn *websocket.Conn, msg wsFrame) {
	b, _ := json.Marshal(msg)
	if err := conn.WriteMessage(websocket.TextMessage, b); err != nil {
		log.Printf("[puzzleplay] write failed: %v", err)
	}
}

func randomHex(nBytes int) string {
	b := make([]byte, nBytes)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}

// userIDFromPubkey mirrors the relay's GenerateUserID (sha256 of pubkey hex —
// only echoed back in AUTH_OK here, so a local copy is harmless).
func userIDFromPubkey(pubHex string) string {
	b, _ := hex.DecodeString(pubHex)
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

func main() { puzzleplayMain() }
