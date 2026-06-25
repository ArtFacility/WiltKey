package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"testing"
	"time"
)

func TestPoW(t *testing.T) {
	challenge, err := GenerateChallenge()
	if err != nil {
		t.Fatalf("failed to generate challenge: %v", err)
	}

	payload := "message_content_to_be_sent"
	difficulty := 2

	// Brute force a simple 2-char difficulty nonce
	var nonce int64
	var found bool
	for nonce = 0; nonce < 1000000; nonce++ {
		if VerifyPoW(challenge, nonce, payload, difficulty) {
			found = true
			break
		}
	}

	if !found {
		t.Fatalf("failed to find nonce for difficulty %d", difficulty)
	}

	// Verify validation works
	if !VerifyPoW(challenge, nonce, payload, difficulty) {
		t.Errorf("VerifyPoW returned false for valid nonce")
	}

	// Verify invalid nonce fails
	if VerifyPoW(challenge, nonce+1, payload, difficulty) {
		t.Errorf("VerifyPoW returned true for invalid nonce")
	}
}

func TestVoucher(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("failed to generate key: %v", err)
	}

	pubHex := hex.EncodeToString(pub)
	hashPub := sha256.Sum256(pub)
	recipientID := hex.EncodeToString(hashPub[:])

	senderKeyHash := "bob_public_key_hash_value_123"
	expiry := time.Now().Add(1 * time.Hour).Unix()

	message := fmt.Sprintf("%s:%d", senderKeyHash, expiry)
	sig := ed25519.Sign(priv, []byte(message))
	sigHex := hex.EncodeToString(sig)

	v := Voucher{
		RecipientPublicKey: pubHex,
		SenderKeyHash:      senderKeyHash,
		Expiry:             expiry,
		Signature:          sigHex,
	}

	// Verify valid voucher
	ok, err := VerifyVoucher(recipientID, v)
	if err != nil {
		t.Fatalf("failed to verify valid voucher: %v", err)
	}
	if !ok {
		t.Errorf("VerifyVoucher returned false for valid voucher")
	}

	// Verify expired voucher
	vExpired := v
	vExpired.Expiry = time.Now().Add(-1 * time.Hour).Unix()
	// re-sign for expired
	msgExpired := fmt.Sprintf("%s:%d", senderKeyHash, vExpired.Expiry)
	sigExpired := ed25519.Sign(priv, []byte(msgExpired))
	vExpired.Signature = hex.EncodeToString(sigExpired)

	ok, err = VerifyVoucher(recipientID, vExpired)
	if err == nil {
		t.Errorf("expected error for expired voucher, got nil")
	}
	if ok {
		t.Errorf("VerifyVoucher returned true for expired voucher")
	}

	// Verify signature mismatch fails
	vBadSig := v
	vBadSig.Signature = "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
	ok, err = VerifyVoucher(recipientID, vBadSig)
	if ok {
		t.Errorf("expected verification failure (ok=false) for bad signature")
	}
}
