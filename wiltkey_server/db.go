package main

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

type PGMessage struct {
	ID          string
	RecipientID string
	SenderID    string
	Envelope    *string // Nullable if stored in bucket
	BucketURL   *string // Nullable if stored inline
	ContentType string
	ExpiresAt   time.Time
	SizeBytes   int64
	// OfferMeta is the message envelope with its big `d` ciphertext blanked —
	// enough for the recipient to place the message in the right chat and render
	// a pending-download bubble without fetching the body. Empty for inline rows.
	OfferMeta string
}

type PGEntitlement struct {
	UserID              string
	VerificationKeyHash string
	ExpiresAt           time.Time
}

type PGClientAttestation struct {
	UserID      string
	ClientType  string
	IssuedAt    time.Time
	ExpiresAt   time.Time
	CertSig     string
	RelayPubkey string
}

type PGStory struct {
	ID            string    `json:"id"`
	SenderID      string    `json:"sender_id"`
	StoryType     string    `json:"story_type"`
	CiphertextB64 string    `json:"ciphertext_b64"`
	BucketURL     *string   `json:"bucket_url,omitempty"`
	MediaMeta     string    `json:"media_meta,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
	ExpiresAt     time.Time `json:"expires_at"`
	BytesUsed     int64     `json:"bytes_used"`
}

type PGStoryReaction struct {
	ID        string    `json:"id"`
	StoryID   string    `json:"story_id"`
	ReactorID string    `json:"reactor_id"`
	Emoji     string    `json:"emoji"`
	CreatedAt time.Time `json:"created_at"`
}

type PGSocialBudget struct {
	UserID    string    `json:"user_id"`
	BytesUsed int64     `json:"bytes_used"`
	WeekStart time.Time `json:"week_start"`
	UpdatedAt time.Time `json:"updated_at"`
}

type PostgresClient struct {
	db *sql.DB
}

// NewPostgresClient initializes Postgres connection and runs migrations.
func NewPostgresClient(connStr string) (*PostgresClient, error) {
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, fmt.Errorf("failed to open postgres: %v", err)
	}

	// Ping database to confirm connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping postgres: %v", err)
	}

	client := &PostgresClient{db: db}
	if err := client.runMigrations(); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to run postgres migrations: %v", err)
	}

	return client, nil
}

func (p *PostgresClient) Close() error {
	if p.db != nil {
		return p.db.Close()
	}
	return nil
}

func (p *PostgresClient) runMigrations() error {
	// Create messages table
	_, err := p.db.Exec(`
		CREATE TABLE IF NOT EXISTS messages (
			id UUID PRIMARY KEY,
			recipient_id VARCHAR(64) NOT NULL,
			sender_id VARCHAR(64) NOT NULL,
			envelope TEXT,
			bucket_url VARCHAR(255),
			content_type VARCHAR(64) NOT NULL,
			created_at TIMESTAMP NOT NULL DEFAULT NOW(),
			expires_at TIMESTAMP NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
		CREATE INDEX IF NOT EXISTS idx_messages_expires ON messages(expires_at);
	`)
	if err != nil {
		return fmt.Errorf("error creating messages table: %v", err)
	}

	// Envelope byte size, so a FILE_OFFER can advertise how big the pending
	// download is (and the download endpoint can set Content-Length) without
	// stat-ing the object store. 0 for legacy rows.
	_, err = p.db.Exec(`
		ALTER TABLE messages ADD COLUMN IF NOT EXISTS size_bytes BIGINT NOT NULL DEFAULT 0;
		ALTER TABLE messages ADD COLUMN IF NOT EXISTS offer_meta TEXT NOT NULL DEFAULT '';
	`)
	if err != nil {
		return fmt.Errorf("error adding large-file columns: %v", err)
	}

	// Create entitlements table
	_, err = p.db.Exec(`
		CREATE TABLE IF NOT EXISTS entitlements (
			user_id VARCHAR(64) PRIMARY KEY,
			verification_key_hash VARCHAR(64) NOT NULL,
			expires_at TIMESTAMP NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_entitlements_expires ON entitlements(expires_at);
	`)
	if err != nil {
		return fmt.Errorf("error creating entitlements table: %v", err)
	}

	// Create client_attestations table (Play Integrity verification cache)
	_, err = p.db.Exec(`
		CREATE TABLE IF NOT EXISTS client_attestations (
			user_id VARCHAR(64) PRIMARY KEY,
			client_type VARCHAR(32) NOT NULL,
			issued_at TIMESTAMP NOT NULL,
			expires_at TIMESTAMP NOT NULL,
			cert_sig VARCHAR(128) NOT NULL,
			relay_pubkey VARCHAR(64) NOT NULL DEFAULT ''
		);
		ALTER TABLE client_attestations ADD COLUMN IF NOT EXISTS relay_pubkey VARCHAR(64) NOT NULL DEFAULT '';
		CREATE INDEX IF NOT EXISTS idx_attestations_expires ON client_attestations(expires_at);
	`)
	if err != nil {
		return fmt.Errorf("error creating client_attestations table: %v", err)
	}

	// Create stories, reactions, and social budgets tables
	_, err = p.db.Exec(`
		CREATE TABLE IF NOT EXISTS stories (
			id UUID PRIMARY KEY,
			sender_id VARCHAR(64) NOT NULL,
			story_type VARCHAR(32) NOT NULL,
			ciphertext_b64 TEXT NOT NULL,
			bucket_url VARCHAR(255),
			media_meta TEXT NOT NULL DEFAULT '',
			created_at TIMESTAMP NOT NULL DEFAULT NOW(),
			expires_at TIMESTAMP NOT NULL,
			bytes_used BIGINT NOT NULL DEFAULT 0
		);
		CREATE INDEX IF NOT EXISTS idx_stories_sender ON stories(sender_id);
		CREATE INDEX IF NOT EXISTS idx_stories_expires ON stories(expires_at);

		CREATE TABLE IF NOT EXISTS story_reactions (
			id UUID PRIMARY KEY,
			story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
			reactor_id VARCHAR(64) NOT NULL,
			emoji VARCHAR(32) NOT NULL,
			created_at TIMESTAMP NOT NULL DEFAULT NOW(),
			UNIQUE(story_id, reactor_id)
		);
		CREATE INDEX IF NOT EXISTS idx_reactions_story ON story_reactions(story_id);

		CREATE TABLE IF NOT EXISTS social_budgets (
			user_id VARCHAR(64) PRIMARY KEY,
			bytes_used BIGINT NOT NULL DEFAULT 0,
			week_start TIMESTAMP NOT NULL,
			updated_at TIMESTAMP NOT NULL DEFAULT NOW()
		);
	`)
	if err != nil {
		return fmt.Errorf("error creating stories and social tables: %v", err)
	}

	return nil
}

// StoreMessage inserts a new offline message into the database.
func (p *PostgresClient) StoreMessage(recipientID, senderID string, envelope *string, bucketURL *string, contentType string, ttl time.Duration) (string, error) {
	return p.StoreMessageSized(recipientID, senderID, envelope, bucketURL, contentType, ttl, 0, "")
}

// StoreMessageSized is StoreMessage plus the envelope's byte size and offer
// metadata, recorded so a pending large file can be advertised (and streamed)
// without ever pulling the body back out of storage.
func (p *PostgresClient) StoreMessageSized(recipientID, senderID string, envelope *string, bucketURL *string, contentType string, ttl time.Duration, size int64, offerMeta string) (string, error) {
	id := uuid.New().String()
	expiresAt := time.Now().Add(ttl)

	_, err := p.db.Exec(`
		INSERT INTO messages (id, recipient_id, sender_id, envelope, bucket_url, content_type, expires_at, size_bytes, offer_meta)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`, id, recipientID, senderID, envelope, bucketURL, contentType, expiresAt, size, offerMeta)
	if err != nil {
		return "", err
	}

	return id, nil
}

// GetFileMessage returns the bucket-backed message [id] addressed to
// [recipientID], or nil when it doesn't exist, has expired, isn't a file, or
// belongs to someone else. Used to authorize + serve a download.
func (p *PostgresClient) GetFileMessage(id, recipientID string) (*PGMessage, error) {
	row := p.db.QueryRow(`
		SELECT id, recipient_id, sender_id, envelope, bucket_url, content_type, expires_at, size_bytes, offer_meta
		FROM messages
		WHERE id = $1 AND recipient_id = $2 AND bucket_url IS NOT NULL AND expires_at > NOW()
	`, id, recipientID)

	var m PGMessage
	err := row.Scan(&m.ID, &m.RecipientID, &m.SenderID, &m.Envelope, &m.BucketURL,
		&m.ContentType, &m.ExpiresAt, &m.SizeBytes, &m.OfferMeta)
	if err == sql.ErrNoRows {
		return nil, nil
	} else if err != nil {
		return nil, err
	}
	return &m, nil
}

// GetPendingMessages returns all unexpired pending messages for a recipient.
func (p *PostgresClient) GetPendingMessages(recipientID string) ([]PGMessage, error) {
	rows, err := p.db.Query(`
		SELECT id, recipient_id, sender_id, envelope, bucket_url, content_type, expires_at, size_bytes, offer_meta
		FROM messages
		WHERE recipient_id = $1 AND expires_at > NOW()
		ORDER BY created_at ASC
	`, recipientID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msgs []PGMessage
	for rows.Next() {
		var msg PGMessage
		err := rows.Scan(&msg.ID, &msg.RecipientID, &msg.SenderID, &msg.Envelope, &msg.BucketURL, &msg.ContentType, &msg.ExpiresAt, &msg.SizeBytes, &msg.OfferMeta)
		if err != nil {
			return nil, err
		}
		msgs = append(msgs, msg)
	}

	return msgs, nil
}

// DeleteMessage deletes a specific message by its UUID.
func (p *PostgresClient) DeleteMessage(id string) error {
	_, err := p.db.Exec("DELETE FROM messages WHERE id = $1", id)
	return err
}

// CountMessagesByBucket returns how many message rows still reference a bucket
// object. Group fan-out shares ONE bucket object across N pointer rows, so a
// caller must only delete the object once this reaches zero — otherwise one
// recipient's ACK (or a shorter free-tier TTL expiring) would strand the file
// for the others.
func (p *PostgresClient) CountMessagesByBucket(bucketURL string) (int, error) {
	var n int
	err := p.db.QueryRow("SELECT COUNT(*) FROM messages WHERE bucket_url = $1", bucketURL).Scan(&n)
	return n, err
}

// DeleteInlineMessages deletes all unexpired inline messages for a user (called after WebSocket delivery).
func (p *PostgresClient) DeleteInlineMessages(recipientID string) error {
	_, err := p.db.Exec("DELETE FROM messages WHERE recipient_id = $1 AND envelope IS NOT NULL", recipientID)
	return err
}

// PruneExpiredMessages removes expired messages and returns the URLs of bucket
// objects that are now safe to delete. Group fan-out shares one object across N
// pointer rows with PER-RECIPIENT hold TTLs (72h Plus / 24h free), so an object
// must NOT be deleted while a not-yet-expired row still points at it. So: gather
// the distinct bucket URLs of expired rows, delete the expired rows, then return
// only those URLs no surviving row still references.
func (p *PostgresClient) PruneExpiredMessages() ([]string, error) {
	rows, err := p.db.Query(`
		SELECT DISTINCT bucket_url
		FROM messages
		WHERE expires_at <= NOW() AND bucket_url IS NOT NULL
	`)
	if err != nil {
		return nil, err
	}
	var candidates []string
	for rows.Next() {
		var url string
		if err := rows.Scan(&url); err == nil {
			candidates = append(candidates, url)
		}
	}
	rows.Close()

	// Delete the expired rows first, so the ref-count below reflects only the
	// rows that are still live.
	if _, err = p.db.Exec("DELETE FROM messages WHERE expires_at <= NOW()"); err != nil {
		return nil, fmt.Errorf("error deleting expired messages: %v", err)
	}

	var urls []string
	for _, url := range candidates {
		var n int
		if err := p.db.QueryRow("SELECT COUNT(*) FROM messages WHERE bucket_url = $1", url).Scan(&n); err != nil {
			// Fail SAFE: can't confirm it's unreferenced → leave the object (a
			// later sweep retries once its rows are gone).
			log.Printf("[Prune Warning] ref-count for %s failed: %v — keeping object", url, err)
			continue
		}
		if n == 0 {
			urls = append(urls, url)
		}
	}
	return urls, nil
}

// StoreEntitlement creates or updates user's premium entitlement.
func (p *PostgresClient) StoreEntitlement(userID, verificationKeyHash string, expiresAt time.Time) error {
	_, err := p.db.Exec(`
		INSERT INTO entitlements (user_id, verification_key_hash, expires_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id) DO UPDATE 
		SET verification_key_hash = EXCLUDED.verification_key_hash,
		    expires_at = EXCLUDED.expires_at
	`, userID, verificationKeyHash, expiresAt)
	return err
}

// GetEntitlement retrieves a user's entitlement if it exists and is not expired.
func (p *PostgresClient) GetEntitlement(userID string) (*PGEntitlement, error) {
	row := p.db.QueryRow(`
		SELECT user_id, verification_key_hash, expires_at
		FROM entitlements
		WHERE user_id = $1 AND expires_at > NOW()
	`, userID)

	var ent PGEntitlement
	err := row.Scan(&ent.UserID, &ent.VerificationKeyHash, &ent.ExpiresAt)
	if err == sql.ErrNoRows {
		return nil, nil
	} else if err != nil {
		return nil, err
	}

	return &ent, nil
}

// StoreClientAttestation creates or updates user's client integrity attestation.
func (p *PostgresClient) StoreClientAttestation(userID, clientType string, issuedAt, expiresAt time.Time, certSig, relayPubkey string) error {
	_, err := p.db.Exec(`
		INSERT INTO client_attestations (user_id, client_type, issued_at, expires_at, cert_sig, relay_pubkey)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (user_id) DO UPDATE 
		SET client_type = EXCLUDED.client_type,
		    issued_at = EXCLUDED.issued_at,
		    expires_at = EXCLUDED.expires_at,
		    cert_sig = EXCLUDED.cert_sig,
		    relay_pubkey = EXCLUDED.relay_pubkey
	`, userID, clientType, issuedAt, expiresAt, certSig, relayPubkey)
	return err
}

// GetClientAttestation retrieves a user's client attestation if it exists and is not expired.
func (p *PostgresClient) GetClientAttestation(userID string) (*PGClientAttestation, error) {
	row := p.db.QueryRow(`
		SELECT user_id, client_type, issued_at, expires_at, cert_sig, relay_pubkey
		FROM client_attestations
		WHERE user_id = $1 AND expires_at > NOW()
	`, userID)

	var att PGClientAttestation
	err := row.Scan(&att.UserID, &att.ClientType, &att.IssuedAt, &att.ExpiresAt, &att.CertSig, &att.RelayPubkey)
	if err == sql.ErrNoRows {
		return nil, nil
	} else if err != nil {
		return nil, err
	}

	return &att, nil
}

// GetOrCreateSocialBudget retrieves or initializes the weekly social budget for a user.
// Resets budget automatically if 7 days have passed.
func (p *PostgresClient) GetOrCreateSocialBudget(userID string) (*PGSocialBudget, error) {
	now := time.Now()
	var b PGSocialBudget
	err := p.db.QueryRow(`
		SELECT user_id, bytes_used, week_start, updated_at
		FROM social_budgets
		WHERE user_id = $1
	`, userID).Scan(&b.UserID, &b.BytesUsed, &b.WeekStart, &b.UpdatedAt)

	if err == sql.ErrNoRows {
		b = PGSocialBudget{
			UserID:    userID,
			BytesUsed: 0,
			WeekStart: now,
			UpdatedAt: now,
		}
		_, err := p.db.Exec(`
			INSERT INTO social_budgets (user_id, bytes_used, week_start, updated_at)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (user_id) DO NOTHING
		`, b.UserID, b.BytesUsed, b.WeekStart, b.UpdatedAt)
		if err != nil {
			return nil, err
		}
		return &b, nil
	} else if err != nil {
		return nil, err
	}

	if now.Sub(b.WeekStart) >= 7*24*time.Hour {
		b.BytesUsed = 0
		b.WeekStart = now
		b.UpdatedAt = now
		_, err := p.db.Exec(`
			UPDATE social_budgets
			SET bytes_used = 0, week_start = $2, updated_at = $3
			WHERE user_id = $1
		`, b.UserID, b.WeekStart, b.UpdatedAt)
		if err != nil {
			return nil, err
		}
	}

	return &b, nil
}

// ConsumeSocialBudget checks if the user has enough budget to spend [bytes], and if so, atomically increments usage.
// Returns (allowed, newBytesUsed, maxBytes, error).
func (p *PostgresClient) ConsumeSocialBudget(userID string, bytes int64, isPlus bool) (bool, int64, int64, error) {
	_, err := p.GetOrCreateSocialBudget(userID)
	if err != nil {
		return false, 0, 0, err
	}

	var maxBudget int64 = 10 * 1024 * 1024 // 10 MB for free
	if isPlus {
		maxBudget = 100 * 1024 * 1024 // 100 MB for plus
	}

	var newBytesUsed int64
	err = p.db.QueryRow(`
		UPDATE social_budgets
		SET bytes_used = bytes_used + $2, updated_at = NOW()
		WHERE user_id = $1 AND bytes_used + $2 <= $3
		RETURNING bytes_used
	`, userID, bytes, maxBudget).Scan(&newBytesUsed)

	if err == sql.ErrNoRows {
		var currentUsed int64
		_ = p.db.QueryRow(`SELECT bytes_used FROM social_budgets WHERE user_id = $1`, userID).Scan(&currentUsed)
		return false, currentUsed, maxBudget, nil
	}
	if err != nil {
		return false, 0, 0, err
	}

	return true, newBytesUsed, maxBudget, nil
}

// PostStory stores a new story.
func (p *PostgresClient) PostStory(senderID, storyType, ciphertextB64 string, bucketURL *string, mediaMeta string, bytesUsed int64, ttl time.Duration) (string, error) {
	id := uuid.New().String()
	expiresAt := time.Now().Add(ttl)

	_, err := p.db.Exec(`
		INSERT INTO stories (id, sender_id, story_type, ciphertext_b64, bucket_url, media_meta, bytes_used, created_at, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), $8)
	`, id, senderID, storyType, ciphertextB64, bucketURL, mediaMeta, bytesUsed, expiresAt)
	if err != nil {
		return "", err
	}
	return id, nil
}

// GetStoriesFeed returns unexpired stories for given senders.
func (p *PostgresClient) GetStoriesFeed(senders []string) ([]PGStory, error) {
	if len(senders) == 0 {
		return []PGStory{}, nil
	}

	query := `
		SELECT id, sender_id, story_type, ciphertext_b64, bucket_url, media_meta, bytes_used, created_at, expires_at
		FROM stories
		WHERE sender_id = ANY($1) AND expires_at > NOW()
		ORDER BY created_at ASC
	`
	rows, err := p.db.Query(query, pq.Array(senders))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var stories []PGStory
	for rows.Next() {
		var s PGStory
		var bucketURL sql.NullString
		if err := rows.Scan(&s.ID, &s.SenderID, &s.StoryType, &s.CiphertextB64, &bucketURL, &s.MediaMeta, &s.BytesUsed, &s.CreatedAt, &s.ExpiresAt); err != nil {
			return nil, err
		}
		if bucketURL.Valid {
			s.BucketURL = &bucketURL.String
		}
		stories = append(stories, s)
	}
	return stories, nil
}

// GetStory loads a single story by ID.
func (p *PostgresClient) GetStory(id string) (*PGStory, error) {
	var s PGStory
	var bucketURL sql.NullString
	err := p.db.QueryRow(`
		SELECT id, sender_id, story_type, ciphertext_b64, bucket_url, media_meta, bytes_used, created_at, expires_at
		FROM stories
		WHERE id = $1 AND expires_at > NOW()
	`, id).Scan(&s.ID, &s.SenderID, &s.StoryType, &s.CiphertextB64, &bucketURL, &s.MediaMeta, &s.BytesUsed, &s.CreatedAt, &s.ExpiresAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if bucketURL.Valid {
		s.BucketURL = &bucketURL.String
	}
	return &s, nil
}

// DeleteStory deletes a story owned by userID.
func (p *PostgresClient) DeleteStory(id, userID string) error {
	_, err := p.db.Exec(`DELETE FROM stories WHERE id = $1 AND sender_id = $2`, id, userID)
	return err
}

// AddOrUpdateStoryReaction adds or updates an emoji reaction.
func (p *PostgresClient) AddOrUpdateStoryReaction(storyID, reactorID, emoji string) error {
	id := uuid.New().String()
	_, err := p.db.Exec(`
		INSERT INTO story_reactions (id, story_id, reactor_id, emoji, created_at)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (story_id, reactor_id)
		DO UPDATE SET emoji = EXCLUDED.emoji, created_at = NOW()
	`, id, storyID, reactorID, emoji)
	return err
}

// GetStoryReactions returns all reactions for a story.
func (p *PostgresClient) GetStoryReactions(storyID string) ([]PGStoryReaction, error) {
	rows, err := p.db.Query(`
		SELECT id, story_id, reactor_id, emoji, created_at
		FROM story_reactions
		WHERE story_id = $1
		ORDER BY created_at ASC
	`, storyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reactions []PGStoryReaction
	for rows.Next() {
		var r PGStoryReaction
		if err := rows.Scan(&r.ID, &r.StoryID, &r.ReactorID, &r.Emoji, &r.CreatedAt); err != nil {
			return nil, err
		}
		reactions = append(reactions, r)
	}
	return reactions, nil
}

// WipeUserSocialData deletes all stories and reactions for a user and returns any bucket URLs.
func (p *PostgresClient) WipeUserSocialData(userID string) ([]string, error) {
	rows, err := p.db.Query(`
		DELETE FROM stories
		WHERE sender_id = $1
		RETURNING bucket_url
	`, userID)
	var deletedURLs []string
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var bucketURL sql.NullString
			if err := rows.Scan(&bucketURL); err == nil && bucketURL.Valid && bucketURL.String != "" {
				deletedURLs = append(deletedURLs, bucketURL.String)
			}
		}
	}
	_, _ = p.db.Exec(`DELETE FROM story_reactions WHERE reactor_id = $1`, userID)
	_, _ = p.db.Exec(`DELETE FROM social_budgets WHERE user_id = $1`, userID)
	return deletedURLs, nil
}

// PruneExpiredStories deletes stories older than their expires_at and returns their bucket URLs.
func (p *PostgresClient) PruneExpiredStories() ([]string, error) {
	rows, err := p.db.Query(`
		DELETE FROM stories
		WHERE expires_at <= NOW()
		RETURNING bucket_url
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var deletedURLs []string
	for rows.Next() {
		var bucketURL sql.NullString
		if err := rows.Scan(&bucketURL); err == nil && bucketURL.Valid && bucketURL.String != "" {
			deletedURLs = append(deletedURLs, bucketURL.String)
		}
	}
	return deletedURLs, nil
}
