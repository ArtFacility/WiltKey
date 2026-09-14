package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
)

// handleSendMessage routes a standard encrypted 1-on-1 message.
func (c *Client) handleSendMessage(msg WSMessage) {
	log.Printf("[Relay] Received message routing request. Sender: %s, Recipient: %s, Content-Type: %s, Envelope length: %d bytes.", c.id, msg.RecipientID, msg.ContentType, len(msg.Envelope))
	if msg.RecipientID == "" {
		log.Printf("[Relay Error] Missing recipient_id from %s", c.id)
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Missing recipient_id"})
		return
	}

	// Check if queue blocked (nuked)
	blocked, err := c.hub.rdb.IsQueueBlocked(msg.RecipientID)
	if err != nil {
		log.Printf("[Relay Error] Database error checking queue status for recipient %s: %v", msg.RecipientID, err)
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Database error checking queue status"})
		return
	}
	if blocked {
		log.Printf("[Relay Warning] Recipient queue %s is locked due to active Nuke command", msg.RecipientID)
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Recipient queue is locked due to active Nuke command"})
		return
	}

	payloadSize := int64(len(msg.Envelope))

	// 0. Hard size ceiling — reject oversized payloads outright (storage/DoS guard).
	if payloadSize > plusMaxPayload {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Payload exceeds the 50MB maximum"})
		return
	}

	// 1. Google subscriptions check for >= 5MB payloads (sender must be premium).
	if payloadSize >= freeMaxPayload {
		hasSub, err := checkPremiumSubscription(c.id)
		if err != nil || !hasSub {
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Payload >= 5MB requires an active premium subscription"})
			return
		}
	}

	// 1.5 Per-sender cooldown on large payloads. Checked AFTER the size/subscription
	// gates so a rejected message never burns the sender's window, and before the
	// expensive bucket upload + Postgres write. Fails OPEN: a Redis hiccup must not
	// block legitimate sends.
	if payloadSize >= largePayloadThreshold {
		allowed, rlErr := c.hub.rdb.AllowLargeUpload(c.id, largeUploadCooldown)
		if rlErr != nil {
			log.Printf("[Relay Warning] large-upload rate check failed for %s: %v — allowing", c.id, rlErr)
		} else if !allowed {
			log.Printf("[Relay] Client %s exceeded large-upload rate (1 per %s)", c.id, largeUploadCooldown)
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Sending large files too quickly — please wait a few seconds and try again"})
			return
		}
	}

	// Offline-hold TTL is keyed on the recipient's own subscription.
	holdTTL := holdTTLForRecipient(msg.RecipientID)

	// 2. Large file routing (>= 500KB) -> storage bucket + Postgres
	if payloadSize >= largePayloadThreshold {
		if pg == nil {
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Postgres and storage must be configured to process large payloads"})
			return
		}
		storageKey := uuid.New().String()
		bucketURL, err := storage.Upload(context.Background(), storageKey, strings.NewReader(msg.Envelope), payloadSize, "application/octet-stream")
		if err != nil {
			log.Printf("Failed to upload payload to storage: %v", err)
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to upload large file to storage"})
			return
		}

		// Strip the bulky ciphertext so the recipient can be told WHAT arrived
		// (which chat, which offset, reply/wilt flags) without shipping the body.
		offerMeta, metaOK := buildOfferMeta(msg.Envelope)

		// Store link in postgres
		messageID, err := pg.StoreMessageSized(msg.RecipientID, c.id, nil, &bucketURL, msg.ContentType, holdTTL, payloadSize, offerMeta)
		if err != nil {
			storage.Delete(context.Background(), storageKey) // rollback storage
			log.Printf("Failed to store message metadata in Postgres: %v", err)
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to store message metadata in database"})
			return
		}

		target, ok := c.hub.getClient(msg.RecipientID)
		if !metaOK {
			// Unparseable envelope (not our JSON shape) — fall back to the old
			// push-it-all behaviour rather than stranding the message.
			log.Printf("[Relay] Envelope for %s isn't offer-able; delivering inline", messageID)
			if ok {
				target.SendJSON(WSMessage{
					Type:        "NEW_MESSAGE",
					SenderID:    c.id,
					Envelope:    msg.Envelope,
					ContentType: msg.ContentType,
					MessageID:   messageID,
				})
			} else {
				go c.hub.sendWakePush(msg.RecipientID, c.id, msg.ContentType)
			}
			return
		}

		// Advertise the file. The body stays in the bucket until the recipient
		// downloads it and ACKs (FILE_RECEIVED), or the hold TTL expires — so an
		// interrupted or half-finished download can always be retried.
		if ok {
			target.SendJSON(WSMessage{
				Type:        "FILE_OFFER",
				SenderID:    c.id,
				ContentType: msg.ContentType,
				MessageID:   messageID,
				Meta:        offerMeta,
				Size:        payloadSize,
				ExpiresAt:   time.Now().Add(holdTTL).Unix(),
			})
		} else {
			go c.hub.sendWakePush(msg.RecipientID, c.id, msg.ContentType)
		}
		return
	}

	// 3+4. Sub-threshold routing (Postgres-inline under memory pressure, else
	// direct/Redis) — shared with the group fan-out path.
	if err := c.routeSmallMessage(msg.RecipientID, msg.Envelope, msg.ContentType, holdTTL); err != nil {
		log.Printf("[Relay Error] Failed to route message to %s: %v", msg.RecipientID, err)
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to route message"})
	}
}

// routeSmallMessage delivers ONE sub-[largePayloadThreshold] envelope to a single
// recipient: straight to the socket if they're online, else queued in Redis (or,
// under memory pressure, parked inline in Postgres and dropped once delivered).
// It returns an error WITHOUT notifying the sender, so the 1-on-1 path can turn
// that into an ERROR while the group fan-out can log-and-skip one bad recipient
// without aborting delivery to the rest of the group.
func (c *Client) routeSmallMessage(recipientID, envelope, contentType string, holdTTL time.Duration) error {
	// High RAM -> Postgres inline, delivered-then-deleted.
	if pg != nil && isHighRAMLoad() {
		messageID, err := pg.StoreMessage(recipientID, c.id, &envelope, nil, contentType, holdTTL)
		if err != nil {
			return fmt.Errorf("postgres inline store: %w", err)
		}
		if target, ok := c.hub.getClient(recipientID); ok {
			target.SendJSON(WSMessage{
				Type:        "NEW_MESSAGE",
				SenderID:    c.id,
				Envelope:    envelope,
				ContentType: contentType,
			})
			pg.DeleteMessage(messageID)
		} else {
			go c.hub.sendWakePush(recipientID, c.id, contentType)
		}
		return nil
	}

	// Normal -> direct if online, else Redis queue.
	if target, ok := c.hub.getClient(recipientID); ok {
		target.SendJSON(WSMessage{
			Type:        "NEW_MESSAGE",
			SenderID:    c.id,
			Envelope:    envelope,
			ContentType: contentType,
		})
	} else {
		if err := c.hub.rdb.AddMessageToQueue(recipientID, c.id, envelope, contentType, holdTTL); err != nil {
			return fmt.Errorf("redis queue: %w", err)
		}
		go c.hub.sendWakePush(recipientID, c.id, contentType)
	}
	return nil
}

// handleBroadcastGroupMessage is server-side fan-out: the sender uploads ONE
// envelope plus a recipient list, and the relay routes that identical envelope to
// each recipient (group envelopes are byte-identical — the group shares one
// keystream, so there is no per-recipient re-encryption). This replaces the old
// model where the sender fired N separate SEND_MESSAGE frames, each carrying the
// full envelope — brutal for images. For large files the body is uploaded to the
// bucket ONCE and shared by N Postgres pointer rows (see the ref-counted deletion
// in handleFileReceived / PruneExpiredMessages).
//
// The relay is group-blind: it cannot validate membership, so the recipient list
// is only a routing hint, capped + deduped + rate-charged to bound amplification,
// and discarded after fan-out (never persisted as a group).
func (c *Client) handleBroadcastGroupMessage(msg WSMessage) {
	// Dedupe + drop self/empties so a repeated id can't queue N copies for one
	// victim, and so the cap counts distinct recipients.
	seen := make(map[string]struct{}, len(msg.Recipients))
	recipients := make([]string, 0, len(msg.Recipients))
	for _, r := range msg.Recipients {
		if r == "" || r == c.id {
			continue
		}
		if _, dup := seen[r]; dup {
			continue
		}
		seen[r] = struct{}{}
		recipients = append(recipients, r)
	}
	if len(recipients) == 0 {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "No recipients"})
		return
	}
	if len(recipients) > maxBroadcastRecipients {
		log.Printf("[Relay] Client %s broadcast to %d recipients exceeds cap %d", c.id, len(recipients), maxBroadcastRecipients)
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Too many recipients"})
		return
	}

	// Amplification guard: one frame does N recipients' work, so charge N tokens
	// from the flood bucket (readPump already took 1). Same goroutine as readPump,
	// so touching c.tokens here is lock-free. Negative is fine — it just throttles
	// the sender's next frames until the bucket refills.
	c.tokens -= float64(len(recipients) - 1)

	payloadSize := int64(len(msg.Envelope))

	// Sender-side gates run ONCE per broadcast (not per recipient).
	if payloadSize > plusMaxPayload {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Payload exceeds the 50MB maximum"})
		return
	}
	if payloadSize >= freeMaxPayload {
		hasSub, err := checkPremiumSubscription(c.id)
		if err != nil || !hasSub {
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Payload >= 5MB requires an active premium subscription"})
			return
		}
	}
	if payloadSize >= largePayloadThreshold {
		allowed, rlErr := c.hub.rdb.AllowLargeUpload(c.id, largeUploadCooldown)
		if rlErr != nil {
			log.Printf("[Relay Warning] large-upload rate check failed for %s: %v — allowing", c.id, rlErr)
		} else if !allowed {
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Sending large files too quickly — please wait a few seconds and try again"})
			return
		}
	}

	log.Printf("[Relay] Group fan-out from %s to %d recipients, content-type %s, %d bytes", c.id, len(recipients), msg.ContentType, payloadSize)

	// Large-file path: upload the body to the bucket ONCE, then fan out pointers.
	if payloadSize >= largePayloadThreshold {
		c.broadcastLargeFile(recipients, msg)
		return
	}

	// Small path: route the identical envelope to each recipient. Per-recipient
	// failures (blocked/nuked queue, transient DB/Redis error) are logged and
	// skipped — one bad recipient must not drop the message for the whole group.
	for _, rid := range recipients {
		blocked, err := c.hub.rdb.IsQueueBlocked(rid)
		if err != nil {
			log.Printf("[Relay] fan-out: queue-status check failed for %s: %v — skipping", rid, err)
			continue
		}
		if blocked {
			log.Printf("[Relay] fan-out: recipient %s queue blocked (nuke) — skipping", rid)
			continue
		}
		holdTTL := holdTTLForRecipient(rid) // per-recipient perk (72h Plus / 24h free)
		if err := c.routeSmallMessage(rid, msg.Envelope, msg.ContentType, holdTTL); err != nil {
			log.Printf("[Relay] fan-out: failed to route to %s: %v — skipping", rid, err)
		}
	}
}

// broadcastLargeFile uploads a >= largePayloadThreshold group envelope to the
// bucket ONCE and advertises it to each recipient via its own Postgres pointer
// row (all sharing the single bucket object). The object is reference-counted:
// handleFileReceived / PruneExpiredMessages only delete it once the last pointer
// row is gone, so one recipient downloading (or a free member's shorter TTL
// expiring) can't strand the file for the others.
func (c *Client) broadcastLargeFile(recipients []string, msg WSMessage) {
	if pg == nil {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Postgres and storage must be configured to process large payloads"})
		return
	}
	payloadSize := int64(len(msg.Envelope))
	storageKey := uuid.New().String()
	bucketURL, err := storage.Upload(context.Background(), storageKey, strings.NewReader(msg.Envelope), payloadSize, "application/octet-stream")
	if err != nil {
		log.Printf("[Relay Error] fan-out: failed to upload payload to storage: %v", err)
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to upload large file to storage"})
		return
	}

	offerMeta, metaOK := buildOfferMeta(msg.Envelope)

	delivered := 0
	for _, rid := range recipients {
		blocked, err := c.hub.rdb.IsQueueBlocked(rid)
		if err != nil {
			log.Printf("[Relay] fan-out(file): queue-status check failed for %s: %v — skipping", rid, err)
			continue
		}
		if blocked {
			log.Printf("[Relay] fan-out(file): recipient %s queue blocked (nuke) — skipping", rid)
			continue
		}
		holdTTL := holdTTLForRecipient(rid)
		messageID, err := pg.StoreMessageSized(rid, c.id, nil, &bucketURL, msg.ContentType, holdTTL, payloadSize, offerMeta)
		if err != nil {
			log.Printf("[Relay] fan-out(file): failed to store pointer for %s: %v — skipping", rid, err)
			continue
		}
		delivered++

		target, ok := c.hub.getClient(rid)
		if !metaOK {
			// Unparseable envelope — fall back to inline delivery for online
			// recipients, matching the 1-on-1 large-file fallback.
			if ok {
				target.SendJSON(WSMessage{Type: "NEW_MESSAGE", SenderID: c.id, Envelope: msg.Envelope, ContentType: msg.ContentType, MessageID: messageID})
			} else {
				go c.hub.sendWakePush(rid, c.id, msg.ContentType)
			}
			continue
		}
		if ok {
			target.SendJSON(WSMessage{
				Type:        "FILE_OFFER",
				SenderID:    c.id,
				ContentType: msg.ContentType,
				MessageID:   messageID,
				Meta:        offerMeta,
				Size:        payloadSize,
				ExpiresAt:   time.Now().Add(holdTTL).Unix(),
			})
		} else {
			go c.hub.sendWakePush(rid, c.id, msg.ContentType)
		}
	}

	// No pointer rows were created (every recipient blocked/errored) → nothing
	// references the object, so reclaim it rather than orphaning it in the bucket.
	if delivered == 0 {
		storage.Delete(context.Background(), storageKey)
		log.Printf("[Relay] fan-out(file): no recipients accepted — reclaimed orphan object %s", storageKey)
	}
}

// buildOfferMeta returns the message envelope with its `d` ciphertext blanked,
// so a FILE_OFFER can tell the recipient which chat/offset/flags the pending
// file belongs to without transferring the body. Returns ok=false when the
// envelope isn't the expected JSON object with a `d` field — callers then fall
// back to inline delivery, keeping the relay agnostic about payload shape.
func buildOfferMeta(envelope string) (string, bool) {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal([]byte(envelope), &fields); err != nil {
		return "", false
	}
	if _, hasBody := fields["d"]; !hasBody {
		return "", false
	}
	fields["d"] = json.RawMessage(`""`)
	out, err := json.Marshal(fields)
	if err != nil {
		return "", false
	}
	return string(out), true
}

// handleRequestFile mints a short-lived download token for a pending large file,
// but only for the client that message is actually addressed to. The HTTP
// download endpoint has no auth of its own — this WebSocket check, which runs on
// an already signature-authenticated connection, is the gate.
func (c *Client) handleRequestFile(msg WSMessage) {
	if msg.MessageID == "" {
		c.SendJSON(WSMessage{Type: "FILE_ERROR", Message: "Missing message_id"})
		return
	}
	if pg == nil {
		c.SendJSON(WSMessage{Type: "FILE_ERROR", MessageID: msg.MessageID, Message: "File storage is not configured"})
		return
	}

	record, err := pg.GetFileMessage(msg.MessageID, c.id)
	if err != nil {
		log.Printf("[Relay Error] file lookup failed for %s: %v", msg.MessageID, err)
		c.SendJSON(WSMessage{Type: "FILE_ERROR", MessageID: msg.MessageID, Message: "Could not look up that file"})
		return
	}
	if record == nil {
		// Unknown, expired, already acknowledged, or addressed to someone else —
		// all indistinguishable to the caller on purpose.
		c.SendJSON(WSMessage{Type: "FILE_ERROR", MessageID: msg.MessageID, Message: "File is no longer available"})
		return
	}

	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		c.SendJSON(WSMessage{Type: "FILE_ERROR", MessageID: msg.MessageID, Message: "Could not issue a download token"})
		return
	}
	token := hex.EncodeToString(tokenBytes)
	if err := c.hub.rdb.StoreFileToken(token, record.ID, c.id); err != nil {
		log.Printf("[Relay Error] could not store file token: %v", err)
		c.SendJSON(WSMessage{Type: "FILE_ERROR", MessageID: msg.MessageID, Message: "Could not issue a download token"})
		return
	}

	log.Printf("[Relay] Issued download token for message %s to %s (%d bytes)", record.ID, c.id, record.SizeBytes)
	c.SendJSON(WSMessage{
		Type:      "FILE_TOKEN",
		MessageID: record.ID,
		Token:     token,
		Size:      record.SizeBytes,
		ExpiresAt: record.ExpiresAt.Unix(),
	})
}

// handleTypingStatus forwards peer typing updates.
func (c *Client) handleTypingStatus(msg WSMessage) {
	if msg.RecipientID == "" {
		return
	}
	target, ok := c.hub.getClient(msg.RecipientID)
	if ok {
		target.SendJSON(WSMessage{
			Type:     "PEER_TYPING_STATUS",
			SenderID: c.id,
			Status:   msg.Status,
		})
	}
}

// handleNukeRecipient sets up queue locks and queues nuke self-destruct envelopes.
func (c *Client) handleNukeRecipient(msg WSMessage) {
	if msg.RecipientID == "" {
		return
	}

	// Rate-limit nukes per sender so a client that knows a victim's hash can't
	// mass-block or loop-block queues (the block denies offline delivery). A
	// legitimate user nukes contacts only occasionally.
	const nukeLimitPerHour = 10
	allowed, err := c.hub.rdb.AllowNuke(c.id, nukeLimitPerHour)
	if err != nil {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Nuke rate check failed"})
		return
	}
	if !allowed {
		log.Printf("[Relay Warning] Client %s exceeded nuke rate limit (%d/hr)", c.id, nukeLimitPerHour)
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Nuke rate limit exceeded"})
		return
	}

	// Block queue in Redis
	err = c.hub.rdb.BlockQueue(msg.RecipientID)
	if err != nil {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to apply nuke lock"})
		return
	}

	// Queue the Nuke payload
	err = c.hub.rdb.AddMessageToQueue(msg.RecipientID, c.id, msg.NukeEnvelope, "nuke", 7*24*time.Hour)
	if err != nil {
		log.Printf("Failed to queue nuke payload: %v", err)
	}

	// If online, route the Nuke immediately
	target, ok := c.hub.getClient(msg.RecipientID)
	if ok {
		target.SendJSON(WSMessage{
			Type:        "NEW_MESSAGE",
			SenderID:    c.id,
			Envelope:    msg.NukeEnvelope,
			ContentType: "nuke",
		})
	}
}

// handleAckNuke processes self-destruct completion, unblocking offline message routing queues.
func (c *Client) handleAckNuke(msg WSMessage) {
	err := c.hub.rdb.UnblockQueue(c.id)
	if err != nil {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to unblock queue"})
	} else {
		c.SendJSON(WSMessage{Type: "STATUS", Message: "Queue unblocked successfully"})
	}
}

// handleFileReceived processes WebSocket file acknowledgment signals from clients.
func (c *Client) handleFileReceived(msg WSMessage) {
	if msg.MessageID == "" {
		log.Println("[Relay Warning] FILE_RECEIVED frame missing message_id")
		return
	}

	if pg == nil {
		log.Println("[Relay Error] Postgres client is nil on handleFileReceived")
		return
	}

	// Fetch message from Postgres to verify ownership
	rows, err := pg.db.Query("SELECT id, recipient_id, bucket_url FROM messages WHERE id = $1", msg.MessageID)
	if err != nil {
		log.Printf("[Relay Error] Database error checking message ownership: %v", err)
		return
	}
	defer rows.Close()

	if !rows.Next() {
		log.Printf("[Relay Warning] Message ID %s not found in Postgres for deletion", msg.MessageID)
		return
	}

	var id, recipientID, bucketURL string
	if err := rows.Scan(&id, &recipientID, &bucketURL); err != nil {
		log.Printf("[Relay Error] Error scanning message fields: %v", err)
		return
	}

	// Safety check: ensure current client is the recipient of the file
	if recipientID != c.id {
		log.Printf("[Relay Warning] Client %s unauthorized to acknowledge message %s (recipient is %s)", c.id, id, recipientID)
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Unauthorized to acknowledge this file"})
		return
	}

	// Extract key from bucketURL
	var key string
	if strings.HasPrefix(bucketURL, "local://") {
		key = strings.TrimPrefix(bucketURL, "local://")
	} else {
		parts := strings.Split(bucketURL, "/")
		if len(parts) > 0 {
			key = parts[len(parts)-1]
		}
	}

	// Delete THIS recipient's pointer row FIRST, then delete the bucket object
	// only if no other pointer rows still reference it. Doing the row delete
	// before the ref-count check means two simultaneous ACKs can at worst both
	// try to delete the object (harmless — Delete errors are only logged), never
	// both skip it and orphan it. A group fan-out shares one object across N rows.
	if err = pg.DeleteMessage(id); err != nil {
		log.Printf("[Relay Error] Failed to delete Postgres message %s: %v", id, err)
	} else {
		log.Printf("[Relay] File message %s acknowledged and cleared from database", id)
	}

	if key != "" {
		remaining, cErr := pg.CountMessagesByBucket(bucketURL)
		if cErr != nil {
			// Fail SAFE: if we can't confirm the object is unreferenced, leave it.
			// The prune sweep will reclaim it once every pointer row has expired.
			log.Printf("[Relay Warning] ref-count check for %s failed: %v — leaving object", bucketURL, cErr)
			return
		}
		if remaining > 0 {
			log.Printf("[Storage] Object %s still referenced by %d recipient(s) — keeping", key, remaining)
			return
		}
		if err = storage.Delete(context.Background(), key); err != nil {
			log.Printf("[Storage Error] Failed to delete object %s: %v", key, err)
		} else {
			log.Printf("[Storage] Deleted object %s (last reference cleared)", key)
		}
	}
}

// NOTE: The TUNNEL_INIT / TUNNEL_PACKET / TUNNEL_CLOSE handlers were removed on
// 2026-07-01. They were a scrapped feature (zero client references) but remained
// a live, authenticated attack surface: TUNNEL_INIT let any caller overwrite an
// arbitrary user's hub entry (routing hijack), and TUNNEL_CLOSE let any caller
// delete an arbitrary user's hub entry (silent eviction) AND could leave a
// closed-channel client behind that crashed the whole relay on the next send.
// The underlying Redis tunnel helpers in redis.go are now dead code (only the
// mock test references them) and can be deleted in a later cleanup.

// handlePostStoryWS handles publishing a 24-hour story over an authenticated WebSocket.
func (c *Client) handlePostStoryWS(msg WSMessage) {
	const maxMediaMetaBytes = 2048
	if msg.StoryType == "" || msg.CiphertextB64 == "" {
		c.SendJSON(WSMessage{Type: "POST_STORY_ERROR", Message: "Missing story_type or ciphertext_b64"})
		return
	}
	if len(msg.MediaMeta) > maxMediaMetaBytes {
		c.SendJSON(WSMessage{Type: "POST_STORY_ERROR", Message: "Media metadata too large"})
		return
	}

	if pg == nil {
		c.SendJSON(WSMessage{Type: "POST_STORY_ERROR", Message: "PostgreSQL storage unavailable"})
		return
	}

	isPlus, err := checkPremiumSubscription(c.id)
	if err != nil {
		log.Printf("[Social WS] Failed to check premium subscription for %s: %v", c.id, err)
		isPlus = false
	}

	// Charge media_meta too — it is stored server-side and re-served inside
	// every feed row, so leaving it free would let clients stuff unbudgeted
	// bytes into storage and every contact's feed download.
	bytesUsed := int64(len(msg.CiphertextB64) + len(msg.MediaMeta))
	allowed, used, maxBytes, err := pg.ConsumeSocialBudget(c.id, bytesUsed, isPlus)
	if err != nil {
		log.Printf("[Social WS] Failed to check/consume budget for %s: %v", c.id, err)
		c.SendJSON(WSMessage{Type: "POST_STORY_ERROR", Message: "Database error checking weekly budget"})
		return
	}

	if !allowed {
		c.SendJSON(WSMessage{
			Type:      "POST_STORY_ERROR",
			Message:   "Weekly social budget quota exceeded",
			BytesUsed: used,
			MaxBytes:  maxBytes,
		})
		return
	}

	ttl := 24 * time.Hour
	storyID, err := pg.PostStory(c.id, msg.StoryType, msg.CiphertextB64, nil, msg.MediaMeta, bytesUsed, ttl)
	if err != nil {
		log.Printf("[Social WS] Failed to insert story for %s: %v", c.id, err)
		c.SendJSON(WSMessage{Type: "POST_STORY_ERROR", Message: "Failed to store story"})
		return
	}

	log.Printf("[Social WS] User %s posted story %s (%s, %d bytes)", c.id, storyID, msg.StoryType, bytesUsed)
	c.SendJSON(WSMessage{
		Type:      "POST_STORY_OK",
		StoryID:   storyID,
		BytesUsed: used,
		MaxBytes:  maxBytes,
		ExpiresAt: time.Now().Add(ttl).Unix(),
	})
}

// handleFetchStoriesWS returns the caller's 24h stories plus stories from the
// contacts it listed. The contact list is a query filter only — the caller is
// authenticated by the WS handshake (c.id), and everything returned is an
// encrypted envelope the relay cannot read. Replaces HTTP /api/v1/stories/feed.
func (c *Client) handleFetchStoriesWS(msg WSMessage) {
	const maxFeedContacts = 500
	if len(msg.Contacts) > maxFeedContacts {
		c.SendJSON(WSMessage{Type: "STORIES_ERROR", Message: "Too many contacts"})
		return
	}

	// This frame triggers a full Postgres query per call — throttle it per
	// sender (not per socket: reconnecting must not reset the gate). Fail OPEN
	// on Redis trouble; infra issues must not break feed reads.
	if allowed, err := c.hub.rdb.AllowAction("storyfeed:"+c.id, 2*time.Second); err == nil && !allowed {
		c.SendJSON(WSMessage{Type: "STORIES_ERROR", Message: "Fetching too fast — slow down"})
		return
	}

	if pg == nil {
		c.SendJSON(WSMessage{Type: "STORIES_ERROR", Message: "PostgreSQL storage unavailable"})
		return
	}

	senders := append([]string{c.id}, msg.Contacts...)
	stories, err := pg.GetStoriesFeed(senders)
	if err != nil {
		log.Printf("[Social WS] Failed to query stories feed for %s: %v", c.id, err)
		c.SendJSON(WSMessage{Type: "STORIES_ERROR", Message: "Failed to fetch feed"})
		return
	}
	if stories == nil {
		stories = []PGStory{}
	}

	c.SendJSON(WSMessage{Type: "STORIES_FEED", Stories: stories})
}

// handleStoryReactWS records/updates the caller's emoji on a story.
// Replaces HTTP /api/v1/stories/react.
func (c *Client) handleStoryReactWS(msg WSMessage) {
	const maxEmojiRunes = 16
	if msg.StoryID == "" || msg.Emoji == "" {
		c.SendJSON(WSMessage{Type: "STORY_REACT_ERROR", Message: "Missing story_id or emoji"})
		return
	}
	if utf8.RuneCountInString(msg.Emoji) > maxEmojiRunes {
		c.SendJSON(WSMessage{Type: "STORY_REACT_ERROR", Message: "Emoji too long"})
		return
	}
	if pg == nil {
		c.SendJSON(WSMessage{Type: "STORY_REACT_ERROR", Message: "PostgreSQL storage unavailable"})
		return
	}

	// Per-sender-per-story throttle so one client can't hammer reaction writes
	// at token-bucket speed. Fail OPEN on Redis trouble.
	if allowed, err := c.hub.rdb.AllowAction("storyreact:"+c.id+":"+msg.StoryID, 2*time.Second); err == nil && !allowed {
		c.SendJSON(WSMessage{Type: "STORY_REACT_ERROR", Message: "Reacting too fast — slow down"})
		return
	}

	story, err := pg.GetStory(msg.StoryID)
	if err != nil || story == nil {
		c.SendJSON(WSMessage{Type: "STORY_REACT_ERROR", Message: "Story not found or expired"})
		return
	}

	if err := pg.AddOrUpdateStoryReaction(msg.StoryID, c.id, msg.Emoji); err != nil {
		log.Printf("[Social WS] Failed to record reaction on story %s for %s: %v", msg.StoryID, c.id, err)
		c.SendJSON(WSMessage{Type: "STORY_REACT_ERROR", Message: "Failed to record reaction"})
		return
	}

	c.SendJSON(WSMessage{Type: "STORY_REACT_OK"})
}

// handleStoryReactionsWS lets a story's author inspect its reactions.
// Replaces HTTP /api/v1/stories/{id}/reactions.
func (c *Client) handleStoryReactionsWS(msg WSMessage) {
	if msg.StoryID == "" {
		c.SendJSON(WSMessage{Type: "STORY_REACTIONS_ERROR", Message: "Missing story_id"})
		return
	}
	if pg == nil {
		c.SendJSON(WSMessage{Type: "STORY_REACTIONS_ERROR", Message: "PostgreSQL unavailable"})
		return
	}

	story, err := pg.GetStory(msg.StoryID)
	if err != nil || story == nil {
		c.SendJSON(WSMessage{Type: "STORY_REACTIONS_ERROR", Message: "Story not found or expired"})
		return
	}
	if story.SenderID != c.id {
		c.SendJSON(WSMessage{Type: "STORY_REACTIONS_ERROR", Message: "Only story author can inspect reactions"})
		return
	}

	reactions, err := pg.GetStoryReactions(msg.StoryID)
	if err != nil {
		c.SendJSON(WSMessage{Type: "STORY_REACTIONS_ERROR", Message: "Failed to query reactions"})
		return
	}
	if reactions == nil {
		reactions = []PGStoryReaction{}
	}

	c.SendJSON(WSMessage{Type: "STORY_REACTIONS", StoryID: msg.StoryID, Reactions: reactions})
}

// handleDeleteStoryWS removes the caller's own story. Replaces the HTTP
// /api/v1/stories/{id} DELETE endpoint.
func (c *Client) handleDeleteStoryWS(msg WSMessage) {
	if msg.StoryID == "" {
		c.SendJSON(WSMessage{Type: "DELETE_STORY_ERROR", Message: "Missing story_id"})
		return
	}
	if pg == nil {
		c.SendJSON(WSMessage{Type: "DELETE_STORY_ERROR", Message: "PostgreSQL unavailable"})
		return
	}

	if err := pg.DeleteStory(msg.StoryID, c.id); err != nil {
		log.Printf("[Social WS] Failed to delete story %s for %s: %v", msg.StoryID, c.id, err)
		c.SendJSON(WSMessage{Type: "DELETE_STORY_ERROR", Message: "Failed to delete story"})
		return
	}

	c.SendJSON(WSMessage{Type: "DELETE_STORY_OK", StoryID: msg.StoryID})
}
