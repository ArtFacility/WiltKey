package main

import (
	"context"
	crypto_rand "crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"math/big"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/shirou/gopsutil/v3/mem"
)

var rdb *RedisClient
var pg *PostgresClient
var storage ObjectStorage

// clientIP resolves the real client IP for rate-limiting / bans. In production the
// relay only ever sees traffic from nginx on loopback (ufw blocks the relay port),
// so r.RemoteAddr is always 127.0.0.1 — using it directly collapses every user into
// one shared bucket. We therefore trust X-Real-IP / X-Forwarded-For ONLY when the
// direct peer is loopback (our own reverse proxy); otherwise a client could spoof
// those headers to evade a ban. If not proxied, RemoteAddr is used as-is.
func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	if host == "127.0.0.1" || host == "::1" {
		if xr := strings.TrimSpace(r.Header.Get("X-Real-IP")); xr != "" {
			return xr
		}
		if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
			// First entry is the original client; the rest are proxy hops.
			return strings.TrimSpace(strings.Split(xff, ",")[0])
		}
	}
	return host
}

// IP middleware to enforce rate-limiting and validation failure bans
func rateLimitMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ip := clientIP(r)

		// 1. Check IP Ban
		banned, err := rdb.CheckIPBan(ip)
		if err != nil {
			http.Error(w, `{"error":"Database error check ban"}`, http.StatusInternalServerError)
			return
		}
		if banned {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusForbidden)
			w.Write([]byte(`{"error":"Banned"}`))
			return
		}

		// 2. Check Rate Limit (max 10 requests per minute)
		allowed, err := rdb.CheckIPRateLimit(ip, 10)
		if err != nil {
			http.Error(w, `{"error":"Database error check rate limit"}`, http.StatusInternalServerError)
			return
		}
		if !allowed {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`{"error":"Rate limit exceeded"}`))
			return
		}

		next.ServeHTTP(w, r)
	}
}

// Log a validation failure and escalate IP bans if necessary
func handleValidationFailure(w http.ResponseWriter, ip string, reason string) {
	fails, err := rdb.IncrementIPFailure(ip)
	if err != nil {
		log.Printf("Failed to increment IP failure count: %v", err)
	}

	var banDuration time.Duration
	if fails == 1 {
		banDuration = 5 * time.Minute
	} else if fails >= 2 {
		banDuration = 30 * time.Minute
	}

	if banDuration > 0 {
		err = rdb.BanIP(ip, banDuration)
		if err != nil {
			log.Printf("Failed to ban IP %s: %v", ip, err)
		}
		log.Printf("IP %s banned for %v due to repeated validation failures. Reason: %s", ip, banDuration, reason)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusBadRequest)
	w.Write([]byte(fmt.Sprintf(`{"error":"Validation failed: %s"}`, reason)))
}

type ChallengeResponse struct {
	Challenge  string `json:"challenge"`
	Difficulty int    `json:"difficulty"`
}

// GET /api/v1/pow/challenge
func handleGetChallenge(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	challenge, err := GenerateChallenge()
	if err != nil {
		http.Error(w, "Failed to generate challenge", http.StatusInternalServerError)
		return
	}

	// 5 leading hex zeros (~1M hashes avg vs ~65k at difficulty 4). The client
	// reads this value from the challenge response, so raising it needs no client
	// change; it only raises the cost for anyone abusing the HTTP queue/post path.
	difficulty := 5
	err = rdb.StorePoWChallenge(challenge, difficulty)
	if err != nil {
		http.Error(w, "Failed to store challenge", http.StatusInternalServerError)
		return
	}

	resp := ChallengeResponse{
		Challenge:  challenge,
		Difficulty: difficulty,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// Payload size tiers (a single encrypted message/file envelope, NOT the OTP pad).
//   - < freeMaxPayload            → any user
//   - [freeMaxPayload, plusMaxPayload] → requires an active premium subscription
//   - > plusMaxPayload            → rejected for everyone (storage/DoS ceiling)
const (
	freeMaxPayload = 5 * 1024 * 1024  // 5 MB — free file-transfer limit
	plusMaxPayload = 50 * 1024 * 1024 // 50 MB — hard ceiling, premium included
)

// Offline-hold TTLs: how long a queued message waits for an offline RECIPIENT to
// come back online. Premium recipients (WiltKey Plus) get the longer hold.
const (
	freeHoldTTL = 24 * time.Hour // free / FOSS / self-host default
	plusHoldTTL = 72 * time.Hour // WiltKey Plus recipient
)

// holdTTLForRecipient returns the offline-queue TTL for a message addressed to
// recipientID: 72h if that recipient has an active premium subscription, else
// 24h. Keyed on the RECIPIENT (it's their queue that holds longer) — distinct
// from the >=5MB file gate, which is keyed on the sender. Fails safe to the free
// TTL on any lookup error.
func holdTTLForRecipient(recipientID string) time.Duration {
	hasSub, err := checkPremiumSubscription(recipientID)
	if err == nil && hasSub {
		return plusHoldTTL
	}
	return freeHoldTTL
}

// checkPremiumSubscription checks Redis and Postgres to verify if a user has a premium subscription.
func checkPremiumSubscription(userID string) (bool, error) {
	hash, err := rdb.GetEntitlementHash(userID)
	if err == nil && hash != "" {
		return true, nil
	}

	if pg != nil {
		ent, err := pg.GetEntitlement(userID)
		if err != nil {
			return false, err
		}
		if ent != nil && ent.VerificationKeyHash != "" {
			ttl := time.Until(ent.ExpiresAt)
			if ttl > 0 {
				rdb.StoreEntitlement(userID, ent.VerificationKeyHash, ttl)
			}
			return true, nil
		}
	}

	return false, nil
}

type PostMessageRequest struct {
	RecipientID string   `json:"recipient_id"`
	Envelope    string   `json:"envelope"`
	Challenge   string   `json:"challenge,omitempty"`
	Nonce       int64    `json:"nonce,omitempty"`
	Voucher     *Voucher `json:"voucher,omitempty"`
}

// POST /api/v1/queue/post
func handlePostQueue(hub *Hub) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		ip := clientIP(r)

		var req PostMessageRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}

		if req.RecipientID == "" || req.Envelope == "" {
			http.Error(w, "Missing recipient_id or envelope", http.StatusBadRequest)
			return
		}

		protection := r.Header.Get("X-Wiltkey-Spam-Protection")
		if protection == "" {
			protection = "pow" // fallback
		}

		if protection == "pow" {
			if req.Challenge == "" || req.Nonce == 0 {
				handleValidationFailure(w, ip, "missing pow fields")
				return
			}

			// Retrieve difficulty (also consumes/deletes the challenge to prevent reuse)
			difficulty, err := rdb.GetPoWChallengeDifficulty(req.Challenge)
			if err != nil {
				handleValidationFailure(w, ip, "invalid/expired challenge")
				return
			}

			// Verify nonce is unique
			unique, err := rdb.IsNonceUnique(strconv.FormatInt(req.Nonce, 10))
			if err != nil || !unique {
				handleValidationFailure(w, ip, "replay attack detected (used nonce)")
				return
			}

			// Verify mathematical puzzle
			valid := VerifyPoW(req.Challenge, req.Nonce, req.Envelope, difficulty)
			if !valid {
				handleValidationFailure(w, ip, "incorrect proof of work")
				return
			}

		} else if protection == "voucher" {
			if req.Voucher == nil {
				handleValidationFailure(w, ip, "missing voucher structure")
				return
			}

			valid, err := VerifyVoucher(req.RecipientID, *req.Voucher)
			if err != nil || !valid {
				reason := "invalid voucher"
				if err != nil {
					reason = err.Error()
				}
				handleValidationFailure(w, ip, reason)
				return
			}

			// Single-use: a valid voucher (signed by the recipient authorizing a
			// sender) otherwise bypasses PoW and could be replayed indefinitely.
			// Bind it by signature so it can only post once.
			fresh, err := rdb.ConsumeVoucher(req.Voucher.Signature, req.Voucher.Expiry)
			if err != nil {
				http.Error(w, "Database error", http.StatusInternalServerError)
				return
			}
			if !fresh {
				handleValidationFailure(w, ip, "voucher already used or expired")
				return
			}
		} else {
			http.Error(w, "Unsupported spam protection mechanism", http.StatusBadRequest)
			return
		}

		// Verify recipient queue is not blocked (Nuke command active)
		blocked, err := rdb.IsQueueBlocked(req.RecipientID)
		if err != nil {
			http.Error(w, "Database error", http.StatusInternalServerError)
			return
		}
		if blocked {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusLocked) // 423 Locked
			w.Write([]byte(`{"error":"Recipient queue is locked due to active Nuke command"}`))
			return
		}

		senderID := "offline_queue_router"
		if req.Voucher != nil {
			senderID = req.Voucher.SenderKeyHash
		}

		payloadSize := int64(len(req.Envelope))

		// 0. Hard size ceiling — reject oversized payloads outright.
		if payloadSize > plusMaxPayload {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusRequestEntityTooLarge)
			w.Write([]byte(`{"error":"Payload exceeds the 50MB maximum"}`))
			return
		}

		// 1. Google subscriptions check for >= 5MB payloads
		if payloadSize >= freeMaxPayload {
			if req.Voucher == nil {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusForbidden)
				w.Write([]byte(`{"error":"Payload >= 5MB requires sender identity via voucher for subscription check"}`))
				return
			}
			hasSub, err := checkPremiumSubscription(senderID)
			if err != nil || !hasSub {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusForbidden)
				w.Write([]byte(`{"error":"Payload >= 5MB requires an active premium subscription"}`))
				return
			}
		}

		// 2. Large file routing (>= 500KB) -> storage bucket + Postgres
		if payloadSize >= 500*1024 {
			if pg == nil {
				http.Error(w, "Postgres and storage must be configured to process large payloads", http.StatusInternalServerError)
				return
			}
			storageKey := uuid.New().String()
			bucketURL, err := storage.Upload(r.Context(), storageKey, strings.NewReader(req.Envelope), payloadSize, "application/octet-stream")
			if err != nil {
				log.Printf("Failed to upload payload to storage: %v", err)
				http.Error(w, "Failed to upload large file to storage", http.StatusInternalServerError)
				return
			}

			// Store link in postgres (recipient-based offline hold TTL)
			messageID, err := pg.StoreMessage(req.RecipientID, senderID, nil, &bucketURL, "file", holdTTLForRecipient(req.RecipientID))
			if err != nil {
				storage.Delete(r.Context(), storageKey) // rollback storage
				log.Printf("Failed to store message metadata in Postgres: %v", err)
				http.Error(w, "Failed to store message metadata in database", http.StatusInternalServerError)
				return
			}

			// Deliver directly if online
			hub.mu.RLock()
			target, ok := hub.clients[req.RecipientID]
			hub.mu.RUnlock()
			if ok {
				target.SendJSON(WSMessage{
					Type:        "NEW_MESSAGE",
					SenderID:    senderID,
					Envelope:    req.Envelope,
					ContentType: "file",
					MessageID:   messageID,
				})
			} else {
				go hub.sendWakePush(req.RecipientID, senderID, "file")
			}

			w.WriteHeader(http.StatusAccepted) // 202 Accepted
			w.Write([]byte(`{"status":"Accepted","message_id":"` + messageID + `"}`))
			return
		}

		// 3. High RAM check -> Postgres inline (under 500KB)
		if pg != nil && isHighRAMLoad() {
			messageID, err := pg.StoreMessage(req.RecipientID, senderID, &req.Envelope, nil, "text", holdTTLForRecipient(req.RecipientID))
			if err != nil {
				log.Printf("Failed to store message in Postgres under high memory: %v", err)
				http.Error(w, "Failed to store message in database", http.StatusInternalServerError)
				return
			}

			hub.mu.RLock()
			target, ok := hub.clients[req.RecipientID]
			hub.mu.RUnlock()
			if ok {
				target.SendJSON(WSMessage{
					Type:        "NEW_MESSAGE",
					SenderID:    senderID,
					Envelope:    req.Envelope,
					ContentType: "text",
				})
				// Delete inline message immediately from DB once sent
				pg.DeleteMessage(messageID)
			} else {
				go hub.sendWakePush(req.RecipientID, senderID, "text")
			}

			w.WriteHeader(http.StatusAccepted)
			w.Write([]byte(`{"status":"Accepted"}`))
			return
		}

		// 4. Normal routing (under 500KB, normal RAM) -> Redis
		hub.mu.RLock()
		target, ok := hub.clients[req.RecipientID]
		hub.mu.RUnlock()

		if ok {
			target.SendJSON(WSMessage{
				Type:     "NEW_MESSAGE",
				SenderID: senderID,
				Envelope: req.Envelope,
			})
		} else {
			err = rdb.AddMessageToQueue(req.RecipientID, senderID, req.Envelope, "", holdTTLForRecipient(req.RecipientID))
			if err != nil {
				http.Error(w, "Failed to store message offline", http.StatusInternalServerError)
				return
			}
			go hub.sendWakePush(req.RecipientID, senderID, "")
		}

		w.WriteHeader(http.StatusAccepted) // 202 Accepted
		w.Write([]byte(`{"status":"Accepted"}`))
	}
}

type QueueStatusResponse struct {
	HasPayload bool `json:"has_payload"`
	Blocked    bool `json:"blocked"`
}

// GET /api/v1/queue/status (For passive polling Mode B)
func handleQueueStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	ip := clientIP(r)

	q := r.URL.Query()
	id := q.Get("id")
	timestampStr := q.Get("timestamp")
	sig := q.Get("sig")
	pubkey := q.Get("pubkey")

	if id == "" || timestampStr == "" || sig == "" || pubkey == "" {
		http.Error(w, "Missing query parameters", http.StatusBadRequest)
		return
	}

	timestamp, err := strconv.ParseInt(timestampStr, 10, 64)
	if err != nil {
		http.Error(w, "Invalid timestamp", http.StatusBadRequest)
		return
	}

	// 1. Verify timestamp drift (max 30 seconds)
	drift := math.Abs(float64(time.Now().Unix() - timestamp))
	if drift > 30 {
		handleValidationFailure(w, ip, "timestamp drift too high")
		return
	}

	// 2. Validate id matches SHA-256(pubkey)
	pubBytes, err := hex.DecodeString(pubkey)
	if err != nil {
		http.Error(w, "Invalid pubkey hex format", http.StatusBadRequest)
		return
	}
	if GenerateUserID(pubBytes) != id {
		handleValidationFailure(w, ip, "identity public key mismatch")
		return
	}

	// 3. Verify signature of id:timestamp
	message := fmt.Sprintf("%s:%d", id, timestamp)
	ok, err := VerifySignature(pubkey, sig, []byte(message))
	if err != nil || !ok {
		handleValidationFailure(w, ip, "invalid authentication signature")
		return
	}

	// 4. Query queue status
	blocked, err := rdb.IsQueueBlocked(id)
	if err != nil {
		http.Error(w, "Database error checking block status", http.StatusInternalServerError)
		return
	}

	count, err := rdb.GetActiveQueueCount(id)
	if err != nil {
		http.Error(w, "Database error fetching queue count", http.StatusInternalServerError)
		return
	}

	resp := QueueStatusResponse{
		HasPayload: count > 0,
		Blocked:    blocked,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

type PairInitRequest struct {
	InitiatorID string `json:"initiator_id"`
	Pubkey      string `json:"pubkey"`
	BufferBytes int64  `json:"buffer_bytes"`
}

type PairInitResponse struct {
	PIN string `json:"pin"`
}

type PairState struct {
	InitiatorID  string `json:"initiator_id"`
	InitiatorPub string `json:"initiator_pub"`
	BufferBytes  int64  `json:"buffer_bytes"`
	ReceiverID   string `json:"receiver_id,omitempty"`
	ReceiverPub  string `json:"receiver_pub,omitempty"`
}

func handlePairInit(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req PairInitRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	if req.InitiatorID == "" || req.Pubkey == "" {
		http.Error(w, "Missing fields", http.StatusBadRequest)
		return
	}

	var pin string
	for i := 0; i < 5; i++ {
		n, err := crypto_rand.Int(crypto_rand.Reader, big.NewInt(900000))
		if err != nil {
			http.Error(w, "Entropy failure", http.StatusInternalServerError)
			return
		}
		candidate := fmt.Sprintf("%06d", n.Int64()+100000)

		_, err = rdb.GetPairing(candidate)
		if err != nil {
			pin = candidate
			break
		}
	}

	if pin == "" {
		http.Error(w, "PIN collision timeout", http.StatusInternalServerError)
		return
	}

	state := PairState{
		InitiatorID:  req.InitiatorID,
		InitiatorPub: req.Pubkey,
		BufferBytes:  req.BufferBytes,
	}

	stateBytes, _ := json.Marshal(state)
	err := rdb.StorePairing(pin, string(stateBytes), 5*time.Minute)
	if err != nil {
		http.Error(w, "Database error storing pairing", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(PairInitResponse{PIN: pin})
}

type PairJoinRequest struct {
	PIN        string `json:"pin"`
	ReceiverID string `json:"receiver_id"`
	Pubkey     string `json:"pubkey"`
}

func handlePairJoin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req PairJoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	if req.PIN == "" || req.ReceiverID == "" || req.Pubkey == "" {
		http.Error(w, "Missing fields", http.StatusBadRequest)
		return
	}

	data, err := rdb.GetPairing(req.PIN)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte(`{"error":"Invalid or expired PIN"}`))
		return
	}

	var state PairState
	if err := json.Unmarshal([]byte(data), &state); err != nil {
		http.Error(w, "State corrupted", http.StatusInternalServerError)
		return
	}

	state.ReceiverID = req.ReceiverID
	state.ReceiverPub = req.Pubkey

	stateBytes, _ := json.Marshal(state)
	err = rdb.StorePairing(req.PIN, string(stateBytes), 2*time.Minute)
	if err != nil {
		http.Error(w, "Database error updating pairing", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"initiator_id": state.InitiatorID,
		"pubkey":       state.InitiatorPub,
		"buffer_bytes": state.BufferBytes,
	})
}

func handlePairPoll(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	pin := r.URL.Query().Get("pin")
	id := r.URL.Query().Get("id")

	if pin == "" || id == "" {
		http.Error(w, "Missing parameters", http.StatusBadRequest)
		return
	}

	data, err := rdb.GetPairing(pin)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "expired"})
		return
	}

	var state PairState
	if err := json.Unmarshal([]byte(data), &state); err != nil {
		http.Error(w, "State corrupted", http.StatusInternalServerError)
		return
	}

	if state.InitiatorID != id {
		http.Error(w, "Unauthorized poll", http.StatusUnauthorized)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if state.ReceiverID != "" {
		rdb.DeletePairing(pin)

		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":      "joined",
			"receiver_id": state.ReceiverID,
			"pubkey":      state.ReceiverPub,
		})
	} else {
		json.NewEncoder(w).Encode(map[string]string{"status": "pending"})
	}
}

// isHighRAMLoad returns true if virtual memory usage is above the configured threshold.
func isHighRAMLoad() bool {
	thresholdPercent := 80.0
	if pctStr := os.Getenv("HIGH_RAM_THRESHOLD_PERCENT"); pctStr != "" {
		if pct, err := strconv.ParseFloat(pctStr, 64); err == nil {
			thresholdPercent = pct
		}
	}

	v, err := mem.VirtualMemory()
	if err != nil {
		log.Printf("Warning: Failed to check virtual memory stats: %v", err)
		return false
	}
	return v.UsedPercent >= thresholdPercent
}

// startCleanupWorker periodically prunes expired Postgres records and deletes their S3/local files.
func startCleanupWorker(pg *PostgresClient, storage ObjectStorage) {
	ticker := time.NewTicker(5 * time.Minute)
	go func() {
		for range ticker.C {
			if pg == nil {
				continue
			}
			log.Println("[Cleanup] Running expired messages pruner...")
			deletedURLs, err := pg.PruneExpiredMessages()
			if err != nil {
				log.Printf("[Cleanup Error] Failed to prune expired messages: %v", err)
				continue
			}
			if len(deletedURLs) > 0 {
				log.Printf("[Cleanup] Pruned %d expired database records. Deleting associated files...", len(deletedURLs))
				for _, rawURL := range deletedURLs {
					var key string
					if strings.HasPrefix(rawURL, "local://") {
						key = strings.TrimPrefix(rawURL, "local://")
					} else {
						// For S3: e.g. http://minio:9000/wiltkey-files/some-uuid
						parts := strings.Split(rawURL, "/")
						if len(parts) > 0 {
							key = parts[len(parts)-1]
						}
					}
					if key != "" {
						if err := storage.Delete(context.Background(), key); err != nil {
							log.Printf("[Cleanup Error] Failed to delete object %s from storage: %v", key, err)
						} else {
							log.Printf("[Cleanup] Deleted object %s from storage", key)
						}
					}
				}
			}
		}
	}()
}

type EntitlementRequest struct {
	UserID           string `json:"user_id"`
	Pubkey           string `json:"pubkey"`
	Signature        string `json:"signature"`
	Timestamp        int64  `json:"timestamp"`
	PurchaseToken    string `json:"purchase_token"`
	SubscriptionHash string `json:"subscription_hash"`
}

// handlePostEntitlement registers a verified/mock subscription hash in Postgres and Redis.
func handlePostEntitlement(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if pg == nil {
		http.Error(w, `{"error":"Postgres is not configured"}`, http.StatusInternalServerError)
		return
	}

	ip := clientIP(r)

	var req EntitlementRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.UserID == "" || req.Pubkey == "" || req.Signature == "" || req.Timestamp == 0 {
		http.Error(w, "Missing authentication fields", http.StatusBadRequest)
		return
	}

	drift := math.Abs(float64(time.Now().Unix() - req.Timestamp))
	if drift > 30 {
		handleValidationFailure(w, ip, "timestamp drift too high")
		return
	}

	pubBytes, err := hex.DecodeString(req.Pubkey)
	if err != nil {
		http.Error(w, "Invalid pubkey hex format", http.StatusBadRequest)
		return
	}
	if GenerateUserID(pubBytes) != req.UserID {
		handleValidationFailure(w, ip, "identity public key mismatch")
		return
	}

	message := fmt.Sprintf("%s:%d", req.UserID, req.Timestamp)
	ok, err := VerifySignature(req.Pubkey, req.Signature, []byte(message))
	if err != nil || !ok {
		handleValidationFailure(w, ip, "invalid authentication signature")
		return
	}

	if req.PurchaseToken == "" && req.SubscriptionHash == "" {
		http.Error(w, "Missing subscription token or hash", http.StatusBadRequest)
		return
	}

	var hashToStore string
	if req.SubscriptionHash != "" {
		hashToStore = req.SubscriptionHash
	} else {
		hash := sha256.Sum256([]byte(req.PurchaseToken))
		hashToStore = hex.EncodeToString(hash[:])
	}

	expiry := time.Now().Add(30 * 24 * time.Hour)
	err = pg.StoreEntitlement(req.UserID, hashToStore, expiry)
	if err != nil {
		log.Printf("Failed to store entitlement: %v", err)
		http.Error(w, "Database error storing entitlement", http.StatusInternalServerError)
		return
	}

	err = rdb.StoreEntitlement(req.UserID, hashToStore, 30*24*time.Hour)
	if err != nil {
		log.Printf("Failed to store entitlement in Redis: %v", err)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf(`{"status":"success","expires_at":%d}`, expiry.Unix())))
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}

	var err error
	rdb, err = NewRedisClient(redisAddr)
	if err != nil {
		log.Fatalf("Failed to initialize Redis connection: %v", err)
	}
	defer rdb.Close()
	log.Printf("Connected to Redis at %s", redisAddr)

	// 1. Initialize Postgres
	postgresURL := os.Getenv("POSTGRES_URL")
	if postgresURL != "" {
		pg, err = NewPostgresClient(postgresURL)
		if err != nil {
			log.Fatalf("Failed to initialize Postgres: %v", err)
		}
		defer pg.Close()
		log.Println("Connected to Postgres database successfully")
	} else {
		log.Println("Warning: POSTGRES_URL not configured. Postgres message queue and entitlement support is disabled.")
	}

	// 2. Initialize Object Storage (S3 / MinIO or Local fallback)
	bucketEndpoint := os.Getenv("BUCKET_ENDPOINT")
	bucketAccessKey := os.Getenv("BUCKET_ACCESS_KEY")
	bucketSecretKey := os.Getenv("BUCKET_SECRET_KEY")
	bucketName := os.Getenv("BUCKET_NAME")
	if bucketName == "" {
		bucketName = "wiltkey-files"
	}
	useSSLStr := os.Getenv("BUCKET_USE_SSL")
	useSSL := useSSLStr == "true"

	if bucketEndpoint != "" && bucketAccessKey != "" && bucketSecretKey != "" {
		storage, err = NewS3Storage(bucketEndpoint, bucketAccessKey, bucketSecretKey, bucketName, useSSL)
		if err != nil {
			log.Fatalf("Failed to initialize S3 storage: %v", err)
		}
		log.Printf("Connected to S3 storage at %s, bucket %s", bucketEndpoint, bucketName)
	} else {
		localDir := "./wiltkey_local_storage"
		storage, err = NewLocalStorage(localDir)
		if err != nil {
			log.Fatalf("Failed to initialize local storage fallback: %v", err)
		}
		log.Printf("Warning: S3 bucket config incomplete. Using local storage fallback at %s", localDir)
	}

	// 3. Start background cleanup worker
	if pg != nil {
		startCleanupWorker(pg, storage)
	}

	// FCM wake-up push sender (Play flavor). Disabled/no-op unless
	// FCM_CREDENTIALS_FILE points at a Firebase service-account JSON.
	push := NewPushSender()

	hub := NewHub(rdb, push)
	go hub.Run()

	// HTTP Routing
	http.HandleFunc("/api/v1/pow/challenge", rateLimitMiddleware(handleGetChallenge))
	http.HandleFunc("/api/v1/queue/post", rateLimitMiddleware(handlePostQueue(hub)))
	http.HandleFunc("/api/v1/queue/status", rateLimitMiddleware(handleQueueStatus))
	http.HandleFunc("/api/v1/push/register", rateLimitMiddleware(handlePushRegister))
	http.HandleFunc("/api/v1/push/unregister", rateLimitMiddleware(handlePushUnregister))
	http.HandleFunc("/api/v1/pair/init", rateLimitMiddleware(handlePairInit))
	http.HandleFunc("/api/v1/pair/join", rateLimitMiddleware(handlePairJoin))
	http.HandleFunc("/api/v1/pair/poll", rateLimitMiddleware(handlePairPoll))
	http.HandleFunc("/api/v1/entitlement", rateLimitMiddleware(handlePostEntitlement))
	http.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	// WebSocket upgrading
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		ServeWS(hub, w, r)
	})

	log.Printf("Wiltkey Blind Relay listening on port %s...", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("HTTP server failed: %v", err)
	}
}
