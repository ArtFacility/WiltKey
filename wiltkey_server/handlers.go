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
	// Block queue in Redis
	err := c.hub.rdb.BlockQueue(msg.RecipientID)
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

// handleTunnelInit initiates a WebSocket route mapping tunnel between two ephemeral keys.
func (c *Client) handleTunnelInit(msg WSMessage) {
	if msg.RecipientID == "" || msg.EphemeralPubkey == "" {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Missing ephemeral keys"})
		return
	}

	err := c.hub.rdb.CreateTunnel(msg.RecipientID, msg.EphemeralPubkey, 1*time.Hour)
	if err != nil {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to map ephemeral tunnel"})
		return
	}

	c.hub.mu.Lock()
	c.hub.clients[msg.EphemeralPubkey] = c
	c.hub.mu.Unlock()

	target, ok := c.hub.getClient(msg.RecipientID)
	if ok {
		target.SendJSON(WSMessage{
			Type:            "TUNNEL_INIT",
			RecipientID:     msg.RecipientID,
			EphemeralPubkey: msg.EphemeralPubkey,
		})
	}

	c.SendJSON(WSMessage{
		Type:            "TUNNEL_OK",
		RecipientID:     msg.RecipientID,
		EphemeralPubkey: msg.EphemeralPubkey,
	})
}

// handleTunnelPacket forwards packets through the WS ephemeral tunnel, checking the 1KB cap.
func (c *Client) handleTunnelPacket(msg WSMessage) {
	if msg.RecipientID == "" || msg.Envelope == "" {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Missing tunnel envelope or recipient"})
		return
	}

	packetBytes := int64(len(msg.Envelope))

	var tunnelID string
	if c.id < msg.RecipientID {
		tunnelID = c.id + ":" + msg.RecipientID
	} else {
		tunnelID = msg.RecipientID + ":" + c.id
	}

	totalBytes, err := c.hub.rdb.IncrementTunnelBytes(tunnelID, packetBytes)
	if err != nil {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "Failed to increment packet audit ledger"})
		return
	}

	if totalBytes > 1024 {
		c.SendJSON(WSMessage{Type: "ERROR", Message: "1KB tunnel bandwidth quota exceeded. Connection closed."})
		c.handleTunnelClose(msg)
		return
	}

	target, ok := c.hub.getClient(msg.RecipientID)
	if ok {
		target.SendJSON(WSMessage{
			Type:        "TUNNEL_PACKET",
			SenderID:    c.id,
			Envelope:    msg.Envelope,
			ContentType: msg.ContentType,
		})
	}
}

// handleTunnelClose deletes the WS ephemeral tunnel routes.
func (c *Client) handleTunnelClose(msg WSMessage) {
	if msg.RecipientID == "" {
		return
	}

	c.hub.rdb.DeleteTunnel(c.id, msg.RecipientID)

	target, ok := c.hub.getClient(msg.RecipientID)
	if ok {
		target.SendJSON(WSMessage{
			Type:     "TUNNEL_CLOSED",
			SenderID: c.id,
		})
	}

	c.hub.mu.Lock()
	delete(c.hub.clients, c.id)
	delete(c.hub.clients, msg.RecipientID)
	c.hub.mu.Unlock()
}
