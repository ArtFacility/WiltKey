package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"log"
	"strings"
	"time"

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

	// 3. High RAM check -> Postgres inline (under 500KB)
	if pg != nil && isHighRAMLoad() {
		messageID, err := pg.StoreMessage(msg.RecipientID, c.id, &msg.Envelope, nil, msg.ContentType, holdTTL)
		if err != nil {
			log.Printf("Failed to store message in Postgres under high memory: %v", err)
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to store message in database"})
			return
		}

		target, ok := c.hub.getClient(msg.RecipientID)
		if ok {
			target.SendJSON(WSMessage{
				Type:        "NEW_MESSAGE",
				SenderID:    c.id,
				Envelope:    msg.Envelope,
				ContentType: msg.ContentType,
			})
			// Delete inline message immediately from DB once sent
			pg.DeleteMessage(messageID)
		} else {
			go c.hub.sendWakePush(msg.RecipientID, c.id, msg.ContentType)
		}
		return
	}

	// 4. Normal routing (under 500KB, normal RAM) -> Redis
	target, ok := c.hub.getClient(msg.RecipientID)
	if ok {
		log.Printf("[Relay] Routing message directly to online client %s", msg.RecipientID)
		target.SendJSON(WSMessage{
			Type:        "NEW_MESSAGE",
			SenderID:    c.id,
			Envelope:    msg.Envelope,
			ContentType: msg.ContentType,
		})
	} else {
		log.Printf("[Relay] Client %s offline. Queuing message in Redis with %s TTL.", msg.RecipientID, holdTTL)
		err := c.hub.rdb.AddMessageToQueue(msg.RecipientID, c.id, msg.Envelope, msg.ContentType, holdTTL)
		if err != nil {
			log.Printf("[Relay Error] Failed to queue offline message for %s in Redis: %v", msg.RecipientID, err)
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to queue message offline"})
			return
		}
		go c.hub.sendWakePush(msg.RecipientID, c.id, msg.ContentType)
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

	// Delete from storage
	if key != "" {
		err = storage.Delete(context.Background(), key)
		if err != nil {
			log.Printf("[Storage Error] Failed to delete object %s: %v", key, err)
		} else {
			log.Printf("[Storage] Deleted object %s successfully", key)
		}
	}

	// Delete from Postgres
	err = pg.DeleteMessage(id)
	if err != nil {
		log.Printf("[Relay Error] Failed to delete Postgres message %s: %v", id, err)
	} else {
		log.Printf("[Relay] File message %s successfully acknowledged and cleared from database", id)
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
