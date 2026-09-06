package main

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"strconv"
	"time"
)

// SocialRequest is the base payload for authenticated social endpoints.
type SocialRequest struct {
	ID            string   `json:"id"`
	Pubkey        string   `json:"pubkey"`
	Timestamp     int64    `json:"timestamp"`
	Sig           string   `json:"sig"`
	StoryType     string   `json:"story_type,omitempty"`
	CiphertextB64 string   `json:"ciphertext_b64,omitempty"`
	BucketURL     *string  `json:"bucket_url,omitempty"`
	MediaMeta     string   `json:"media_meta,omitempty"`
	Contacts      []string `json:"contacts,omitempty"`
	StoryID       string   `json:"story_id,omitempty"`
	Emoji         string   `json:"emoji,omitempty"`
}

func verifySocialIdentity(w http.ResponseWriter, ip string, req SocialRequest, signedMessage string) bool {
	if req.ID == "" || req.Pubkey == "" || req.Sig == "" || req.Timestamp == 0 {
		http.Error(w, `{"error":"Missing required authentication fields"}`, http.StatusBadRequest)
		return false
	}

	// 1. Timestamp freshness (max 60s drift)
	drift := math.Abs(float64(time.Now().Unix() - req.Timestamp))
	if drift > 60 {
		handleValidationFailure(w, ip, "timestamp drift too high")
		return false
	}

	// 2. ID must match SHA-256(pubkey)
	pubBytes, err := hex.DecodeString(req.Pubkey)
	if err != nil {
		http.Error(w, `{"error":"Invalid pubkey hex"}`, http.StatusBadRequest)
		return false
	}
	if GenerateUserID(pubBytes) != req.ID {
		handleValidationFailure(w, ip, "identity public key mismatch")
		return false
	}

	// 3. Ed25519 signature verification
	valid, err := VerifySignature(req.Pubkey, req.Sig, []byte(signedMessage))
	if err != nil || !valid {
		handleValidationFailure(w, ip, "invalid cryptographic signature")
		return false
	}

	return true
}

func verifyQueryIdentity(w http.ResponseWriter, ip, userID, pubkey, timestampStr, sig, signedMessage string) bool {
	if userID == "" || pubkey == "" || timestampStr == "" || sig == "" {
		http.Error(w, `{"error":"Missing authentication query parameters"}`, http.StatusBadRequest)
		return false
	}

	ts, err := strconv.ParseInt(timestampStr, 10, 64)
	if err != nil {
		http.Error(w, `{"error":"Invalid timestamp"}`, http.StatusBadRequest)
		return false
	}

	drift := math.Abs(float64(time.Now().Unix() - ts))
	if drift > 60 {
		handleValidationFailure(w, ip, "timestamp drift too high")
		return false
	}

	pubBytes, err := hex.DecodeString(pubkey)
	if err != nil {
		http.Error(w, `{"error":"Invalid pubkey hex"}`, http.StatusBadRequest)
		return false
	}
	if GenerateUserID(pubBytes) != userID {
		handleValidationFailure(w, ip, "identity public key mismatch")
		return false
	}

	valid, err := VerifySignature(pubkey, sig, []byte(signedMessage))
	if err != nil || !valid {
		handleValidationFailure(w, ip, "invalid cryptographic signature")
		return false
	}

	return true
}

// NOTE: The HTTP story handlers (POST /api/v1/stories/post, POST /feed,
// POST /react, GET /{id}/reactions, DELETE /{id}) were removed: a bare
// sig-over-timestamp was the only gate, so anyone with a self-minted keypair
// could post/interact at HTTP rate-limit speed. Stories now ride the
// authenticated WebSocket exclusively (handlers.go, "stories_ws" capability).
// The budget and wipe endpoints below remain HTTP — they are self-targeted
// (read own quota / delete own data) and cannot spam third parties.

// handleGetSocialBudget handles GET /api/v1/social/budget
func handleGetSocialBudget(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ip := clientIP(r)

	q := r.URL.Query()
	userID := q.Get("user_id")
	pubkey := q.Get("pubkey")
	timestamp := q.Get("timestamp")
	sig := q.Get("sig")

	signedMsg := fmt.Sprintf("WILTKEY_SOCIAL_BUDGET:%s:%s", userID, timestamp)
	if !verifyQueryIdentity(w, ip, userID, pubkey, timestamp, sig, signedMsg) {
		return
	}

	if pg == nil {
		http.Error(w, `{"error":"PostgreSQL unavailable"}`, http.StatusServiceUnavailable)
		return
	}

	isPlus, err := checkPremiumSubscription(userID)
	if err != nil {
		isPlus = false
	}

	var maxBudget int64 = 10 * 1024 * 1024
	if isPlus {
		maxBudget = 100 * 1024 * 1024
	}

	budget, err := pg.GetOrCreateSocialBudget(userID)
	if err != nil {
		http.Error(w, "Database error retrieving budget", http.StatusInternalServerError)
		return
	}

	resetInSecs := int64(7*24*3600) - int64(time.Since(budget.WeekStart).Seconds())
	if resetInSecs < 0 {
		resetInSecs = 0
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":           "ok",
		"user_id":          userID,
		"bytes_used":       budget.BytesUsed,
		"max_bytes":        maxBudget,
		"is_plus":          isPlus,
		"week_start":       budget.WeekStart.Unix(),
		"reset_in_seconds": resetInSecs,
	})
}

// handleSocialWipe handles POST /api/v1/social/wipe
func handleSocialWipe(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ip := clientIP(r)

	var req SocialRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid JSON"}`, http.StatusBadRequest)
		return
	}

	signedMessage := fmt.Sprintf("WILTKEY_SOCIAL_WIPE:%s:%d", req.ID, req.Timestamp)
	if !verifySocialIdentity(w, ip, req, signedMessage) {
		return
	}

	if pg == nil {
		http.Error(w, `{"error":"PostgreSQL storage unavailable"}`, http.StatusServiceUnavailable)
		return
	}

	deletedURLs, err := pg.WipeUserSocialData(req.ID)
	if err != nil {
		log.Printf("[Social] Failed to wipe social data for %s: %v", req.ID, err)
		http.Error(w, `{"error":"Failed to wipe social data"}`, http.StatusInternalServerError)
		return
	}

	if storage != nil && len(deletedURLs) > 0 {
		for _, rawURL := range deletedURLs {
			key := storageKeyFromURL(rawURL)
			if key != "" {
				_ = storage.Delete(context.Background(), key)
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "ok",
		"message": "All social data wiped successfully",
	})
}
