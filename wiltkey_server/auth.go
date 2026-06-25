package main

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"errors"
)

// GenerateUserID computes SHA-256(PublicKeyBytes) and returns the hex-encoded string.
func GenerateUserID(pubKeyBytes []byte) string {
	hash := sha256.Sum256(pubKeyBytes)
	return hex.EncodeToString(hash[:])
}

// VerifySignature verifies if the Ed25519 signature is valid for the given message and public key.
func VerifySignature(pubKeyHex, sigHex string, message []byte) (bool, error) {
	pubKeyBytes, err := hex.DecodeString(pubKeyHex)
	if err != nil {
		return false, errors.New("invalid public key hex")
	}
	if len(pubKeyBytes) != ed25519.PublicKeySize {
		return false, errors.New("invalid public key size for ed25519")
	}

	sigBytes, err := hex.DecodeString(sigHex)
	if err != nil {
		return false, errors.New("invalid signature hex")
	}
	if len(sigBytes) != ed25519.SignatureSize {
		return false, errors.New("invalid signature size for ed25519")
	}

	return ed25519.Verify(pubKeyBytes, message, sigBytes), nil
}
