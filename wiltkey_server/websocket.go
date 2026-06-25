package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for dev/self-hosted
	},
}

// Client represents a connected WebSocket user.
type Client struct {
	id   string
	conn *websocket.Conn
	send chan []byte
	hub  *Hub
}

// Hub manages all active WebSocket connections.
type Hub struct {
	clients    map[string]*Client // maps user_id -> Client
	register   chan *Client
	unregister chan *Client
	rdb        *RedisClient
	mu         sync.RWMutex
}

func NewHub(rdb *RedisClient) *Hub {
	return &Hub{
		clients:    make(map[string]*Client),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		rdb:        rdb,
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.id] = client
			h.mu.Unlock()
			log.Printf("Client registered: %s", client.id)
			go h.deliverOfflineQueue(client)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.id]; ok {
				delete(h.clients, client.id)
				close(client.send)
				log.Printf("Client unregistered: %s", client.id)
			}
			h.mu.Unlock()
		}
	}
}

func (h *Hub) deliverOfflineQueue(client *Client) {
	messages, err := h.rdb.FetchAndClearQueue(client.id)
	if err != nil {
		log.Printf("Error fetching offline queue for %s: %v", client.id, err)
		return
	}
	if len(messages) == 0 {
		return
	}

	log.Printf("Delivering %d offline messages to %s", len(messages), client.id)
	for _, msg := range messages {
		senderID := msg["sender_id"]
		envelope := msg["envelope"]
		contentType := msg["content_type"]

		client.SendJSON(WSMessage{
			Type:        "NEW_MESSAGE",
			SenderID:    senderID,
			Envelope:    envelope,
			ContentType: contentType,
		})
	}
}

// SendJSON helper to send a JSON frame to a specific client.
func (c *Client) SendJSON(v interface{}) {
	data, err := json.Marshal(v)
	if err != nil {
		log.Printf("Error marshalling JSON: %v", err)
		return
	}
	select {
	case c.send <- data:
	default:
		c.hub.unregister <- c
		c.conn.Close()
	}
}

// WebSocket Message Schemas
type WSMessage struct {
	Type            string            `json:"type"`
	Challenge       string            `json:"challenge,omitempty"`
	Pubkey          string            `json:"pubkey,omitempty"`
	Signature       string            `json:"signature,omitempty"`
	UserID          string            `json:"user_id,omitempty"`
	RecipientID     string            `json:"recipient_id,omitempty"`
	SenderID        string            `json:"sender_id,omitempty"`
	Envelope        string            `json:"envelope,omitempty"`
	ContentType     string            `json:"content_type,omitempty"`
	Status          string            `json:"status,omitempty"`
	HostID          string            `json:"host_id,omitempty"`
	SpokeID         string            `json:"spoke_id,omitempty"`
	Sequence        int64             `json:"sequence,omitempty"`
	Recipients      []string          `json:"recipients,omitempty"`
	Envelopes       map[string]string `json:"envelopes,omitempty"`
	Message         string            `json:"message,omitempty"`
	NukeEnvelope    string            `json:"nuke_envelope,omitempty"`
	EphemeralPubkey string            `json:"ephemeral_pubkey,omitempty"`
}

// readPump pumps messages from the websocket connection to the hub.
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(2 * 1024 * 1024) // 2 MB max payload size
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		var msg WSMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Invalid JSON format"})
			continue
		}

		c.handleWSMessage(msg)
	}
}

// writePump pumps messages from the hub to the websocket connection.
func (c *Client) writePump() {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// getClient safely looks up a client by ID under a read lock.
func (h *Hub) getClient(id string) (*Client, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	client, ok := h.clients[id]
	return client, ok
}

func (c *Client) handleWSMessage(msg WSMessage) {
	switch msg.Type {
	case "SEND_MESSAGE":
		c.handleSendMessage(msg)
	case "TYPING_STATUS":
		c.handleTypingStatus(msg)
	case "NUKE_RECIPIENT":
		c.handleNukeRecipient(msg)
	case "ACK_NUKE":
		c.handleAckNuke(msg)
	case "TUNNEL_INIT":
		c.handleTunnelInit(msg)
	case "TUNNEL_PACKET":
		c.handleTunnelPacket(msg)
	case "TUNNEL_CLOSE":
		c.handleTunnelClose(msg)
	default:
		log.Printf("[WebSocket] Unhandled message type: %s", msg.Type)
	}
}

// ServeWS handles WebSocket upgrading and challenge authentication.
func ServeWS(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket Upgrade Error: %v", err)
		return
	}

	// 1. Generate challenge
	challengeBytes := make([]byte, 32)
	rand.Read(challengeBytes)
	challengeHex := hex.EncodeToString(challengeBytes)

	// Send challenge
	initMsg := WSMessage{
		Type:      "CHALLENGE",
		Challenge: challengeHex,
	}
	initBytes, _ := json.Marshal(initMsg)
	conn.WriteMessage(websocket.TextMessage, initBytes)

	// 2. Expect AUTH message within 5 seconds
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, msgBytes, err := conn.ReadMessage()
	if err != nil {
		log.Printf("[Auth Error] Failed to read AUTH message: %v", err)
		conn.Close()
		return
	}

	var authMsg WSMessage
	if err := json.Unmarshal(msgBytes, &authMsg); err != nil || authMsg.Type != "AUTH" {
		log.Printf("[Auth Error] Invalid AUTH structure or type: %v, body: %s", err, string(msgBytes))
		conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"ERROR","message":"Expected AUTH frame"}`))
		conn.Close()
		return
	}

	// Verify signature
	ok, err := VerifySignature(authMsg.Pubkey, authMsg.Signature, []byte(challengeHex))
	if err != nil || !ok {
		log.Printf("[Auth Error] Signature verification failed: verified=%t, error=%v", ok, err)
		conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"ERROR","message":"Authentication failed"}`))
		conn.Close()
		return
	}

	pubBytes, _ := hex.DecodeString(authMsg.Pubkey)
	userID := GenerateUserID(pubBytes)
	log.Printf("[Auth Success] Client verified. User ID generated: %s", userID)

	// Authentication successful
	client := &Client{
		id:   userID,
		conn: conn,
		send: make(chan []byte, 256),
		hub:  hub,
	}

	client.hub.register <- client

	client.SendJSON(WSMessage{
		Type:   "AUTH_OK",
		UserID: userID,
	})

	// Reset read deadlines and start pumps
	conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	go client.writePump()
	go client.readPump()
}
