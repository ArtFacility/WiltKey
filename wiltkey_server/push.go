package main

import (
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math"
	"net/http"
	"time"
)

// PushRequest is the body for /api/v1/push/register and /unregister. Auth mirrors
// the queue/status endpoint: a fresh timestamp, id == SHA-256(pubkey), and an
// Ed25519 signature — proving the caller owns this identity and can therefore
// only set/clear its OWN token. Register binds the token into the signed message
// so it can't be swapped in flight; unregister signs id:timestamp.
type PushRequest struct {
	ID        string `json:"id"`
	Pubkey    string `json:"pubkey"`
	Timestamp int64  `json:"timestamp"`
	Sig       string `json:"sig"`
	Token     string `json:"token,omitempty"`
}

// verifyPushIdentity runs the shared timestamp/identity/signature checks. On
// failure it writes the response (via handleValidationFailure) and returns false.
func verifyPushIdentity(w http.ResponseWriter, ip string, req PushRequest, signedMessage string) bool {
	if req.ID == "" || req.Pubkey == "" || req.Sig == "" || req.Timestamp == 0 {
		http.Error(w, "Missing fields", http.StatusBadRequest)
		return false
	}

	// 1. Timestamp freshness (max 30s drift) — bounds replay of a captured request.
	drift := math.Abs(float64(time.Now().Unix() - req.Timestamp))
	if drift > 30 {
		handleValidationFailure(w, ip, "timestamp drift too high")
		return false
	}

	// 2. id must be SHA-256(pubkey).
	pubBytes, err := hex.DecodeString(req.Pubkey)
	if err != nil {
		http.Error(w, "Invalid pubkey hex format", http.StatusBadRequest)
		return false
	}
	if GenerateUserID(pubBytes) != req.ID {
		handleValidationFailure(w, ip, "identity public key mismatch")
		return false
	}

	// 3. Signature over the bound message.
	ok, err := VerifySignature(req.Pubkey, req.Sig, []byte(signedMessage))
	if err != nil || !ok {
		handleValidationFailure(w, ip, "invalid authentication signature")
		return false
	}
	return true
}

// POST /api/v1/push/register — store/refresh this user's FCM token. Play-flavor
// only; FOSS builds never call it. Signed message: "id:timestamp:token".
func handlePushRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ip := clientIP(r)

	var req PushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	if req.Token == "" {
		http.Error(w, "Missing token", http.StatusBadRequest)
		return
	}

	signed := fmt.Sprintf("%s:%d:%s", req.ID, req.Timestamp, req.Token)
	if !verifyPushIdentity(w, ip, req, signed) {
		return
	}

	if err := rdb.SetPushToken(req.ID, req.Token); err != nil {
		log.Printf("[Push Register Error] Failed to store FCM token for %s: %v", req.ID, err)
		http.Error(w, "Database error storing token", http.StatusInternalServerError)
		return
	}

	log.Printf("[Push Register Success] Stored FCM token for %s (token length: %d)", req.ID, len(req.Token))
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"registered"}`))
}

// POST /api/v1/push/unregister — drop this user's FCM token (mode set to
// Off/FOSS, logout, nuke). Signed message: "id:timestamp".
func handlePushUnregister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ip := clientIP(r)

	var req PushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	signed := fmt.Sprintf("%s:%d", req.ID, req.Timestamp)
	if !verifyPushIdentity(w, ip, req, signed) {
		return
	}

	if err := rdb.DeletePushToken(req.ID); err != nil {
		log.Printf("[Push Unregister Error] Failed to clear FCM token for %s: %v", req.ID, err)
		http.Error(w, "Database error clearing token", http.StatusInternalServerError)
		return
	}

	log.Printf("[Push Unregister Success] Cleared FCM token for %s", req.ID)
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"unregistered"}`))
}

// pushWorthyContentType mirrors the client's notify allowlist: only real user
// messages raise a wake-up ping. Control frames (receipts, resync, borrow,
// metadata, nuke, emoji ops) are queued but never wake the device. The empty
// string is the HTTP queue/post path (a genuine message whose type isn't tagged).
func pushWorthyContentType(ct string) bool {
	switch ct {
	case "", "text", "image", "voice", "group_message", "emergency_chat":
		return true
	default:
		return false
	}
}

// sendWakePush fires a content-free FCM ping to an offline recipient that has a
// registered token, so their Play-flavor app surfaces a notification without a
// persistent background socket. No-op when push is disabled, the content type
// isn't message-worthy, or no token is registered. Runs best-effort (call via
// `go`) — delivery is never on the message's critical path. A dead token is
// pruned so we stop trying.
func (h *Hub) sendWakePush(recipientID string, senderID string, contentType string) {
	if !h.push.Enabled() {
		return
	}
	if !pushWorthyContentType(contentType) {
		return
	}
	token, err := h.rdb.GetPushToken(recipientID)
	if err != nil {
		log.Printf("[Push] Error fetching push token for offline recipient %s: %v", recipientID, err)
		return
	}
	if token == "" {
		log.Printf("[Push] No push token registered for offline recipient %s (FOSS/no instant mode)", recipientID)
		return
	}
	log.Printf("[Push] Dispatching FCM wake push for offline recipient %s from sender %s (type: %s)", recipientID, senderID, contentType)
	if err := h.push.Send(token, senderID, contentType); err != nil {
		if errors.Is(err, errTokenUnregistered) {
			_ = h.rdb.DeletePushToken(recipientID)
			log.Printf("[Push] Pruned unregistered token for %s", recipientID)
		} else {
			log.Printf("[Push] Wake-up send failed for %s: %v", recipientID, err)
		}
	} else {
		log.Printf("[Push] FCM wake push successfully sent to %s", recipientID)
	}
}
