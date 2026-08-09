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
	"os"
	"path/filepath"
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

	hub := NewHub(rdb, NewPushSender()) // NewPushSender() is disabled without FCM env
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

	hub := NewHub(rdb, NewPushSender()) // NewPushSender() is disabled without FCM env
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

	// 4. Alice (Host) fans one identical envelope out to Bob and Charlie via
	// server-side broadcast (group envelopes are byte-identical — shared keystream,
	// no per-recipient re-encryption — so it's a single Envelope + Recipients list,
	// NOT a per-recipient map).
	const groupEnvelope = "shared_group_envelope"
	broadcast := WSMessage{
		Type:        "BROADCAST_GROUP_MESSAGE",
		Recipients:  []string{bobID, charlieID},
		Envelope:    groupEnvelope,
		ContentType: "group_message",
	}
	if err := aliceConn.WriteJSON(broadcast); err != nil {
		t.Fatalf("failed to write BROADCAST_GROUP_MESSAGE: %v", err)
	}

	// Both online recipients receive the same envelope, attributed to Alice.
	var bobRecv WSMessage
	if err := bobConn.ReadJSON(&bobRecv); err != nil || bobRecv.Type != "NEW_MESSAGE" {
		t.Fatalf("expected Bob to receive NEW_MESSAGE, got: %v", bobRecv)
	}
	if bobRecv.Envelope != groupEnvelope || bobRecv.SenderID != aliceID {
		t.Errorf("Bob received wrong envelope: %v", bobRecv)
	}

	var charlieRecv WSMessage
	if err := charlieConn.ReadJSON(&charlieRecv); err != nil || charlieRecv.Type != "NEW_MESSAGE" {
		t.Fatalf("expected Charlie to receive NEW_MESSAGE, got: %v", charlieRecv)
	}
	if charlieRecv.Envelope != groupEnvelope || charlieRecv.SenderID != aliceID {
		t.Errorf("Charlie received wrong envelope: %v", charlieRecv)
	}
}

func TestStorageAndSubscriptions(t *testing.T) {
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

	// Try to connect to Postgres
	pgURL := os.Getenv("POSTGRES_URL")
	if pgURL == "" {
		pgURL = "postgres://wiltkey:wiltkey@localhost:5432/wiltkey?sslmode=disable"
	}
	testPg, err := NewPostgresClient(pgURL)
	if err != nil {
		t.Skipf("Skipping storage and subscription integration test: Postgres not running (%v)", err)
		return
	}
	defer testPg.Close()
	pg = testPg

	// Set up local storage fallback
	localDir := "./test_storage_dir"
	storage, err = NewLocalStorage(localDir)
	if err != nil {
		t.Fatalf("failed to setup local storage: %v", err)
	}
	defer os.RemoveAll(localDir)

	// Clean DB
	rdb.FlushAll()
	pg.db.Exec("DELETE FROM messages")
	pg.db.Exec("DELETE FROM entitlements")

	hub := NewHub(rdb, NewPushSender())
	go hub.Run()

	mux := http.NewServeMux()
	mux.HandleFunc("/api/v1/queue/post", rateLimitMiddleware(handlePostQueue(hub)))
	mux.HandleFunc("/api/v1/entitlement", rateLimitMiddleware(handlePostEntitlement))
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		ServeWS(hub, w, r)
	})

	server := httptest.NewServer(mux)
	defer server.Close()

	// Helper to dial WS
	dialWS := func(pubHex string, priv ed25519.PrivateKey) *websocket.Conn {
		wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
		conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		if err != nil {
			t.Fatalf("failed to dial WS: %v", err)
		}
		var challenge WSMessage
		if err := conn.ReadJSON(&challenge); err != nil {
			t.Fatalf("failed to read challenge: %v", err)
		}
		sig := ed25519.Sign(priv, []byte(challenge.Challenge))
		authMsg := WSMessage{
			Type:      "AUTH",
			Pubkey:    pubHex,
			Signature: hex.EncodeToString(sig),
		}
		if err := conn.WriteJSON(authMsg); err != nil {
			t.Fatalf("failed to send AUTH: %v", err)
		}
		var authOk WSMessage
		if err := conn.ReadJSON(&authOk); err != nil || authOk.Type != "AUTH_OK" {
			t.Fatalf("auth failed: %v", err)
		}
		return conn
	}

	// 1. Test High RAM fallback (route small message to Postgres instead of Redis)
	os.Setenv("HIGH_RAM_THRESHOLD_PERCENT", "0.0") // Force high memory load condition
	defer os.Unsetenv("HIGH_RAM_THRESHOLD_PERCENT")

	aliceConn := dialWS(alicePubHex, alicePriv)
	defer aliceConn.Close()

	// Send a 10KB message to Bob who is offline
	msg10K := strings.Repeat("A", 10*1024)
	sendMsg := WSMessage{
		Type:        "SEND_MESSAGE",
		RecipientID: bobID,
		Envelope:    msg10K,
		ContentType: "text",
	}
	if err := aliceConn.WriteJSON(sendMsg); err != nil {
		t.Fatalf("failed to send WS message: %v", err)
	}

	// Verify it was stored in Postgres database (since high RAM load is active)
	var count int
	err = pg.db.QueryRow("SELECT COUNT(*) FROM messages WHERE recipient_id = $1", bobID).Scan(&count)
	if err != nil || count != 1 {
		t.Errorf("expected 1 message in postgres under high RAM load, got %d, err: %v", count, err)
	}

	// Reset RAM threshold
	os.Setenv("HIGH_RAM_THRESHOLD_PERCENT", "100.0")

	// 2. Test Large file routing (>= 500KB) -> S3/Local storage + Postgres with client ACK
	msg600K := strings.Repeat("B", 600*1024)
	sendMsgLarge := WSMessage{
		Type:        "SEND_MESSAGE",
		RecipientID: bobID,
		Envelope:    msg600K,
		ContentType: "file",
	}
	if err := aliceConn.WriteJSON(sendMsgLarge); err != nil {
		t.Fatalf("failed to send large WS message: %v", err)
	}

	// Verify it was uploaded to storage and metadata stored in Postgres
	var dbMsg PGMessage
	err = pg.db.QueryRow("SELECT id, bucket_url FROM messages WHERE recipient_id = $1 AND envelope IS NULL", bobID).Scan(&dbMsg.ID, &dbMsg.BucketURL)
	if err != nil || dbMsg.BucketURL == nil {
		t.Fatalf("expected message to be stored in Postgres with bucket URL: %v", err)
	}

	// Verify local storage has the file
	storageKey := strings.TrimPrefix(*dbMsg.BucketURL, "local://")
	_, err = os.Stat(filepath.Join(localDir, storageKey))
	if err != nil {
		t.Errorf("expected storage file to exist: %v", err)
	}

	// 3. Bob comes online and delivers messages
	bobConn := dialWS(bobPubHex, bobPriv)
	defer bobConn.Close()

	// Bob should receive 2 messages:
	// Message 1: 10KB message (inline, from Postgres)
	var recv1 WSMessage
	if err := bobConn.ReadJSON(&recv1); err != nil || recv1.Envelope != msg10K {
		t.Fatalf("Bob failed to receive first message: %v", err)
	}

	// Message 2: 600KB message (bucket-backed, from Postgres)
	var recv2 WSMessage
	if err := bobConn.ReadJSON(&recv2); err != nil || recv2.Envelope != msg600K {
		t.Fatalf("Bob failed to receive second message: %v", err)
	}
	if recv2.MessageID != dbMsg.ID {
		t.Errorf("expected message_id %s, got %s", dbMsg.ID, recv2.MessageID)
	}

	// Verify the inline message is deleted from Postgres immediately
	pg.db.QueryRow("SELECT COUNT(*) FROM messages WHERE envelope IS NOT NULL").Scan(&count)
	if count != 0 {
		t.Errorf("expected 0 inline messages left in Postgres, got %d", count)
	}

	// Verify the bucket message is STILL in Postgres and storage (not acknowledged yet)
	pg.db.QueryRow("SELECT COUNT(*) FROM messages WHERE id = $1", dbMsg.ID).Scan(&count)
	if count != 1 {
		t.Errorf("expected large message to still exist in database, got %d", count)
	}

	// Bob acknowledges receipt
	ackMsg := WSMessage{
		Type:      "FILE_RECEIVED",
		MessageID: dbMsg.ID,
	}
	if err := bobConn.WriteJSON(ackMsg); err != nil {
		t.Fatalf("failed to send FILE_RECEIVED ack: %v", err)
	}

	// Give a bit of time for async delete processing
	time.Sleep(100 * time.Millisecond)

	// Verify the message and file are deleted
	pg.db.QueryRow("SELECT COUNT(*) FROM messages WHERE id = $1", dbMsg.ID).Scan(&count)
	if count != 0 {
		t.Errorf("expected database message to be deleted, got %d", count)
	}
	_, err = os.Stat(filepath.Join(localDir, storageKey))
	if !os.IsNotExist(err) {
		t.Errorf("expected storage file to be deleted, got: %v", err)
	}

	// 4. Test Premium verification (>= 5MB)
	msg6M := strings.Repeat("C", 6*1024*1024)
	sendMsg6M := WSMessage{
		Type:        "SEND_MESSAGE",
		RecipientID: bobID,
		Envelope:    msg6M,
		ContentType: "file",
	}
	// Alice is not premium yet. She sends it.
	if err := aliceConn.WriteJSON(sendMsg6M); err != nil {
		t.Fatalf("failed to send: %v", err)
	}

	// Should receive ERROR from server
	var errResp WSMessage
	if err := aliceConn.ReadJSON(&errResp); err != nil || errResp.Type != "ERROR" {
		t.Fatalf("expected ERROR frame, got: %v", errResp)
	}
	if !strings.Contains(errResp.Message, "requires an active premium subscription") {
		t.Errorf("unexpected error message: %s", errResp.Message)
	}

	// Register Alice's entitlement
	pg.StoreEntitlement(aliceID, "alicetokenhash", time.Now().Add(time.Hour))

	// Alice sends it again
	if err := aliceConn.WriteJSON(sendMsg6M); err != nil {
		t.Fatalf("failed to send: %v", err)
	}

	// Verification: should go through successfully (check database count of bucket message)
	var count6M int
	err = pg.db.QueryRow("SELECT COUNT(*) FROM messages WHERE recipient_id = $1 AND envelope IS NULL", bobID).Scan(&count6M)
	if err != nil || count6M != 1 {
		t.Errorf("expected 1 premium 6MB message stored in db, got %d, err: %v", count6M, err)
	}
}
