package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"
)

type Voucher struct {
	RecipientPublicKey string `json:"recipient_public_key"`
	SenderKeyHash      string `json:"sender_key_hash"`
	Expiry             int64  `json:"expiry"`
	Signature          string `json:"signature"`
}

// VerifyVoucher checks if the voucher is valid, unexpired, and authenticates the recipient's target ID.
func VerifyVoucher(recipientID string, v Voucher) (bool, error) {
	// 1. Check expiration
	if v.Expiry < time.Now().Unix() {
		return false, fmt.Errorf("voucher expired")
	}

	// 2. Check that the recipient public key matches the target recipientID
	pubBytes, err := hex.DecodeString(v.RecipientPublicKey)
	if err != nil {
		return false, fmt.Errorf("invalid recipient public key format")
	}
	hash := sha256.Sum256(pubBytes)
	computedRecipientID := hex.EncodeToString(hash[:])
	if computedRecipientID != recipientID {
		return false, fmt.Errorf("recipient public key does not match recipient ID")
	}

	// 3. Reconstruct signed message format
	message := fmt.Sprintf("%s:%d", v.SenderKeyHash, v.Expiry)

	// 4. Verify signature
	ok, err := VerifySignature(v.RecipientPublicKey, v.Signature, []byte(message))
	if err != nil {
		return false, err
	}
	return ok, nil
}
