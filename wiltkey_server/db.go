package main

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	_ "github.com/lib/pq"
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

// DeleteInlineMessages deletes all unexpired inline messages for a user (called after WebSocket delivery).
func (p *PostgresClient) DeleteInlineMessages(recipientID string) error {
	_, err := p.db.Exec("DELETE FROM messages WHERE recipient_id = $1 AND envelope IS NOT NULL", recipientID)
	return err
}

// PruneExpiredMessages removes expired messages from the database and returns the URLs of any deleted bucket objects.
func (p *PostgresClient) PruneExpiredMessages() ([]string, error) {
	// First select bucket URLs of expired messages to clean up object storage
	rows, err := p.db.Query(`
		SELECT bucket_url 
		FROM messages 
		WHERE expires_at <= NOW() AND bucket_url IS NOT NULL
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var urls []string
	for rows.Next() {
		var url string
		if err := rows.Scan(&url); err == nil {
			urls = append(urls, url)
		}
	}

	// Delete from database
	_, err = p.db.Exec("DELETE FROM messages WHERE expires_at <= NOW()")
	if err != nil {
		return nil, fmt.Errorf("error deleting expired messages: %v", err)
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
