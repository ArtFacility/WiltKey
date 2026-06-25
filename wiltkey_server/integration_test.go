package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestIntegration(t *testing.T) {
	// 0. Setup Keys
	alicePub, alicePriv, _ := ed25519.GenerateKey(rand.Reader)
	aliceID := GenerateUserID(alicePub)
	alicePubHex := hex.EncodeToString(alicePub)

	bobPub, bobPriv, _ := ed25519.GenerateKey(rand.Reader)
	bobID := GenerateUserID(bobPub)
	bobPubHex := hex.EncodeToString(bobPub)

	// Try to connect to Redis
	testRdb, err := NewRedisClient("localhost:6379")
	if err != nil || testRdb.IsMemory() {
		t.Skip("Skipping integration test: Redis not running on localhost:6379")
		return
	}
	defer testRdb.Close()
	rdb = testRdb

	// Clear test keys
	rdb.FlushAll()

	hub := NewHub(rdb)
	go hub.Run()

	mux := http.NewServeMux()
	mux.HandleFunc("/api/v1/pow/challenge", rateLimitMiddleware(handleGetChallenge))
	mux.HandleFunc("/api/v1/queue/post", rateLimitMiddleware(handlePostQueue(hub)))
	mux.HandleFunc("/api/v1/queue/status", rateLimitMiddleware(handleQueueStatus))
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		ServeWS(hub, w, r)
	})

	server := httptest.NewServer(mux)
	defer server.Close()

	// 1. Alice connects to WS and Authenticates
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
	aliceConn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("failed to dial Alice WS: %v", err)
	}
	defer aliceConn.Close()

	var aliceChallenge WSMessage
	if err := aliceConn.ReadJSON(&aliceChallenge); err != nil {
		t.Fatalf("failed to read challenge: %v", err)
	}

	// Sign Alice challenge
	aliceSig := ed25519.Sign(alicePriv, []byte(aliceChallenge.Challenge))
	authMsg := WSMessage{
		Type:      "AUTH",
		Pubkey:    alicePubHex,
		Signature: hex.EncodeToString(aliceSig),
	}
	if err := aliceConn.WriteJSON(authMsg); err != nil {
		t.Fatalf("failed to send Alice AUTH: %v", err)
	}

	var authOk WSMessage
	if err := aliceConn.ReadJSON(&authOk); err != nil || authOk.Type != "AUTH_OK" {
		t.Fatalf("Alice auth failed or returned wrong response: %v", err)
	}
	if authOk.UserID != aliceID {
		t.Errorf("expected UserID %s, got %s", aliceID, authOk.UserID)
	}

	// 2. Bob connects to WS and Authenticates
	bobConn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("failed to dial Bob WS: %v", err)
	}
	defer bobConn.Close()

	var bobChallenge WSMessage
	if err := bobConn.ReadJSON(&bobChallenge); err != nil {
		t.Fatalf("failed to read Bob challenge: %v", err)
	}

	bobSig := ed25519.Sign(bobPriv, []byte(bobChallenge.Challenge))
	bobAuthMsg := WSMessage{
		Type:      "AUTH",
		Pubkey:    bobPubHex,
		Signature: hex.EncodeToString(bobSig),
	}
	if err := bobConn.WriteJSON(bobAuthMsg); err != nil {
		t.Fatalf("failed to send Bob AUTH: %v", err)
	}

	var bobAuthOk WSMessage
	if err := bobConn.ReadJSON(&bobAuthOk); err != nil || bobAuthOk.Type != "AUTH_OK" {
		t.Fatalf("Bob auth failed: %v", err)
	}

	// 3. Alice sends a message to Bob via WebSocket
	aliceMsg := WSMessage{
		Type:        "SEND_MESSAGE",
		RecipientID: bobID,
		Envelope:    "alice_envelope_data",
	}
	if err := aliceConn.WriteJSON(aliceMsg); err != nil {
		t.Fatalf("failed to write send_message: %v", err)
	}

	// Bob should receive it instantly
	var bobReceived WSMessage
	if err := bobConn.ReadJSON(&bobReceived); err != nil {
		t.Fatalf("failed to read Bob message: %v", err)
	}
	if bobReceived.Type != "NEW_MESSAGE" || bobReceived.Envelope != "alice_envelope_data" {
		t.Errorf("wrong message received by Bob: %v", bobReceived)
	}

	// 4. Bob typing lock status Alice
	bobTyping := WSMessage{
		Type:        "TYPING_STATUS",
		RecipientID: aliceID,
		Status:      "typing",
	}
	if err := bobConn.WriteJSON(bobTyping); err != nil {
		t.Fatalf("failed to send typing status: %v", err)
	}

	var aliceTypingReceived WSMessage
	if err := aliceConn.ReadJSON(&aliceTypingReceived); err != nil {
		t.Fatalf("failed to read Alice typing: %v", err)
	}
	if aliceTypingReceived.Type != "PEER_TYPING_STATUS" || aliceTypingReceived.Status != "typing" {
		t.Errorf("wrong typing status frame: %v", aliceTypingReceived)
	}

	// 5. Offline Queue Polling check for Bob (disconnect Bob first)
	bobConn.Close()
	// Wait a bit for hub unregister
	time.Sleep(100 * time.Millisecond)

	// Alice sends message to Bob (who is now offline)
	aliceMsgOffline := WSMessage{
		Type:        "SEND_MESSAGE",
		RecipientID: bobID,
		Envelope:    "alice_offline_envelope_data",
	}
	if err := aliceConn.WriteJSON(aliceMsgOffline); err != nil {
		t.Fatalf("failed to write offline message: %v", err)
	}

	// Query Bob status via HTTP GET status
	timestamp := time.Now().Unix()
	statusMsg := fmt.Sprintf("%s:%d", bobID, timestamp)
	bobStatusSig := ed25519.Sign(bobPriv, []byte(statusMsg))

	u, _ := url.Parse(server.URL + "/api/v1/queue/status")
	valQuery := u.Query()
	valQuery.Set("id", bobID)
	valQuery.Set("timestamp", fmt.Sprintf("%d", timestamp))
	valQuery.Set("sig", hex.EncodeToString(bobStatusSig))
	valQuery.Set("pubkey", bobPubHex)
	u.RawQuery = valQuery.Encode()

	statusResp, err := http.Get(u.String())
	if err != nil {
		t.Fatalf("failed to request status: %v", err)
	}
	defer statusResp.Body.Close()

	var qStatus QueueStatusResponse
	if err := json.NewDecoder(statusResp.Body).Decode(&qStatus); err != nil {
		t.Fatalf("failed to decode status JSON: %v", err)
	}
	if !qStatus.HasPayload {
		t.Errorf("expected has_payload to be true, got false")
	}

	// 6. Test Nuke Locking: Host (Alice) Nukes Bob (Recipient)
	nukeMsg := WSMessage{
		Type:         "NUKE_RECIPIENT",
		RecipientID:  bobID,
		NukeEnvelope: "nuke_wiping_data",
	}
	if err := aliceConn.WriteJSON(nukeMsg); err != nil {
		t.Fatalf("failed to send nuke command: %v", err)
	}
	time.Sleep(100 * time.Millisecond)

	// Post message to Bob now should be blocked
	aliceMsgBlocked := WSMessage{
		Type:        "SEND_MESSAGE",
		RecipientID: bobID,
		Envelope:    "normal_msg_post_nuke",
	}
	if err := aliceConn.WriteJSON(aliceMsgBlocked); err != nil {
		t.Fatalf("failed to send blocked msg: %v", err)
	}

	var errorFrame WSMessage
	if err := aliceConn.ReadJSON(&errorFrame); err != nil {
		t.Fatalf("failed to read error response: %v", err)
	}
	if errorFrame.Type != "ERROR" || !strings.Contains(errorFrame.Message, "locked due to active Nuke") {
		t.Errorf("expected nuke lock error frame, got %v", errorFrame)
	}
}

func TestEphemeralTunnelsMock(t *testing.T) {
	rdbMock := &RedisClient{
		isMemory:          true,
		memoryQueue:       make(map[string][]memoryZ),
		memoryBlocks:      make(map[string]time.Time),
		memoryPoW:         make(map[string]powChallenge),
		memoryNonces:      make(map[string]time.Time),
		memoryBans:        make(map[string]time.Time),
		memoryFails:       make(map[string]ipFail),
		memoryRate:        make(map[string]int64),
		memoryPairings:    make(map[string]memoryPairing),
		memoryTunnels:     make(map[string]string),
		memoryTunnelBytes: make(map[string]int64),
	}

	// Ephemeral Tunnels Tests
	pubkeyA := "pub_a"
	pubkeyB := "pub_b"
	err := rdbMock.CreateTunnel(pubkeyA, pubkeyB, 1*time.Hour)
	if err != nil {
		t.Fatalf("failed to create tunnel: %v", err)
	}

	partner, err := rdbMock.GetTunnelPartner(pubkeyA)
	if err != nil || partner != pubkeyB {
		t.Errorf("tunnel routing A -> B failed: %v, got partner: %s", err, partner)
	}

	partner, err = rdbMock.GetTunnelPartner(pubkeyB)
	if err != nil || partner != pubkeyA {
		t.Errorf("tunnel routing B -> A failed: %v, got partner: %s", err, partner)
	}

	tunnelID := "pub_a:pub_b"
	bytesTotal, err := rdbMock.IncrementTunnelBytes(tunnelID, 500)
	if err != nil || bytesTotal != 500 {
		t.Errorf("failed to track tunnel bytes: %v, count: %d", err, bytesTotal)
	}

	err = rdbMock.DeleteTunnel(pubkeyA, pubkeyB)
	if err != nil {
		t.Fatalf("failed to delete tunnel: %v", err)
	}
	_, err = rdbMock.GetTunnelPartner(pubkeyA)
	if err == nil {
		t.Errorf("expected tunnel deletion, but route still exists")
	}
}

func TestGroupChatHubAndSpoke(t *testing.T) {
	// Setup 3 users: Alice (Host), Bob (Spoke 1), Charlie (Spoke 2)
	alicePub, alicePriv, _ := ed25519.GenerateKey(rand.Reader)
	aliceID := GenerateUserID(alicePub)
	alicePubHex := hex.EncodeToString(alicePub)

	bobPub, bobPriv, _ := ed25519.GenerateKey(rand.Reader)
	bobID := GenerateUserID(bobPub)
	bobPubHex := hex.EncodeToString(bobPub)

	charliePub, charliePriv, _ := ed25519.GenerateKey(rand.Reader)
	charlieID := GenerateUserID(charliePub)
	charliePubHex := hex.EncodeToString(charliePub)

	testRdb, err := NewRedisClient("localhost:6379")
	if err != nil || testRdb.IsMemory() {
		t.Skip("Skipping integration test: Redis not running on localhost:6379")
		return
	}
	defer testRdb.Close()
	rdb = testRdb
	rdb.FlushAll()

	hub := NewHub(rdb)
	go hub.Run()

	mux := http.NewServeMux()
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		ServeWS(hub, w, r)
	})

	server := httptest.NewServer(mux)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"

	// Helper function to connect and authenticate a user
	connectAndAuth := func(pubHex string, privKey ed25519.PrivateKey) *websocket.Conn {
		conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		if err != nil {
			t.Fatalf("failed to dial: %v", err)
		}
		var challenge WSMessage
		if err := conn.ReadJSON(&challenge); err != nil {
			t.Fatalf("failed to read challenge: %v", err)
		}
		sig := ed25519.Sign(privKey, []byte(challenge.Challenge))
		authMsg := WSMessage{
			Type:      "AUTH",
			Pubkey:    pubHex,
			Signature: hex.EncodeToString(sig),
		}
		if err := conn.WriteJSON(authMsg); err != nil {
			t.Fatalf("failed to write auth: %v", err)
		}
		var authOk WSMessage
		if err := conn.ReadJSON(&authOk); err != nil || authOk.Type != "AUTH_OK" {
			t.Fatalf("auth failed: %v", err)
		}
		return conn
	}

	aliceConn := connectAndAuth(alicePubHex, alicePriv)
	defer aliceConn.Close()

	bobConn := connectAndAuth(bobPubHex, bobPriv)
	defer bobConn.Close()

	charlieConn := connectAndAuth(charliePubHex, charliePriv)
	defer charlieConn.Close()

	// 1. Bob requests a sequence number from Alice (Host)
	reqOrder := WSMessage{
		Type:   "REQUEST_ORDER",
		HostID: aliceID,
	}
	if err := bobConn.WriteJSON(reqOrder); err != nil {
		t.Fatalf("failed to write REQUEST_ORDER: %v", err)
	}

	// Alice (Host) receives the request order
	var hostReq WSMessage
	if err := aliceConn.ReadJSON(&hostReq); err != nil || hostReq.Type != "SPOKE_REQUEST_ORDER" {
		t.Fatalf("expected SPOKE_REQUEST_ORDER, got: %v", hostReq)
	}
	if hostReq.SpokeID != bobID {
		t.Errorf("expected spoke ID %s, got %s", bobID, hostReq.SpokeID)
	}

	// 2. Alice confirms the sequence number
	confirmOrder := WSMessage{
		Type:     "CONFIRM_ORDER",
		SpokeID:  bobID,
		Sequence: 42,
	}
	if err := aliceConn.WriteJSON(confirmOrder); err != nil {
		t.Fatalf("failed to write CONFIRM_ORDER: %v", err)
	}

	// Bob receives the confirmation
	var spokeConfirm WSMessage
	if err := bobConn.ReadJSON(&spokeConfirm); err != nil || spokeConfirm.Type != "ORDER_CONFIRMED" {
		t.Fatalf("expected ORDER_CONFIRMED, got: %v", spokeConfirm)
	}
	if spokeConfirm.Sequence != 42 {
		t.Errorf("expected sequence 42, got %d", spokeConfirm.Sequence)
	}

	// 3. Bob sends the group message to Alice (Host)
	groupMsg := WSMessage{
		Type:        "SEND_MESSAGE",
		RecipientID: aliceID,
		Envelope:    "bob_group_envelope_data",
		ContentType: "group_message",
	}
	if err := bobConn.WriteJSON(groupMsg); err != nil {
		t.Fatalf("failed to send message: %v", err)
	}

	// Alice receives Bob's message
	var receivedMsg WSMessage
	if err := aliceConn.ReadJSON(&receivedMsg); err != nil || receivedMsg.Type != "NEW_MESSAGE" {
		t.Fatalf("expected NEW_MESSAGE, got: %v", receivedMsg)
	}
	if receivedMsg.SenderID != bobID || receivedMsg.Envelope != "bob_group_envelope_data" {
		t.Errorf("wrong message received: %v", receivedMsg)
	}

	// 4. Alice (Host) broadcasts to Bob and Charlie
	broadcast := WSMessage{
		Type:       "BROADCAST_GROUP_MESSAGE",
		Recipients: []string{bobID, charlieID},
		Envelopes: map[string]string{
			bobID:     "re_encrypted_bob_envelope",
			charlieID: "re_encrypted_charlie_envelope",
		},
	}
	if err := aliceConn.WriteJSON(broadcast); err != nil {
		t.Fatalf("failed to write BROADCAST_GROUP_MESSAGE: %v", err)
	}

	// Bob and Charlie should receive their respective envelopes
	var bobRecv WSMessage
	if err := bobConn.ReadJSON(&bobRecv); err != nil || bobRecv.Type != "NEW_MESSAGE" {
		t.Fatalf("expected Bob to receive NEW_MESSAGE, got: %v", bobRecv)
	}
	if bobRecv.Envelope != "re_encrypted_bob_envelope" || bobRecv.SenderID != aliceID {
		t.Errorf("Bob received wrong envelope: %v", bobRecv)
	}

	var charlieRecv WSMessage
	if err := charlieConn.ReadJSON(&charlieRecv); err != nil || charlieRecv.Type != "NEW_MESSAGE" {
		t.Fatalf("expected Charlie to receive NEW_MESSAGE, got: %v", charlieRecv)
	}
	if charlieRecv.Envelope != "re_encrypted_charlie_envelope" || charlieRecv.SenderID != aliceID {
		t.Errorf("Charlie received wrong envelope: %v", charlieRecv)
	}
}
