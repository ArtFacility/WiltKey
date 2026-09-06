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

// Per-connection flood guard. The HTTP rate-limit middleware does not cover /ws,
// and once authenticated a socket could otherwise route/queue at ~50k msg/s. A
// token bucket permits legitimate bursts (group fan-out, resync) up to the
// capacity, then limits sustained throughput to the refill rate.
const (
	wsBucketCapacity = 200.0 // max burst
	wsRefillPerSec   = 100.0 // sustained messages/sec
)

// Device-token issuance gate: PoW difficulty (leading hex zeros of
// sha256(challenge + nonce + pubkey)) and the per-IP DAILY mint cap. Tunable
// via WK_ISSUANCE_DIFFICULTY / WK_ISSUANCE_DAILY_IP — raise them if identity
// farming is ever observed. Difficulty 5 ≈ ~1M hashes (a second or two on a
// phone, once per install).
var (
	issuanceDifficulty = 5
	issuanceDailyIPCap = int64(5)
)

// capabilitiesForThisRelay lists what THIS relay supports, advertised in
// AUTH_OK. "test_mode" is appended when running under WK_TEST_MODE=true.
func capabilitiesForThisRelay() []string {
	caps := []string{"group_fanout", "social_stories", "stories_ws"}
	if testMode {
		caps = append(caps, "test_mode")
	}
	return caps
}

// Client represents a connected WebSocket user.
type Client struct {
	id         string
	conn       *websocket.Conn
	send       chan []byte
	hub        *Hub
	tokens     float64   // flood-guard bucket (readPump goroutine only — no lock)
	lastRefill time.Time
}

// Hub manages all active WebSocket connections.
type Hub struct {
	clients    map[string]*Client // maps user_id -> Client
	register   chan *Client
	unregister chan *Client
	rdb        *RedisClient
	push       *PushSender
	mu         sync.RWMutex
}

func NewHub(rdb *RedisClient, push *PushSender) *Hub {
	return &Hub{
		clients:    make(map[string]*Client),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		rdb:        rdb,
		push:       push,
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
	// 1. Deliver from Redis
	messages, err := h.rdb.FetchAndClearQueue(client.id)
	if err != nil {
		log.Printf("Error fetching offline queue from Redis for %s: %v", client.id, err)
	}
	if len(messages) > 0 {
		log.Printf("Delivering %d offline messages from Redis to %s", len(messages), client.id)
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

	// 2. Deliver from Postgres
	if pg == nil {
		return
	}
	pgMsgs, err := pg.GetPendingMessages(client.id)
	if err != nil {
		log.Printf("Error fetching offline messages from Postgres for %s: %v", client.id, err)
		return
	}

	if len(pgMsgs) > 0 {
		log.Printf("Delivering %d offline messages from Postgres to %s", len(pgMsgs), client.id)
		for _, msg := range pgMsgs {
			if msg.BucketURL != nil {
				// Large file: advertise it, don't push it. The body stays in the
				// bucket until the client downloads it and ACKs (or the TTL
				// expires), so a half-finished or interrupted download can always
				// be retried instead of losing the file.
				client.SendJSON(fileOfferFrom(msg))
				continue
			}
			if msg.Envelope == nil {
				continue
			}
			client.SendJSON(WSMessage{
				Type:        "NEW_MESSAGE",
				SenderID:    msg.SenderID,
				Envelope:    *msg.Envelope,
				ContentType: msg.ContentType,
			})
		}

		// Delete inline messages from Postgres immediately (bucket files stay until ACK)
		err = pg.DeleteInlineMessages(client.id)
		if err != nil {
			log.Printf("Failed to delete delivered inline Postgres messages for %s: %v", client.id, err)
		}
	}
}

// fileOfferFrom builds the FILE_OFFER frame for a pending bucket message. Shared
// by the connect-time sweep and the on-demand resendPendingFileOffers so the two
// can never drift.
func fileOfferFrom(msg PGMessage) WSMessage {
	return WSMessage{
		Type:        "FILE_OFFER",
		SenderID:    msg.SenderID,
		ContentType: msg.ContentType,
		MessageID:   msg.ID,
		Meta:        msg.OfferMeta,
		Size:        msg.SizeBytes,
		ExpiresAt:   msg.ExpiresAt.Unix(),
	}
}

// resendPendingFileOffers re-advertises every un-ACKed bucket file the relay is
// still holding for this client. Bucket rows persist until FILE_RECEIVED, so it
// is idempotent (the client dedups a re-offer by message id) and safe to call
// liberally. It is the ONLY recovery path for a live FILE_OFFER that was missed
// while the client stayed connected (a socket mid-rotation, a full send buffer,
// or a swallowed client-side error) — without it such a file is invisible until
// the next full reconnect. Triggered by the client's REQUEST_PENDING_FILES.
func (c *Client) resendPendingFileOffers() {
	if pg == nil {
		return
	}
	pgMsgs, err := pg.GetPendingMessages(c.id)
	if err != nil {
		log.Printf("[Relay] resendPendingFileOffers: fetch failed for %s: %v", c.id, err)
		return
	}
	var n int
	for _, msg := range pgMsgs {
		if msg.BucketURL == nil {
			continue // inline messages are handled by the connect-time delivery
		}
		c.SendJSON(fileOfferFrom(msg))
		n++
	}
	if n > 0 {
		log.Printf("[Relay] Re-offered %d pending file(s) to %s on request.", n, c.id)
	}
}

// SendJSON helper to send a JSON frame to a specific client.
func (c *Client) SendJSON(v interface{}) {
	data, err := json.Marshal(v)
	if err != nil {
		log.Printf("Error marshalling JSON: %v", err)
		return
	}
	// A client can be unregistered (its `send` channel closed) between the moment
	// a caller looked it up via getClient (which releases the hub lock) and the
	// moment we send here. Sending on a closed channel PANICS, which — with no
	// recover on the readPump goroutine — would crash the entire relay and drop
	// every connected user. Recover so a gone/racing client only costs this one
	// dropped frame instead of the whole process.
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[SendJSON] dropped frame for %s (client already gone): %v", c.id, r)
		}
	}()
	select {
	case c.send <- data:
	case <-time.After(100 * time.Millisecond):
		// Send buffer saturated for >100ms: evict slow/dead consumer gracefully
		log.Printf("[WebSocket] Send buffer saturated for client %s — disconnecting dead/slow consumer", c.id)
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
	// Capabilities the relay advertises in AUTH_OK (e.g. "group_fanout"), so a
	// client can use newer frames only when the relay it connected to supports
	// them and otherwise fall back (old self-hosted relays stay compatible).
	Capabilities []string `json:"capabilities,omitempty"`
	Message         string            `json:"message,omitempty"`
	NukeEnvelope    string            `json:"nuke_envelope,omitempty"`
	EphemeralPubkey string            `json:"ephemeral_pubkey,omitempty"`
	MessageID       string            `json:"message_id,omitempty"`
	// Large-file (FILE_OFFER / FILE_TOKEN) fields. `Meta` is the message envelope
	// with its big `d` ciphertext stripped, so the client can place the message in
	// the right chat and render a placeholder before downloading the body.
	Meta      string `json:"meta,omitempty"`
	Size      int64  `json:"size,omitempty"`
	Token     string `json:"token,omitempty"`
	ExpiresAt int64  `json:"expires_at,omitempty"`
	// Stories WebSocket fields
	StoryType     string `json:"story_type,omitempty"`
	CiphertextB64 string `json:"ciphertext_b64,omitempty"`
	MediaMeta     string `json:"media_meta,omitempty"`
	StoryID       string `json:"story_id,omitempty"`
	BytesUsed     int64  `json:"bytes_used,omitempty"`
	MaxBytes      int64  `json:"max_bytes,omitempty"`
	// Story feed / reactions frames. `Contacts` limits FETCH_STORIES to senders
	// the client actually knows (server always adds the caller itself); the
	// client-supplied list is only a query filter, never an authorization.
	Contacts  []string          `json:"contacts,omitempty"`
	Emoji     string            `json:"emoji,omitempty"`
	Stories   []PGStory         `json:"stories,omitempty"`
	Reactions []PGStoryReaction `json:"reactions,omitempty"`
	// Device-token auth. `DeviceToken` is the raw token the client presents in
	// AUTH (the AUTH signature covers challenge||token); AUTH_OK hands back a
	// fresh token when the presented one is near expiry. TOKEN_CHALLENGE asks
	// a token-less client to solve a PoW over THIS connection's challenge;
	// AUTH_TOKEN_ISSUE carries the solution. The raw token NEVER reaches the
	// database — only its SHA-256 (db.go device_tokens).
	DeviceToken         string `json:"device_token,omitempty"`
	DeviceTokenExpiresAt int64 `json:"device_token_expires_at,omitempty"`
	PowNonce            int64  `json:"pow_nonce,omitempty"`
	Difficulty          int    `json:"difficulty,omitempty"`
	// Human-verification challenge (Phase 2, puzzle.go). The client
	// ADVERTISES "human_challenge" in AUTH client_caps; the relay answers
	// token-less issuance with AUTH_CHALLENGE_REQUIRED (seed the client
	// renders locally) and expects AUTH_CHALLENGE_SOLUTION back. PuzzleAnswer
	// is a POINTER because 0 is a valid rotation — json null vs 0 matters.
	ClientCaps   []string `json:"client_caps,omitempty"`
	ChallengeID  string   `json:"challenge_id,omitempty"`
	PuzzleSeed   string   `json:"seed,omitempty"`
	PuzzleKind   string   `json:"kind,omitempty"`
	PuzzleStrips int      `json:"strips,omitempty"`
	PuzzleAnswer *int     `json:"answer,omitempty"`
	TTL          int      `json:"ttl,omitempty"`
}

// readPump pumps messages from the websocket connection to the hub.
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	// Frame ceiling is tied to what THIS sender is actually allowed to post, so an
	// anonymous/free client can never make the relay buffer a 50MB frame (anyone
	// can self-issue a keypair and authenticate, so the ceiling — not auth — is the
	// real memory guard). Frames carry the base64 envelope plus a little JSON
	// overhead, hence the headroom above the payload limits.
	//
	// NOTE: evaluated once at connect. A user who subscribes mid-session keeps the
	// free ceiling until their next reconnect (the client re-syncs entitlements on
	// every connect, so this self-heals).
	readLimit := int64(freeMaxPayload) + 2*1024*1024 // ~7 MB for free senders
	if hasSub, err := checkPremiumSubscription(c.id); err == nil && hasSub {
		readLimit = int64(plusMaxPayload) + 6*1024*1024 // ~56 MB for Plus senders
	}
	c.conn.SetReadLimit(readLimit)
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

		// Token-bucket flood guard (readPump is the only goroutine touching these
		// fields, so no locking is needed).
		now := time.Now()
		c.tokens += now.Sub(c.lastRefill).Seconds() * wsRefillPerSec
		if c.tokens > wsBucketCapacity {
			c.tokens = wsBucketCapacity
		}
		c.lastRefill = now
		if c.tokens < 1 {
			log.Printf("[WebSocket] Client %s exceeded flood limit — disconnecting", c.id)
			c.SendJSON(WSMessage{Type: "ERROR", Message: "Rate limit exceeded — slow down"})
			break
		}
		c.tokens--

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
	case "BROADCAST_GROUP_MESSAGE":
		c.handleBroadcastGroupMessage(msg)
	case "TYPING_STATUS":
		c.handleTypingStatus(msg)
	case "NUKE_RECIPIENT":
		c.handleNukeRecipient(msg)
	case "ACK_NUKE":
		c.handleAckNuke(msg)
	case "FILE_RECEIVED":
		c.handleFileReceived(msg)
	case "REQUEST_FILE":
		c.handleRequestFile(msg)
	case "REQUEST_PENDING_FILES":
		// Client reconciliation: re-offer any un-ACKed bucket files. Lets a
		// still-connected client recover a live FILE_OFFER it missed, without a
		// full reconnect. Idempotent (client dedups by id).
		c.resendPendingFileOffers()
	case "POST_STORY":
		c.handlePostStoryWS(msg)
	case "FETCH_STORIES":
		c.handleFetchStoriesWS(msg)
	case "STORY_REACT":
		c.handleStoryReactWS(msg)
	case "FETCH_STORY_REACTIONS":
		c.handleStoryReactionsWS(msg)
	case "DELETE_STORY":
		c.handleDeleteStoryWS(msg)
	default:
		log.Printf("[WebSocket] Unhandled message type: %s", msg.Type)
	}
}

// ServeWS handles WebSocket upgrading and challenge authentication.
func ServeWS(hub *Hub, w http.ResponseWriter, r *http.Request) {
	ip := clientIP(r)

	// Banned IPs (repeat auth failures, etc.) never get a challenge at all.
	// Fail CLOSED on Redis error, matching the HTTP middleware — during an infra
	// blip a banned IP must not get free auth attempts.
	banned, err := rdb.CheckIPBan(ip)
	if err != nil || banned {
		if err != nil {
			log.Printf("[Auth] IP-ban check failed for %s: %v — refusing", ip, err)
		} else {
			log.Printf("[Auth] Banned IP %s attempted WS connect — refusing", ip)
		}
		conn, err := upgrader.Upgrade(w, r, nil)
		if err == nil {
			conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"ERROR","message":"Banned"}`))
			conn.Close()
		}
		return
	}

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
		// No punishment here: no auth was even attempted. A truncated frame on a
		// flaky mobile link must not 5-minute-ban a whole carrier-NAT exit IP.
		log.Printf("[Auth Error] Invalid AUTH structure or type: %v, body: %s", err, string(msgBytes))
		conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"ERROR","message":"Expected AUTH frame"}`))
		conn.Close()
		return
	}

	// The AUTH signature covers the challenge PLUS the presented device token
	// (when there is one): challenge-bound tokens mean a stolen token alone is
	// useless AND a captured AUTH frame cannot be replayed on a new connection
	// (the challenge is fresh every time).
	signedPayload := challengeHex
	if authMsg.DeviceToken != "" {
		signedPayload = challengeHex + authMsg.DeviceToken
	}
	ok, err := VerifySignature(authMsg.Pubkey, authMsg.Signature, []byte(signedPayload))
	if err != nil || !ok {
		log.Printf("[Auth Error] Signature verification failed: verified=%t, error=%v", ok, err)
		registerIPFailure(ip, "WS: invalid auth signature")
		conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"ERROR","message":"Authentication failed"}`))
		conn.Close()
		return
	}

	pubBytes, _ := hex.DecodeString(authMsg.Pubkey)
	userID := GenerateUserID(pubBytes)

	// ---- Device-token gate ------------------------------------------------
	// Identity is cheap (anyone can mint an ed25519 keypair), so a keypair
	// alone no longer authenticates: a connection is admitted only with a
	// valid device token (issued after paying the PoW gate once) — or by
	// paying that gate right now.
	if pg == nil {
		// Fail CLOSED: the token store IS the gate. Without Postgres the relay
		// refuses everything rather than silently degrading to free identity.
		log.Printf("[Auth] Postgres unavailable — refusing WS auth (token store down)")
		conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"ERROR","message":"Token store unavailable"}`))
		conn.Close()
		return
	}

	var newTokenForClient string
	var newTokenExpiresAt int64

	if authMsg.DeviceToken != "" {
		valid, nearExpiry, err := pg.VerifyDeviceToken(userID, authMsg.DeviceToken)
		if err != nil {
			log.Printf("[Auth Error] Token verification failed for %s: %v", userID, err)
			conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"ERROR","message":"Token store error"}`))
			conn.Close()
			return
		}
		if !valid {
			// No IP ban on purpose: an expired/rotated/unknown token self-heals
			// via the issuance path on the client's next connect. Punishing
			// here would brick legitimate users (e.g. 60+ days offline)
			// behind shared NATs for the ban duration.
			log.Printf("[Auth Rejected] Invalid device token for %s from %s", userID, ip)
			reject := WSMessage{Type: "AUTH_REJECTED", Message: "token_invalid"}
			rejBytes, _ := json.Marshal(reject)
			conn.WriteMessage(websocket.TextMessage, rejBytes)
			conn.Close()
			return
		}
		pg.TouchDeviceToken(userID)
		if nearExpiry {
			tok, expires, err := mintDeviceToken(userID)
			if err != nil {
				log.Printf("[Auth Error] Token rotation failed for %s: %v", userID, err)
				// The presented token is still valid — continue WITHOUT a
				// refresh rather than dropping a working client.
			} else {
				newTokenForClient = tok
				newTokenExpiresAt = expires
			}
		}
	} else {
		// Issuance path: challenge the client to prove spend (PoW over THIS
		// connection's challenge, bound to its identity via the payload).
		tc := WSMessage{
			Type:       "TOKEN_CHALLENGE",
			Challenge:  challengeHex,
			Difficulty: issuanceDifficulty,
		}
		tcBytes, _ := json.Marshal(tc)
		conn.WriteMessage(websocket.TextMessage, tcBytes)

		conn.SetReadDeadline(time.Now().Add(30 * time.Second))
		_, issueBytes, err := conn.ReadMessage()
		if err != nil {
			log.Printf("[Auth Error] Failed to read AUTH_TOKEN_ISSUE: %v", err)
			conn.Close()
			return
		}
		var issueMsg WSMessage
		if err := json.Unmarshal(issueBytes, &issueMsg); err != nil || issueMsg.Type != "AUTH_TOKEN_ISSUE" {
			log.Printf("[Auth Error] Expected AUTH_TOKEN_ISSUE, got: %s", string(issueBytes))
			conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"ERROR","message":"Expected AUTH_TOKEN_ISSUE frame"}`))
			conn.Close()
			return
		}
		if !VerifyPoW(challengeHex, issueMsg.PowNonce, authMsg.Pubkey, issuanceDifficulty) {
			log.Printf("[Auth Rejected] PoW verification failed during issuance for %s", userID)
			reject := WSMessage{Type: "AUTH_REJECTED", Message: "pow_invalid"}
			rejBytes, _ := json.Marshal(reject)
			conn.WriteMessage(websocket.TextMessage, rejBytes)
			conn.Close()
			return
		}

		// Human-verification gate (Phase 2, puzzle.go): AFTER the PoW proves
		// spend, a challenge-required issuance must ALSO solve the drag
		// puzzle. Placed before AllowIssuance so a failed puzzle never burns
		// the IP's daily mint quota; the cooldown check keeps replay loops
		// out during an armed window.
		//
		// Enforcement flip (review 2026-09-06 HIGH): with the mode ON, a
		// client that does NOT advertise the cap is refused outright —
		// otherwise a bot farm strips "human_challenge" from client_caps and
		// downgrades to PoW-only forever. Safe under the no-backcompat
		// release model (app + relay ship together; the website force-update
		// catches stragglers).
		if challengeUpgradeRequired(authMsg.ClientCaps) {
			log.Printf("[Auth Rejected] Issuance without human_challenge cap while mode=%s for %s (ip %s)",
				challengeMode, userID, ip)
			reject := WSMessage{Type: "AUTH_REJECTED", Message: "challenge_upgrade_required"}
			rejBytes, _ := json.Marshal(reject)
			conn.WriteMessage(websocket.TextMessage, rejBytes)
			conn.Close()
			return
		}
		if puzzleRequiredForClient(authMsg.ClientCaps, ip) {
			cooling, err := rdb.CheckChallengeCooldown(ip)
			if err != nil {
				log.Printf("[Challenge] Cooldown check failed for %s: %v — refusing", ip, err)
				reject := WSMessage{Type: "AUTH_REJECTED", Message: "challenge_unavailable"}
				rejBytes, _ := json.Marshal(reject)
				conn.WriteMessage(websocket.TextMessage, rejBytes)
				conn.Close()
				return
			}
			if cooling {
				log.Printf("[Auth Rejected] Challenge cooldown active for %s", ip)
				reject := WSMessage{Type: "AUTH_REJECTED", Message: "challenge_cooldown"}
				rejBytes, _ := json.Marshal(reject)
				conn.WriteMessage(websocket.TextMessage, rejBytes)
				conn.Close()
				return
			}
			if err := runPuzzleChallenge(conn, ip); err != nil {
				log.Printf("[Auth Rejected] Human challenge failed for %s: %v", ip, err)
				reject := WSMessage{Type: "AUTH_REJECTED", Message: "challenge_failed"}
				rejBytes, _ := json.Marshal(reject)
				conn.WriteMessage(websocket.TextMessage, rejBytes)
				conn.Close()
				return
			}
		}

		allowed, err := rdb.AllowIssuance(ip, issuanceDailyIPCap)
		if err != nil {
			log.Printf("[Auth Error] Issuance cap check failed for %s: %v", ip, err)
			reject := WSMessage{Type: "AUTH_REJECTED", Message: "issuance_unavailable"}
			rejBytes, _ := json.Marshal(reject)
			conn.WriteMessage(websocket.TextMessage, rejBytes)
			conn.Close()
			return
		}
		if !allowed {
			log.Printf("[Auth Rejected] Issuance rate limit hit for %s", ip)
			reject := WSMessage{Type: "AUTH_REJECTED", Message: "issuance_rate_limited"}
			rejBytes, _ := json.Marshal(reject)
			conn.WriteMessage(websocket.TextMessage, rejBytes)
			conn.Close()
			return
		}
		tok, expires, err := mintDeviceToken(userID)
		if err != nil {
			log.Printf("[Auth Error] Token minting failed for %s: %v", userID, err)
			conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"ERROR","message":"Token store error"}`))
			conn.Close()
			return
		}
		newTokenForClient = tok
		newTokenExpiresAt = expires
		log.Printf("[Auth] Device token minted for %s (ip %s)", userID, ip)
	}

	authKind := "device-token"
	if newTokenForClient != "" && authMsg.DeviceToken == "" {
		authKind = "issued new device token"
	}
	log.Printf("[Auth Success] Client verified. User ID: %s (%s)", userID, authKind)

	// Authentication successful
	client := &Client{
		id:         userID,
		conn:       conn,
		send:       make(chan []byte, 512),
		hub:        hub,
		tokens:     wsBucketCapacity,
		lastRefill: time.Now(),
	}

	client.hub.register <- client

	client.SendJSON(WSMessage{
		Type:         "AUTH_OK",
		UserID:       userID,
		DeviceToken:  newTokenForClient,
		DeviceTokenExpiresAt: newTokenExpiresAt,
		// "stories_ws" gates the full story frame set (fetch/react/reactions/
		// delete); "social_stories" only ever covered POST_STORY. The HTTP story
		// endpoints were removed — WS is the only transport for stories now.
		// "test_mode" marks a WK_TEST_MODE=true relay so clients can banner
		// "TEST SERVER" and nobody confuses the two during device testing.
		Capabilities: capabilitiesForThisRelay(),
	})

	// Reset read deadlines and start pumps
	conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	go client.writePump()
	go client.readPump()
}

// mintDeviceToken generates a fresh random 256-bit device token, stores only
// its SHA-256, and returns the raw token (for the client) plus its expiry as
// a unix timestamp.
func mintDeviceToken(userID string) (string, int64, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", 0, err
	}
	token := hex.EncodeToString(raw)
	expiresAt, err := pg.MintDeviceToken(userID, token)
	if err != nil {
		return "", 0, err
	}
	return token, expiresAt.Unix(), nil
}
