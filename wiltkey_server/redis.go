package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

var ctx = context.Background()

// maxQueueLen bounds a single recipient's offline queue. Without a cap, an
// authenticated sender can ZADD unbounded envelopes into a victim's queue
// (measured ~50k/s) and exhaust Redis memory. When exceeded, the oldest
// (soonest-to-expire) entries are dropped.
const maxQueueLen = 1000

type memoryZ struct {
	senderID    string
	envelope    string
	contentType string
	expires     time.Time
}

type powChallenge struct {
	difficulty int
	expires    time.Time
}

type ipFail struct {
	count   int64
	expires time.Time
}

type memoryPairing struct {
	data    string
	expires time.Time
}

type RedisClient struct {
	rdb               *redis.Client
	isMemory          bool
	memoryQueue       map[string][]memoryZ
	memoryBlocks      map[string]time.Time
	memoryPoW         map[string]powChallenge
	memoryNonces      map[string]time.Time
	memoryBans        map[string]time.Time
	memoryFails       map[string]ipFail
	memoryRate        map[string]int64
	memoryPairings    map[string]memoryPairing
	memoryTunnels     map[string]string
	memoryTunnelBytes map[string]int64
	memoryNukes       map[string]ipFail
	mu                sync.RWMutex
}

// NewRedisClient initializes connection to Redis. If it fails, falls back to in-memory DB client.
func NewRedisClient(addr string) (*RedisClient, error) {
	opt := &redis.Options{
		Addr: addr,
	}
	// Optional logical DB index for multi-tenant Redis isolation (e.g. shared host)
	if dbStr := os.Getenv("REDIS_DB"); dbStr != "" {
		if n, err := strconv.Atoi(dbStr); err == nil {
			opt.DB = n
		} else {
			log.Printf("Warning: invalid REDIS_DB value %q, using default DB 0", dbStr)
		}
	}
	rdb := redis.NewClient(opt)
	// Test ping
	_, err := rdb.Ping(ctx).Result()
	if err != nil {
		log.Printf("Warning: Failed to connect to Redis at %s (%v). Falling back to local in-memory DB client.", addr, err)
		return &RedisClient{
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
			memoryNukes:       make(map[string]ipFail),
		}, nil
	}
	return &RedisClient{rdb: rdb}, nil
}

// IsMemory returns true if this client is running in mock in-memory mode.
func (r *RedisClient) IsMemory() bool {
	return r.isMemory
}

// FlushAll clears all databases (used during integration tests).
func (r *RedisClient) FlushAll() error {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		r.memoryQueue = make(map[string][]memoryZ)
		r.memoryBlocks = make(map[string]time.Time)
		r.memoryPoW = make(map[string]powChallenge)
		r.memoryNonces = make(map[string]time.Time)
		r.memoryBans = make(map[string]time.Time)
		r.memoryFails = make(map[string]ipFail)
		r.memoryRate = make(map[string]int64)
		r.memoryPairings = make(map[string]memoryPairing)
		r.memoryTunnels = make(map[string]string)
		r.memoryTunnelBytes = make(map[string]int64)
		return nil
	}
	return r.rdb.FlushAll(ctx).Err()
}

// Close closes the Redis client connection.
func (r *RedisClient) Close() error {
	if r.isMemory {
		return nil
	}
	return r.rdb.Close()
}

// AddMessageToQueue adds an encrypted envelope to the recipient's sorted set queue with an expiry score.
func (r *RedisClient) AddMessageToQueue(recipientID string, senderID string, envelope string, contentType string, ttl time.Duration) error {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		now := time.Now()
		q := append(r.memoryQueue[recipientID], memoryZ{
			senderID:    senderID,
			envelope:    envelope,
			contentType: contentType,
			expires:     now.Add(ttl),
		})
		// Drop expired entries in place, then cap to the newest maxQueueLen.
		pruned := q[:0]
		for _, item := range q {
			if item.expires.After(now) {
				pruned = append(pruned, item)
			}
		}
		if len(pruned) > maxQueueLen {
			pruned = pruned[len(pruned)-maxQueueLen:]
		}
		r.memoryQueue[recipientID] = pruned
		return nil
	}

	queueEntry, _ := json.Marshal(map[string]string{
		"sender_id":    senderID,
		"envelope":     envelope,
		"content_type": contentType,
	})
	now := time.Now()
	member := redis.Z{
		Score:  float64(now.Add(ttl).Unix()),
		Member: string(queueEntry),
	}
	key := fmt.Sprintf("queue:%s", recipientID)

	pipe := r.rdb.TxPipeline()
	pipe.ZAdd(ctx, key, member)
	// Purge already-expired entries (expiry score < now) so dead weight can't pile up.
	pipe.ZRemRangeByScore(ctx, key, "-inf", fmt.Sprintf("(%d", now.Unix()))
	// Self-clean an abandoned queue even if it's never fetched.
	pipe.Expire(ctx, key, 7*24*time.Hour)
	card := pipe.ZCard(ctx, key)
	if _, err := pipe.Exec(ctx); err != nil {
		return err
	}
	// Cap: remove the (n - maxQueueLen) lowest-score (soonest-expiring) entries.
	if n := card.Val(); n > maxQueueLen {
		if err := r.rdb.ZRemRangeByRank(ctx, key, 0, n-maxQueueLen-1).Err(); err != nil {
			return err
		}
	}
	return nil
}

// FetchAndClearQueue retrieves all non-expired messages for a recipient, then deletes the queue.
func (r *RedisClient) FetchAndClearQueue(recipientID string) ([]map[string]string, error) {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()

		q, exists := r.memoryQueue[recipientID]
		if !exists {
			return []map[string]string{}, nil
		}

		now := time.Now()
		var active []map[string]string
		for _, item := range q {
			if item.expires.After(now) {
				active = append(active, map[string]string{
					"sender_id":    item.senderID,
					"envelope":     item.envelope,
					"content_type": item.contentType,
				})
			}
		}

		delete(r.memoryQueue, recipientID)
		return active, nil
	}

	key := fmt.Sprintf("queue:%s", recipientID)
	now := float64(time.Now().Unix())

	// Retrieve active messages (score >= now)
	messages, err := r.rdb.ZRangeByScore(ctx, key, &redis.ZRangeBy{
		Min: fmt.Sprintf("%f", now),
		Max: "+inf",
	}).Result()
	if err != nil {
		return nil, err
	}

	// Delete the queue key completely once retrieved
	err = r.rdb.Del(ctx, key).Err()
	if err != nil {
		return nil, err
	}

	var results []map[string]string
	for _, raw := range messages {
		var entry map[string]string
		if err := json.Unmarshal([]byte(raw), &entry); err != nil {
			// Backward compat: treat as raw envelope string
			entry = map[string]string{"sender_id": "", "envelope": raw, "content_type": ""}
		}
		results = append(results, entry)
	}

	return results, nil
}

// GetActiveQueueCount counts non-expired messages in the recipient's queue.
func (r *RedisClient) GetActiveQueueCount(recipientID string) (int64, error) {
	if r.isMemory {
		r.mu.RLock()
		defer r.mu.RUnlock()

		q, exists := r.memoryQueue[recipientID]
		if !exists {
			return 0, nil
		}

		now := time.Now()
		var count int64
		for _, item := range q {
			if item.expires.After(now) {
				count++
			}
		}
		return count, nil
	}

	key := fmt.Sprintf("queue:%s", recipientID)
	now := float64(time.Now().Unix())
	return r.rdb.ZCount(ctx, key, fmt.Sprintf("%f", now), "+inf").Result()
}

// nukeBlockTTL bounds how long a nuke can hold a recipient's queue blocked. An
// online victim auto-ACKs and unblocks immediately; this TTL only bites an OFFLINE
// victim. Shortened from 7 days to 24h so a malicious nuke can't deny delivery for
// a week (matches the message-queue TTL).
const nukeBlockTTL = 24 * time.Hour

// BlockQueue marks a queue as blocked (Nuked status).
func (r *RedisClient) BlockQueue(userID string) error {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		r.memoryBlocks[userID] = time.Now().Add(nukeBlockTTL)
		return nil
	}

	key := fmt.Sprintf("block:%s", userID)
	return r.rdb.Set(ctx, key, "1", nukeBlockTTL).Err()
}

// UnblockQueue clears the block status.
func (r *RedisClient) UnblockQueue(userID string) error {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		delete(r.memoryBlocks, userID)
		return nil
	}

	key := fmt.Sprintf("block:%s", userID)
	return r.rdb.Del(ctx, key).Err()
}

// IsQueueBlocked checks if a user's queue is blocked.
func (r *RedisClient) IsQueueBlocked(userID string) (bool, error) {
	if r.isMemory {
		r.mu.RLock()
		defer r.mu.RUnlock()
		expiry, exists := r.memoryBlocks[userID]
		if !exists {
			return false, nil
		}
		if expiry.Before(time.Now()) {
			return false, nil
		}
		return true, nil
	}

	key := fmt.Sprintf("block:%s", userID)
	val, err := r.rdb.Exists(ctx, key).Result()
	if err != nil {
		return false, err
	}
	return val > 0, nil
}

// StorePoWChallenge stores a transient PoW challenge string mapped to its difficulty.
func (r *RedisClient) StorePoWChallenge(challenge string, difficulty int) error {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		r.memoryPoW[challenge] = powChallenge{
			difficulty: difficulty,
			expires:    time.Now().Add(5 * time.Minute),
		}
		return nil
	}

	key := fmt.Sprintf("pow:challenge:%s", challenge)
	return r.rdb.Set(ctx, key, difficulty, 5*time.Minute).Err()
}

// GetPoWChallengeDifficulty retrieves and deletes the challenge if it exists.
func (r *RedisClient) GetPoWChallengeDifficulty(challenge string) (int, error) {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		val, exists := r.memoryPoW[challenge]
		if !exists || val.expires.Before(time.Now()) {
			return 0, fmt.Errorf("challenge expired or invalid")
		}
		delete(r.memoryPoW, challenge)
		return val.difficulty, nil
	}

	key := fmt.Sprintf("pow:challenge:%s", challenge)
	val, err := r.rdb.Get(ctx, key).Int()
	if err == redis.Nil {
		return 0, fmt.Errorf("challenge expired or invalid")
	} else if err != nil {
		return 0, err
	}
	// Delete challenge immediately to prevent reuse
	r.rdb.Del(ctx, key)
	return val, nil
}

// IsNonceUnique checks if a nonce is unique and flags it as used (prevents replay).
func (r *RedisClient) IsNonceUnique(nonce string) (bool, error) {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()

		now := time.Now()
		expiry, exists := r.memoryNonces[nonce]
		if exists && expiry.After(now) {
			return false, nil // Replay attack, not unique
		}

		r.memoryNonces[nonce] = now.Add(10 * time.Minute)
		return true, nil
	}

	key := fmt.Sprintf("pow:nonce:%s", nonce)
	// SET key 1 NX EX 600
	ok, err := r.rdb.SetNX(ctx, key, "1", 10*time.Minute).Result()
	if err != nil {
		return false, err
	}
	return ok, nil
}

// AllowNuke rate-limits NUKE_RECIPIENT per sender over a sliding 1h window, so a
// single client can't mass-block or loop-block queues. Returns false once the
// sender has issued more than `limit` nukes in the past hour.
func (r *RedisClient) AllowNuke(senderID string, limit int64) (bool, error) {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		now := time.Now()
		v, ok := r.memoryNukes[senderID]
		if !ok || v.expires.Before(now) {
			r.memoryNukes[senderID] = ipFail{count: 1, expires: now.Add(time.Hour)}
			return true, nil
		}
		if v.count >= limit {
			return false, nil
		}
		v.count++
		r.memoryNukes[senderID] = v
		return true, nil
	}

	key := fmt.Sprintf("nukerate:%s", senderID)
	pipe := r.rdb.TxPipeline()
	incr := pipe.Incr(ctx, key)
	pipe.Expire(ctx, key, time.Hour)
	if _, err := pipe.Exec(ctx); err != nil {
		return false, err
	}
	return incr.Val() <= limit, nil
}

// ConsumeVoucher atomically marks a voucher (keyed by its signature) as spent so a
// valid voucher can't be replayed to post unlimited messages. Returns false if the
// voucher was already used or is already expired. The marker lives until the
// voucher's own expiry. (Reuses the nonce set in memory mode — same "seen once"
// semantics.)
func (r *RedisClient) ConsumeVoucher(sig string, expiryUnix int64) (bool, error) {
	ttl := time.Until(time.Unix(expiryUnix, 0))
	if ttl <= 0 {
		return false, nil
	}
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		key := "voucher:" + sig
		now := time.Now()
		if exp, ok := r.memoryNonces[key]; ok && exp.After(now) {
			return false, nil
		}
		r.memoryNonces[key] = now.Add(ttl)
		return true, nil
	}

	key := fmt.Sprintf("voucher:used:%s", sig)
	ok, err := r.rdb.SetNX(ctx, key, "1", ttl).Result()
	if err != nil {
		return false, err
	}
	return ok, nil
}

// CheckIPBan returns true if the IP is currently banned.
func (r *RedisClient) CheckIPBan(ip string) (bool, error) {
	if r.isMemory {
		r.mu.RLock()
		defer r.mu.RUnlock()
		expiry, exists := r.memoryBans[ip]
		if !exists {
			return false, nil
		}
		if expiry.Before(time.Now()) {
			return false, nil
		}
		return true, nil
	}

	key := fmt.Sprintf("ban:%s", ip)
	exists, err := r.rdb.Exists(ctx, key).Result()
	if err != nil {
		return false, err
	}
	return exists > 0, nil
}

// BanIP sets a ban for an IP with a specific duration.
func (r *RedisClient) BanIP(ip string, duration time.Duration) error {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		r.memoryBans[ip] = time.Now().Add(duration)
		return nil
	}

	key := fmt.Sprintf("ban:%s", ip)
	return r.rdb.Set(ctx, key, "1", duration).Err()
}

// IncrementIPFailure logs a failed validation and returns the current total.
func (r *RedisClient) IncrementIPFailure(ip string) (int64, error) {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()

		now := time.Now()
		val, exists := r.memoryFails[ip]
		if !exists || val.expires.Before(now) {
			r.memoryFails[ip] = ipFail{
				count:   1,
				expires: now.Add(1 * time.Hour),
			}
			return 1, nil
		}

		val.count++
		r.memoryFails[ip] = val
		return val.count, nil
	}

	key := fmt.Sprintf("fail:%s", ip)
	pipe := r.rdb.TxPipeline()
	incr := pipe.Incr(ctx, key)
	pipe.Expire(ctx, key, 1*time.Hour)
	_, err := pipe.Exec(ctx)
	if err != nil {
		return 0, err
	}
	return incr.Val(), nil
}

// CheckIPRateLimit returns true if the request count in the current minute is within limits.
func (r *RedisClient) CheckIPRateLimit(ip string, limit int64) (bool, error) {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()

		minute := time.Now().Format("200601021504")
		key := fmt.Sprintf("rate:%s:%s", ip, minute)

		count := r.memoryRate[key]
		count++
		r.memoryRate[key] = count

		// Clean up old rate records to prevent memory leak
		for k := range r.memoryRate {
			// Extract timestamp part of k
			parts := len(k)
			if parts > 12 {
				kMin := k[parts-12:]
				if kMin != minute {
					delete(r.memoryRate, k)
				}
			}
		}

		return count <= limit, nil
	}

	minute := time.Now().Format("200601021504")
	key := fmt.Sprintf("rate:%s:%s", ip, minute)
	pipe := r.rdb.TxPipeline()
	incr := pipe.Incr(ctx, key)
	pipe.Expire(ctx, key, 60*time.Second)
	_, err := pipe.Exec(ctx)
	if err != nil {
		return false, err
	}
	return incr.Val() <= limit, nil
}

// StorePairing stores pairing data mapped to a PIN code.
func (r *RedisClient) StorePairing(pin string, data string, ttl time.Duration) error {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		r.memoryPairings[pin] = memoryPairing{
			data:    data,
			expires: time.Now().Add(ttl),
		}
		return nil
	}
	key := fmt.Sprintf("pair:%s", pin)
	return r.rdb.Set(ctx, key, data, ttl).Err()
}

// GetPairing retrieves pairing data by PIN.
func (r *RedisClient) GetPairing(pin string) (string, error) {
	if r.isMemory {
		r.mu.RLock()
		defer r.mu.RUnlock()
		p, exists := r.memoryPairings[pin]
		if !exists || p.expires.Before(time.Now()) {
			return "", fmt.Errorf("pairing expired or invalid")
		}
		return p.data, nil
	}
	key := fmt.Sprintf("pair:%s", pin)
	val, err := r.rdb.Get(ctx, key).Result()
	if err == redis.Nil {
		return "", fmt.Errorf("pairing expired or invalid")
	}
	return val, err
}

// DeletePairing deletes pairing data by PIN.
func (r *RedisClient) DeletePairing(pin string) error {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		delete(r.memoryPairings, pin)
		return nil
	}
	key := fmt.Sprintf("pair:%s", pin)
	return r.rdb.Del(ctx, key).Err()
}

// CreateTunnel registers a WebSocket ephemeral routing tunnel mapping between two keys.
func (r *RedisClient) CreateTunnel(pubkeyA string, pubkeyB string, ttl time.Duration) error {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		r.memoryTunnels[pubkeyA] = pubkeyB
		r.memoryTunnels[pubkeyB] = pubkeyA
		return nil
	}

	pipe := r.rdb.TxPipeline()
	pipe.Set(ctx, fmt.Sprintf("tunnel:%s", pubkeyA), pubkeyB, ttl)
	pipe.Set(ctx, fmt.Sprintf("tunnel:%s", pubkeyB), pubkeyA, ttl)
	_, err := pipe.Exec(ctx)
	return err
}

// GetTunnelPartner returns the routing partner for an ephemeral key.
func (r *RedisClient) GetTunnelPartner(pubkey string) (string, error) {
	if r.isMemory {
		r.mu.RLock()
		defer r.mu.RUnlock()
		partner, exists := r.memoryTunnels[pubkey]
		if !exists {
			return "", fmt.Errorf("tunnel not found")
		}
		return partner, nil
	}
	key := fmt.Sprintf("tunnel:%s", pubkey)
	val, err := r.rdb.Get(ctx, key).Result()
	if err == redis.Nil {
		return "", fmt.Errorf("tunnel not found")
	}
	return val, err
}

// IncrementTunnelBytes tracks total packet size routed.
func (r *RedisClient) IncrementTunnelBytes(tunnelID string, bytes int64) (int64, error) {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		r.memoryTunnelBytes[tunnelID] += bytes
		return r.memoryTunnelBytes[tunnelID], nil
	}
	key := fmt.Sprintf("tunnel_bytes:%s", tunnelID)
	pipe := r.rdb.TxPipeline()
	incr := pipe.IncrBy(ctx, key, bytes)
	pipe.Expire(ctx, key, 1*time.Hour)
	_, err := pipe.Exec(ctx)
	if err != nil {
		return 0, err
	}
	return incr.Val(), nil
}

// DeleteTunnel removes a websocket routing tunnel mapping.
func (r *RedisClient) DeleteTunnel(pubkeyA string, pubkeyB string) error {
	if r.isMemory {
		r.mu.Lock()
		defer r.mu.Unlock()
		delete(r.memoryTunnels, pubkeyA)
		delete(r.memoryTunnels, pubkeyB)
		delete(r.memoryTunnelBytes, pubkeyA+":"+pubkeyB)
		delete(r.memoryTunnelBytes, pubkeyB+":"+pubkeyA)
		return nil
	}

	pipe := r.rdb.TxPipeline()
	pipe.Del(ctx, fmt.Sprintf("tunnel:%s", pubkeyA))
	pipe.Del(ctx, fmt.Sprintf("tunnel:%s", pubkeyB))
	pipe.Del(ctx, fmt.Sprintf("tunnel_bytes:%s:%s", pubkeyA, pubkeyB))
	pipe.Del(ctx, fmt.Sprintf("tunnel_bytes:%s:%s", pubkeyB, pubkeyA))
	_, err := pipe.Exec(ctx)
	return err
}
