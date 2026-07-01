package main

import (
	"log"
	"time"
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
		log.Printf("[Relay] Client %s offline. Queuing message in Redis with 24h TTL.", msg.RecipientID)
		err := c.hub.rdb.AddMessageToQueue(msg.RecipientID, c.id, msg.Envelope, msg.ContentType, 24*time.Hour)
		if err != nil {
			log.Printf("[Relay Error] Failed to queue offline message for %s in Redis: %v", msg.RecipientID, err)
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to queue message offline"})
		}
	}
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

// NOTE: The TUNNEL_INIT / TUNNEL_PACKET / TUNNEL_CLOSE handlers were removed on
// 2026-07-01. They were a scrapped feature (zero client references) but remained
// a live, authenticated attack surface: TUNNEL_INIT let any caller overwrite an
// arbitrary user's hub entry (routing hijack), and TUNNEL_CLOSE let any caller
// delete an arbitrary user's hub entry (silent eviction) AND could leave a
// closed-channel client behind that crashed the whole relay on the next send.
// The underlying Redis tunnel helpers in redis.go are now dead code (only the
// mock test references them) and can be deleted in a later cleanup.
