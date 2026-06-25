package main

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
)

// GenerateChallenge creates a random hex string to be used as a PoW challenge.
func GenerateChallenge() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// VerifyPoW checks if SHA256(challenge + nonce_str + payload) has the required number of leading hex zeros.
func VerifyPoW(challenge string, nonce int64, payload string, difficulty int) bool {
	data := fmt.Sprintf("%s%d%s", challenge, nonce, payload)
	hash := sha256.Sum256([]byte(data))
	hashHex := hex.EncodeToString(hash[:])

	prefix := strings.Repeat("0", difficulty)
	return strings.HasPrefix(hashHex, prefix)
}
