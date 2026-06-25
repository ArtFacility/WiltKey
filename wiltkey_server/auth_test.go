package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"testing"
)

func TestAuth(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("failed to generate key: %v", err)
	}

	pubHex := hex.EncodeToString(pub)
	userID := GenerateUserID(pub)

	challenge := []byte("challenge-text-12345")
	sig := ed25519.Sign(priv, challenge)
	sigHex := hex.EncodeToString(sig)

	ok, err := VerifySignature(pubHex, sigHex, challenge)
	if err != nil {
		t.Fatalf("signature verification returned error: %v", err)
	}
	if !ok {
		t.Errorf("expected signature to be valid, but got invalid")
	}

	// Verify that userID computation is consistent
	expectedUserID := GenerateUserID(pub)
	if userID != expectedUserID {
		t.Errorf("user ID was not stable, got %s, expected %s", userID, expectedUserID)
	}
}
