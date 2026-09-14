package main

import (
	"crypto/rand"
	"encoding/hex"

	"wiltkey_server/internal/cryptoops"
)

// GenerateChallenge creates a random hex string to be used as a PoW challenge.
func GenerateChallenge() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// VerifyPoW checks if SHA256(challenge + nonce_str + payload) has the required
// number of leading hex zeros. Thin wrapper — the canonical implementation
// lives in internal/cryptoops so the local puzzle tester (cmd/puzzleplay)
// shares the exact math.
func VerifyPoW(challenge string, nonce int64, payload string, difficulty int) bool {
	return cryptoops.VerifyPoW(challenge, nonce, payload, difficulty)
}
