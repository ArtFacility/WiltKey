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
	"strings"
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

// handlePostStory handles POST /api/v1/stories/post
func handlePostStory(w http.ResponseWriter, r *http.Request) {
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

	signedMessage := fmt.Sprintf("WILTKEY_STORY_POST:%s:%s:%d", req.ID, req.StoryType, req.Timestamp)
	if !verifySocialIdentity(w, ip, req, signedMessage) {
		return
	}

	if req.StoryType == "" || req.CiphertextB64 == "" {
		http.Error(w, `{"error":"Missing story_type or ciphertext_b64"}`, http.StatusBadRequest)
		return
	}

	if pg == nil {
		http.Error(w, `{"error":"PostgreSQL storage unavailable"}`, http.StatusServiceUnavailable)
		return
	}

	isPlus, err := checkPremiumSubscription(req.ID)
	if err != nil {
		log.Printf("[Social] Failed to check premium subscription for %s: %v", req.ID, err)
		isPlus = false
	}

	bytesUsed := int64(len(req.CiphertextB64))
	allowed, used, maxBytes, err := pg.ConsumeSocialBudget(req.ID, bytesUsed, isPlus)
	if err != nil {
		log.Printf("[Social] Failed to check/consume budget for %s: %v", req.ID, err)
		http.Error(w, `{"error":"Database error checking weekly budget"}`, http.StatusInternalServerError)
		return
	}

	if !allowed {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusTooManyRequests)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error":      "Weekly social budget quota exceeded",
			"bytes_used": used,
			"max_bytes":  maxBytes,
		})
		return
	}

	ttl := 24 * time.Hour
	storyID, err := pg.PostStory(req.ID, req.StoryType, req.CiphertextB64, req.BucketURL, req.MediaMeta, bytesUsed, ttl)
	if err != nil {
		log.Printf("[Social] Failed to insert story for %s: %v", req.ID, err)
		http.Error(w, `{"error":"Failed to store story"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":     "ok",
		"story_id":   storyID,
		"bytes_used": used,
		"max_bytes":  maxBytes,
		"expires_at": time.Now().Add(ttl).Unix(),
	})
}

// handleGetStoriesFeed handles POST /api/v1/stories/feed
func handleGetStoriesFeed(w http.ResponseWriter, r *http.Request) {
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

	signedMessage := fmt.Sprintf("WILTKEY_STORY_FEED:%s:%d", req.ID, req.Timestamp)
	if !verifySocialIdentity(w, ip, req, signedMessage) {
		return
	}

	if pg == nil {
		http.Error(w, `{"error":"PostgreSQL storage unavailable"}`, http.StatusServiceUnavailable)
		return
	}

	// Include self in the contacts feed list so author can always see their own stories
	senders := append([]string{req.ID}, req.Contacts...)

	stories, err := pg.GetStoriesFeed(senders)
	if err != nil {
		log.Printf("[Social] Failed to query stories feed for %s: %v", req.ID, err)
		http.Error(w, `{"error":"Failed to fetch feed"}`, http.StatusInternalServerError)
		return
	}

	if stories == nil {
		stories = []PGStory{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "ok",
		"stories": stories,
	})
}

// handleReactStory handles POST /api/v1/stories/react
func handleReactStory(w http.ResponseWriter, r *http.Request) {
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

	signedMessage := fmt.Sprintf("WILTKEY_STORY_REACT:%s:%s:%s:%d", req.ID, req.StoryID, req.Emoji, req.Timestamp)
	if !verifySocialIdentity(w, ip, req, signedMessage) {
		return
	}

	if req.StoryID == "" || req.Emoji == "" {
		http.Error(w, `{"error":"Missing story_id or emoji"}`, http.StatusBadRequest)
		return
	}

	if pg == nil {
		http.Error(w, `{"error":"PostgreSQL storage unavailable"}`, http.StatusServiceUnavailable)
		return
	}

	story, err := pg.GetStory(req.StoryID)
	if err != nil || story == nil {
		http.Error(w, `{"error":"Story not found or expired"}`, http.StatusNotFound)
		return
	}

	if err := pg.AddOrUpdateStoryReaction(req.StoryID, req.ID, req.Emoji); err != nil {
		log.Printf("[Social] Failed to record reaction on story %s: %v", req.StoryID, err)
		http.Error(w, `{"error":"Failed to record reaction"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status": "ok",
	})
}

// handleStoryReactions handles GET /api/v1/stories/{id}/reactions
func handleStoryReactions(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ip := clientIP(r)

	pathParts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(pathParts) < 4 {
		http.Error(w, "Invalid story URL", http.StatusBadRequest)
		return
	}
	storyID := pathParts[3]

	q := r.URL.Query()
	userID := q.Get("user_id")
	pubkey := q.Get("pubkey")
	timestamp := q.Get("timestamp")
	sig := q.Get("sig")

	signedMsg := fmt.Sprintf("WILTKEY_STORY_REACTIONS:%s:%s:%s", storyID, userID, timestamp)
	if !verifyQueryIdentity(w, ip, userID, pubkey, timestamp, sig, signedMsg) {
		return
	}

	if pg == nil {
		http.Error(w, `{"error":"PostgreSQL unavailable"}`, http.StatusServiceUnavailable)
		return
	}

	story, err := pg.GetStory(storyID)
	if err != nil || story == nil {
		http.Error(w, "Story not found or expired", http.StatusNotFound)
		return
	}

	if story.SenderID != userID {
		http.Error(w, "Only story author can inspect reactions", http.StatusForbidden)
		return
	}

	reactions, err := pg.GetStoryReactions(storyID)
	if err != nil {
		http.Error(w, "Failed to query reactions", http.StatusInternalServerError)
		return
	}

	if reactions == nil {
		reactions = []PGStoryReaction{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "ok",
		"reactions": reactions,
	})
}

// handleDeleteStory handles DELETE /api/v1/stories/{id}
func handleDeleteStory(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete && r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ip := clientIP(r)

	pathParts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(pathParts) < 4 {
		http.Error(w, "Invalid story URL", http.StatusBadRequest)
		return
	}
	storyID := pathParts[3]

	q := r.URL.Query()
	userID := q.Get("user_id")
	pubkey := q.Get("pubkey")
	timestamp := q.Get("timestamp")
	sig := q.Get("sig")

	signedMsg := fmt.Sprintf("WILTKEY_STORY_DELETE:%s:%s:%s", storyID, userID, timestamp)
	if !verifyQueryIdentity(w, ip, userID, pubkey, timestamp, sig, signedMsg) {
		return
	}

	if pg == nil {
		http.Error(w, `{"error":"PostgreSQL unavailable"}`, http.StatusServiceUnavailable)
		return
	}

	if err := pg.DeleteStory(storyID, userID); err != nil {
		log.Printf("[Social] Failed to delete story %s for %s: %v", storyID, userID, err)
		http.Error(w, "Failed to delete story", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status": "ok",
	})
}

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
