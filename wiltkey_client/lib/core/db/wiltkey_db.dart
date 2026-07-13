import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models.dart';
import '../persistence.dart';

class WiltkeyDatabase {
  static final WiltkeyDatabase instance = WiltkeyDatabase._();
  WiltkeyDatabase._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    await init();
    return _db!;
  }

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'wiltkey.db');
    _db = await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v2: archived chats keep their (master-key encrypted) messages but drop the
    // OTP pad to save space; flagged read-only via is_archived.
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE contacts ADD COLUMN is_archived INTEGER DEFAULT 0',
      );
    }
    // v3: user-pinned chats float to the top of the list.
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE contacts ADD COLUMN is_pinned INTEGER DEFAULT 0',
      );
    }
    // v4: index for windowed message loading + unread counts (paging and the
    // per-chat COUNT both filter by chat_id and order/range by timestamp).
    if (oldVersion < 4) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_chat_time ON messages(chat_id, timestamp)',
      );
    }
    // v5: persist failed-send state so an abandoned failed message can be
    // auto-refunded on next launch (see autoRefundAbandonedFailures).
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE messages ADD COLUMN is_failed INTEGER DEFAULT 0',
      );
    }
    // v6: emoji reactions — mutable side-metadata synced over the AES meta
    // channel (not the OTP pad). JSON: {token: [reactorId, ...]}. Low-sensitivity
    // (emoji + already-known key hashes), so stored plaintext for cheap in-place
    // updates, unlike the master-encrypted message body.
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE messages ADD COLUMN reactions TEXT');
    }
    // v7: per-image sender opt-in to let the recipient save/download it. Rides as
    // frame metadata, not in the OTP body. Legacy rows default 0 (non-downloadable).
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE messages ADD COLUMN allow_save INTEGER DEFAULT 0',
      );
    }
    // v8: wilting (disappearing) messages. `ephemeral`/`ttl_seconds` are the
    // sender's config (ride the OTP envelope as eph/ttl); `opened_at`/`expires_at`
    // are recipient-local timing set on first reveal; `wilted` marks a destroyed
    // row (its text_otp/text_encrypted_master are blanked in place); `wilted_by`
    // is the sender-side confirmation set (JSON list of reactor ids), synced over
    // the AES meta channel like reactions. Legacy rows default to non-ephemeral.
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE messages ADD COLUMN ephemeral INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE messages ADD COLUMN ttl_seconds INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE messages ADD COLUMN opened_at INTEGER');
      await db.execute('ALTER TABLE messages ADD COLUMN expires_at INTEGER');
      await db.execute(
        'ALTER TABLE messages ADD COLUMN wilted INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE messages ADD COLUMN wilted_by TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Group info
    await db.execute('''
      CREATE TABLE group_info (
        group_id TEXT PRIMARY KEY,
        group_name TEXT,
        group_icon TEXT,
        lane_size INTEGER,
        max_members INTEGER,
        total_size INTEGER,
        group_seed_encrypted TEXT,
        info_lane_write_offset INTEGER DEFAULT 0,
        is_host INTEGER DEFAULT 0,
        host_key_hash TEXT
      )
    ''');

    // 2. Group lanes
    await db.execute('''
      CREATE TABLE group_lanes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id TEXT,
        slot_index INTEGER,
        member_key_hash TEXT,
        start_offset INTEGER,
        max_offset INTEGER,
        current_write_offset INTEGER DEFAULT 0,
        header_written INTEGER DEFAULT 0,
        UNIQUE(group_id, slot_index),
        FOREIGN KEY (group_id) REFERENCES group_info(group_id) ON DELETE CASCADE
      )
    ''');

    // 3. Group profiles
    await db.execute('''
      CREATE TABLE group_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id TEXT,
        member_key_hash TEXT,
        name TEXT,
        profile_image TEXT,
        arrival_order INTEGER,
        permissions TEXT DEFAULT '',
        UNIQUE(group_id, member_key_hash),
        FOREIGN KEY (group_id) REFERENCES group_info(group_id) ON DELETE CASCADE
      )
    ''');

    // 4. Contacts (Unified for 1-on-1 and Group chats)
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT,
        key_hash TEXT UNIQUE,
        relay_url TEXT,
        is_private_node INTEGER,
        max_buffer_bytes INTEGER,
        remaining_buffer_bytes INTEGER,
        peer_remaining_buffer_bytes INTEGER,
        last_activity TEXT,
        is_wilted INTEGER,
        is_archived INTEGER DEFAULT 0,
        is_pinned INTEGER DEFAULT 0,
        is_group INTEGER,
        member_count INTEGER,
        host_name TEXT,
        is_host INTEGER,
        host_key_hash TEXT,
        member_key_hashes TEXT,
        group_icon_hex TEXT,
        max_members INTEGER,
        max_message_size INTEGER,
        images_allowed INTEGER,
        joined_at TEXT,
        short_nick TEXT,
        profile_image_b64 TEXT,
        outgoing_offset INTEGER,
        outgoing_max_offset INTEGER,
        incoming_offset INTEGER,
        incoming_max_offset INTEGER,
        group_seed TEXT,
        lane_size INTEGER,
        total_group_size INTEGER,
        slot_index INTEGER,
        additional_slots TEXT
      )
    ''');

    // 5. Messages (Unified for 1-on-1 and Group chats)
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT,
        sender_id TEXT,
        text_otp TEXT,
        content_type TEXT,
        timestamp TEXT,
        is_sent_by_me INTEGER,
        offset INTEGER,
        is_delivered INTEGER,
        text_encrypted_master TEXT,
        is_failed INTEGER DEFAULT 0,
        reactions TEXT,
        allow_save INTEGER DEFAULT 0,
        ephemeral INTEGER DEFAULT 0,
        ttl_seconds INTEGER DEFAULT 0,
        opened_at INTEGER,
        expires_at INTEGER,
        wilted INTEGER DEFAULT 0,
        wilted_by TEXT
      )
    ''');
    // Speeds windowed paging (chat_id + timestamp ORDER/LIMIT) and unread counts.
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_chat_time ON messages(chat_id, timestamp)',
    );
  }

  // ---------------------------------------------------------------------------
  // Contacts CRUD
  // ---------------------------------------------------------------------------

  Future<void> upsertContact(Contact contact) async {
    final db = await _database;
    await db.insert('contacts', {
      'id': contact.id,
      'name': contact.name,
      'key_hash': contact.keyHash,
      'relay_url': contact.relayUrl,
      'is_private_node': contact.isPrivateNode ? 1 : 0,
      'max_buffer_bytes': contact.maxBufferBytes,
      'remaining_buffer_bytes': contact.remainingBufferBytes,
      'peer_remaining_buffer_bytes': contact.peerRemainingBufferBytes,
      'last_activity': contact.lastActivity.toIso8601String(),
      'is_wilted': contact.isWilted ? 1 : 0,
      'is_archived': contact.isArchived ? 1 : 0,
      'is_pinned': contact.isPinned ? 1 : 0,
      'is_group': contact.isGroup ? 1 : 0,
      'member_count': contact.memberCount,
      'host_name': contact.hostName,
      'is_host': contact.isHost ? 1 : 0,
      'host_key_hash': contact.hostKeyHash,
      'member_key_hashes': jsonEncode(contact.memberKeyHashes),
      'group_icon_hex': contact.groupIconHex,
      'max_members': contact.maxMembers,
      'max_message_size': contact.maxMessageSize,
      'images_allowed': contact.imagesAllowed != null
          ? (contact.imagesAllowed! ? 1 : 0)
          : null,
      'joined_at': contact.joinedAt?.toIso8601String(),
      'short_nick': contact.shortNick,
      'profile_image_b64': contact.profileImageB64,
      'outgoing_offset': contact.outgoingOffset,
      'outgoing_max_offset': contact.outgoingMaxOffset,
      'incoming_offset': contact.incomingOffset,
      'incoming_max_offset': contact.incomingMaxOffset,
      'group_seed': contact.groupSeed,
      'lane_size': contact.laneSize,
      'total_group_size': contact.totalGroupSize,
      'slot_index': contact.slotIndex,
      'additional_slots': jsonEncode(contact.additionalSlots),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Contact>> getAllContacts() async {
    final db = await _database;
    final rows = await db.query('contacts', orderBy: 'last_activity DESC');
    return rows.map((row) {
      final imagesAllowedVal = row['images_allowed'] as int?;
      return Contact(
        id: row['id'] as String,
        name: row['name'] as String,
        keyHash: row['key_hash'] as String,
        relayUrl: row['relay_url'] as String,
        isPrivateNode: (row['is_private_node'] as int) == 1,
        maxBufferBytes: row['max_buffer_bytes'] as int,
        remainingBufferBytes: row['remaining_buffer_bytes'] as int,
        peerRemainingBufferBytes: row['peer_remaining_buffer_bytes'] as int,
        lastActivity: DateTime.parse(row['last_activity'] as String),
        isWilted: (row['is_wilted'] as int) == 1,
        isArchived: (row['is_archived'] as int? ?? 0) == 1,
        isPinned: (row['is_pinned'] as int? ?? 0) == 1,
        isGroup: (row['is_group'] as int) == 1,
        memberCount: row['member_count'] as int?,
        hostName: row['host_name'] as String?,
        isHost: (row['is_host'] as int) == 1,
        hostKeyHash: row['host_key_hash'] as String?,
        memberKeyHashes:
            (jsonDecode(row['member_key_hashes'] as String? ?? '[]')
                    as List<dynamic>)
                .cast<String>(),
        groupIconHex: row['group_icon_hex'] as String?,
        maxMembers: row['max_members'] as int?,
        maxMessageSize: row['max_message_size'] as int?,
        imagesAllowed: imagesAllowedVal != null ? imagesAllowedVal == 1 : null,
        joinedAt: row['joined_at'] != null
            ? DateTime.parse(row['joined_at'] as String)
            : null,
        shortNick: row['short_nick'] as String?,
        profileImageB64: row['profile_image_b64'] as String?,
        outgoingOffset: row['outgoing_offset'] as int? ?? 0,
        outgoingMaxOffset: row['outgoing_max_offset'] as int? ?? 0,
        incomingOffset: row['incoming_offset'] as int? ?? 0,
        incomingMaxOffset: row['incoming_max_offset'] as int? ?? 0,
        groupSeed: row['group_seed'] as String?,
        laneSize: row['lane_size'] as int?,
        totalGroupSize: row['total_group_size'] as int?,
        slotIndex: row['slot_index'] as int?,
        additionalSlots:
            (jsonDecode(row['additional_slots'] as String? ?? '[]')
                    as List<dynamic>)
                .cast<int>(),
      );
    }).toList();
  }

  Future<void> deleteContactRecord(String chatId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
      await txn.delete('contacts', where: 'id = ?', whereArgs: [chatId]);
    });
  }

  // ---------------------------------------------------------------------------
  // Messages CRUD
  // ---------------------------------------------------------------------------

  Future<void> saveMessage(
    ChatMessage msg,
    String chatId, {
    String? masterKeyHex,
  }) async {
    final db = await _database;
    String? textEncryptedMaster;

    if (masterKeyHex != null &&
        msg.decryptedText != null &&
        msg.senderId != 'system') {
      textEncryptedMaster = WiltkeyPersistence().encryptString(
        msg.decryptedText!,
        masterKeyHex,
      );
    }

    // Reactions ride a separate sync channel (not this row's write-once body).
    // A re-save of an existing message (resync / duplicate redelivery) carries no
    // in-memory reactions, and INSERT OR REPLACE would wipe any already stored —
    // so preserve the persisted set when the incoming message has none.
    String? reactionsJson = msg.reactionsJson;
    if (reactionsJson == null) {
      final existing = await db.query(
        'messages',
        columns: ['reactions'],
        where: 'id = ?',
        whereArgs: [msg.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        reactionsJson = existing.first['reactions'] as String?;
      }
    }

    // Wilt state is likewise side-metadata: never let a re-save (resync / late
    // redelivery of the original frame) resurrect a row that has already wilted,
    // and preserve the accumulated `wilted_by` confirmation set when the incoming
    // copy carries none.
    bool wilted = msg.wilted;
    String? wiltedByJson = msg.wiltedBy.isEmpty
        ? null
        : jsonEncode(msg.wiltedBy.toList());
    final priorWilt = await db.query(
      'messages',
      columns: ['wilted', 'wilted_by'],
      where: 'id = ?',
      whereArgs: [msg.id],
      limit: 1,
    );
    if (priorWilt.isNotEmpty) {
      if ((priorWilt.first['wilted'] as int? ?? 0) == 1) wilted = true;
      wiltedByJson ??= priorWilt.first['wilted_by'] as String?;
    }

    await db.insert('messages', {
      'id': msg.id,
      'chat_id': chatId,
      'sender_id': msg.senderId,
      // A wilted row keeps NO recoverable body — blank both ciphertext copies.
      'text_otp': wilted ? '' : msg.text,
      'content_type': msg.contentType,
      'timestamp': msg.timestamp.toIso8601String(),
      'is_sent_by_me': msg.isSentByMe ? 1 : 0,
      'offset': wilted ? -1 : msg.offset,
      'is_delivered': msg.isDelivered ? 1 : 0,
      'text_encrypted_master': wilted ? null : textEncryptedMaster,
      'is_failed': msg.isFailed ? 1 : 0,
      'reactions': reactionsJson,
      'allow_save': msg.allowSave ? 1 : 0,
      'ephemeral': msg.ephemeral ? 1 : 0,
      'ttl_seconds': msg.ttlSeconds,
      'opened_at': msg.openedAt,
      'expires_at': msg.expiresAt,
      'wilted': wilted ? 1 : 0,
      'wilted_by': wiltedByJson,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Read-modify-write a single reaction on a stored message. Best-effort: if the
  /// target message isn't stored yet (a reaction can outrun its message under
  /// store-and-forward), returns null (no-op). Otherwise returns the message's
  /// full reaction map after the change so callers can refresh the in-memory copy
  /// without a second read.
  Future<Map<String, Set<String>>?> mutateMessageReaction(
    String messageId, {
    required String token,
    required String reactorId,
    required bool add,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      columns: ['reactions'],
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final current = ChatMessage.decodeReactions(rows.first['reactions'] as String?);
    final set = current.putIfAbsent(token, () => <String>{});
    if (add) {
      set.add(reactorId);
    } else {
      set.remove(reactorId);
      if (set.isEmpty) current.remove(token);
    }
    await db.update(
      'messages',
      {'reactions': ChatMessage.encodeReactions(current)},
      where: 'id = ?',
      whereArgs: [messageId],
    );
    return current;
  }

  // ---------------------------------------------------------------------------
  // Wilting (disappearing) messages
  // ---------------------------------------------------------------------------

  /// Destroy a wilting message's body in place: blank both ciphertext copies,
  /// scramble the pad offset, and flag it wilted. Irreversible — after this the
  /// row holds no recoverable plaintext even if the OTP pad is retained.
  Future<void> wiltMessageRow(String messageId) async {
    final db = await _database;
    await db.update(
      'messages',
      {
        'text_otp': '',
        'text_encrypted_master': null,
        'offset': -1,
        'wilted': 1,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Record the instant a recipient first revealed a wilting message and when it
  /// will wilt. Idempotent-ish: only writes when `opened_at` is still null so a
  /// re-reveal can't restart the countdown.
  Future<void> markMessageOpened(
    String messageId,
    int openedAtMs,
    int expiresAtMs,
  ) async {
    final db = await _database;
    await db.update(
      'messages',
      {'opened_at': openedAtMs, 'expires_at': expiresAtMs},
      where: 'id = ? AND opened_at IS NULL',
      whereArgs: [messageId],
    );
  }

  /// Read-modify-write the sender-side `wilted_by` confirmation set. Returns the
  /// updated set, or null if the target message isn't stored (a confirmation can
  /// outrun store-and-forward). Mirrors [mutateMessageReaction].
  Future<Set<String>?> addWiltedBy(String messageId, String reactorId) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      columns: ['wilted_by'],
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final set = _decodeWiltedBy(rows.first['wilted_by'] as String?)..add(reactorId);
    await db.update(
      'messages',
      {'wilted_by': jsonEncode(set.toList())},
      where: 'id = ?',
      whereArgs: [messageId],
    );
    return set;
  }

  /// Resolve a stored screenshot-request card: overwrite its control payload and
  /// clear the ephemeral/expiry bookkeeping so the wilt sweep won't later flip a
  /// now-answered card into "expired".
  Future<void> resolveControlMessageRow(String id, String newTextOtp) async {
    final db = await _database;
    await db.update(
      'messages',
      {'text_otp': newTextOtp, 'ephemeral': 0, 'expires_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Whether a message is an ephemeral one we *received* (not authored) — used to
  /// decide whether wilting it should emit a `wilt_done` confirmation to the
  /// sender. Returns false if the row is gone. Safe to call after the body has
  /// been blanked (is_sent_by_me / ephemeral survive wilting).
  Future<bool> isReceivedEphemeral(String messageId) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      columns: ['ephemeral', 'is_sent_by_me', 'content_type'],
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    // Control cards (e.g. screenshot_request) are ephemeral for expiry but must
    // NOT emit a wilt confirmation to a peer — only real message content does.
    if (rows.first['content_type'] == 'screenshot_request') return false;
    return (rows.first['ephemeral'] as int? ?? 0) == 1 &&
        (rows.first['is_sent_by_me'] as int? ?? 0) == 0;
  }

  /// All not-yet-wilted ephemeral messages, for the start-up / resume sweep:
  /// returns `id`, `chat_id` and `expires_at` (null while unopened). Callers wilt
  /// the already-expired ones and arm timers for the rest.
  Future<List<({String id, String chatId, int? expiresAt})>>
  getPendingWiltMessages() async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      columns: ['id', 'chat_id', 'expires_at'],
      where: 'ephemeral = 1 AND wilted = 0',
    );
    return rows
        .map(
          (r) => (
            id: r['id'] as String,
            chatId: r['chat_id'] as String,
            expiresAt: r['expires_at'] as int?,
          ),
        )
        .toList();
  }

  /// Decodes a raw `messages` row into a [ChatMessage], decrypting the body from
  /// the master-key copy when [masterKeyHex] is given (system lines store
  /// plaintext in text_otp). Pass a null key to skip decryption — fine for
  /// resync forwarding, which only needs the OTP ciphertext + metadata.
  ChatMessage _rowToMessage(Map<String, Object?> row, {String? masterKeyHex}) {
    final senderId = row['sender_id'] as String;
    final textOtp = row['text_otp'] as String;
    final textEncryptedMaster = row['text_encrypted_master'] as String?;
    final contentType = row['content_type'] as String;
    final wilted = (row['wilted'] as int? ?? 0) == 1;

    String? decryptedText;
    if (wilted) {
      // Destroyed content — nothing to decrypt or decode.
    } else if (senderId == 'system') {
      decryptedText = textOtp;
    } else if (textEncryptedMaster != null && masterKeyHex != null) {
      try {
        decryptedText = WiltkeyPersistence().decryptString(
          textEncryptedMaster,
          masterKeyHex,
        );
      } catch (e) {
        print('[DB Error] Failed to decrypt message from Master Key: $e');
      }
    }

    return ChatMessage(
      id: row['id'] as String,
      senderId: senderId,
      text: textOtp,
      contentType: contentType,
      timestamp: DateTime.parse(row['timestamp'] as String),
      isSentByMe: (row['is_sent_by_me'] as int) == 1,
      offset: row['offset'] as int,
      isDelivered: (row['is_delivered'] as int) == 1,
      isFailed: (row['is_failed'] as int? ?? 0) == 1,
      allowSave: (row['allow_save'] as int? ?? 0) == 1,
      decryptedText: decryptedText,
      decodedImageBytes: (contentType == 'image' && decryptedText != null)
          ? base64Decode(decryptedText)
          : null,
      reactions: ChatMessage.decodeReactions(row['reactions'] as String?),
      ephemeral: (row['ephemeral'] as int? ?? 0) == 1,
      ttlSeconds: row['ttl_seconds'] as int? ?? 0,
      openedAt: row['opened_at'] as int?,
      expiresAt: row['expires_at'] as int?,
      wilted: wilted,
      wiltedBy: _decodeWiltedBy(row['wilted_by'] as String?),
    );
  }

  /// Decodes the JSON list stored in `wilted_by` (peers who confirmed wilt).
  static Set<String> _decodeWiltedBy(String? s) {
    if (s == null || s.isEmpty) return {};
    try {
      return {...(jsonDecode(s) as List).map((e) => e.toString())};
    } catch (_) {
      return {};
    }
  }

  /// Loads a page of a chat's messages, newest-first window returned in ASC
  /// (chat) order. With [beforeTimestamp] (ISO8601) returns the page strictly
  /// older than it — for scroll-back pagination.
  Future<List<ChatMessage>> getMessagesPage(
    String chatId, {
    required int limit,
    String? beforeTimestamp,
    String? masterKeyHex,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: beforeTimestamp == null
          ? 'chat_id = ?'
          : 'chat_id = ? AND timestamp < ?',
      whereArgs: beforeTimestamp == null ? [chatId] : [chatId, beforeTimestamp],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    // Query is newest-first; reverse to chronological for display.
    final out = [
      for (final r in rows.reversed)
        _rowToMessage(r, masterKeyHex: masterKeyHex),
    ];
    return out;
  }

  /// Whether the chat already has a message with [id], or (when [offset] is
  /// given and not a system line) one at that keystream offset. Used to dedup
  /// resync/offline-replay without holding the whole history in memory.
  Future<bool> messageExists(
    String chatId, {
    required String id,
    int? offset,
  }) async {
    final db = await _database;
    final byId = await db.query(
      'messages',
      columns: ['id'],
      where: 'chat_id = ? AND id = ?',
      whereArgs: [chatId, id],
      limit: 1,
    );
    if (byId.isNotEmpty) return true;
    if (offset != null) {
      final byOffset = await db.query(
        'messages',
        columns: ['id'],
        where: "chat_id = ? AND offset = ? AND sender_id != 'system'",
        whereArgs: [chatId, offset],
        limit: 1,
      );
      if (byOffset.isNotEmpty) return true;
    }
    return false;
  }

  /// Non-system messages in [startOffset, endOffset) for a chat — the source for
  /// answering a peer's resync request. No decryption (forwards OTP ciphertext).
  Future<List<ChatMessage>> getMessagesInOffsetRange(
    String chatId,
    int startOffset,
    int endOffset,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where:
          "chat_id = ? AND sender_id != 'system' AND offset >= ? AND offset < ?",
      whereArgs: [chatId, startOffset, endOffset],
      orderBy: 'timestamp ASC',
    );
    return [for (final r in rows) _rowToMessage(r)];
  }

  /// Failed-send messages for a chat (master-key decrypted when [masterKeyHex]
  /// is given). Source for the launch-time abandoned-failure refund sweep.
  Future<List<ChatMessage>> getFailedMessages(
    String chatId, {
    String? masterKeyHex,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: 'chat_id = ? AND is_failed = 1',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return [for (final r in rows) _rowToMessage(r, masterKeyHex: masterKeyHex)];
  }

  /// Messages that exist ONLY as OTP ciphertext (no master-key copy) — the ones
  /// archive must decrypt with the still-present pad before it's dropped.
  Future<List<ChatMessage>> getOtpOnlyMessages(String chatId) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where:
          "chat_id = ? AND sender_id != 'system' AND text_encrypted_master IS NULL",
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return [for (final r in rows) _rowToMessage(r)];
  }

  /// Per-chat count of inbound, user-visible messages newer than each chat's
  /// last-read time (ms since epoch). Drives the unread badge without loading
  /// message bodies. Chats absent from [lastReadMs] count from 0.
  Future<Map<String, int>> getUnreadCounts(
    Map<String, int> lastReadMs,
    List<String> chatIds,
  ) async {
    final db = await _database;
    final Map<String, int> out = {};
    for (final chatId in chatIds) {
      final lastIso = DateTime.fromMillisecondsSinceEpoch(
        lastReadMs[chatId] ?? 0,
      ).toIso8601String();
      final res = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM messages WHERE chat_id = ? AND is_sent_by_me = 0 "
        "AND sender_id != 'system' AND content_type NOT IN ('emoji_def','emoji_delete') "
        "AND timestamp > ?",
        [chatId, lastIso],
      );
      final c = Sqflite.firstIntValue(res) ?? 0;
      if (c > 0) out[chatId] = c;
    }
    return out;
  }

  Future<void> updateMessageDelivered(
    String messageId,
    bool isDelivered,
  ) async {
    final db = await _database;
    await db.update(
      'messages',
      {'is_delivered': isDelivered ? 1 : 0},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Undelivered outbound messages for a chat (sent by me, not yet acked, not in
  /// a failed state) — the source list for the 1-on-1 delivery reconciliation
  /// sync. Forwards OTP ciphertext (no master decryption needed) so the rows can
  /// also be re-sent verbatim if the peer reports them missing.
  Future<List<ChatMessage>> getUndeliveredSentMessages(String chatId) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where:
          "chat_id = ? AND is_sent_by_me = 1 AND is_delivered = 0 AND is_failed = 0 AND sender_id != 'system'",
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return [for (final r in rows) _rowToMessage(r)];
  }

  /// Flags every outbound message at [offset] as delivered — used by the
  /// delivery-check reconciliation to ack rows that may not be in the loaded
  /// window (so we can't address them by id).
  Future<void> markSentDeliveredByOffset(String chatId, int offset) async {
    final db = await _database;
    await db.update(
      'messages',
      {'is_delivered': 1},
      where:
          "chat_id = ? AND offset = ? AND is_sent_by_me = 1 AND sender_id != 'system'",
      whereArgs: [chatId, offset],
    );
  }

  Future<void> deleteMessagesForChat(String chatId) async {
    final db = await _database;
    await db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
  }

  Future<void> deleteMessage(String id) async {
    final db = await _database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Group Info CRUD
  // ---------------------------------------------------------------------------

  Future<void> upsertGroupInfo({
    required String groupId,
    required String groupName,
    required String groupIcon,
    required int laneSize,
    required int maxMembers,
    required int totalSize,
    required String groupSeedEncrypted,
    int infoLaneWriteOffset = 0,
    bool isHost = false,
    String? hostKeyHash,
  }) async {
    final db = await _database;
    await db.insert('group_info', {
      'group_id': groupId,
      'group_name': groupName,
      'group_icon': groupIcon,
      'lane_size': laneSize,
      'max_members': maxMembers,
      'total_size': totalSize,
      'group_seed_encrypted': groupSeedEncrypted,
      'info_lane_write_offset': infoLaneWriteOffset,
      'is_host': isHost ? 1 : 0,
      'host_key_hash': hostKeyHash,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getGroupInfo(String groupId) async {
    final db = await _database;
    final rows = await db.query(
      'group_info',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllGroups() async {
    final db = await _database;
    return db.query('group_info');
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(
        'group_profiles',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      await txn.delete(
        'group_lanes',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      await txn.delete(
        'group_info',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      // Also delete from contacts/messages if they exist there
      await txn.delete(
        'messages',
        where: 'chat_id = (SELECT id FROM contacts WHERE key_hash = ?)',
        whereArgs: [groupId],
      );
      await txn.delete('contacts', where: 'key_hash = ?', whereArgs: [groupId]);
    });
  }

  // ---------------------------------------------------------------------------
  // Lane CRUD
  // ---------------------------------------------------------------------------

  Future<void> upsertLane({
    required String groupId,
    required int slotIndex,
    String? memberKeyHash,
    required int startOffset,
    required int maxOffset,
    int currentWriteOffset = 0,
    bool headerWritten = false,
  }) async {
    final db = await _database;
    await db.insert('group_lanes', {
      'group_id': groupId,
      'slot_index': slotIndex,
      'member_key_hash': memberKeyHash,
      'start_offset': startOffset,
      'max_offset': maxOffset,
      'current_write_offset': currentWriteOffset,
      'header_written': headerWritten ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getLane(String groupId, int slotIndex) async {
    final db = await _database;
    final rows = await db.query(
      'group_lanes',
      where: 'group_id = ? AND slot_index = ?',
      whereArgs: [groupId, slotIndex],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getLaneByMember(
    String groupId,
    String memberKeyHash,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'group_lanes',
      where: 'group_id = ? AND member_key_hash = ?',
      whereArgs: [groupId, memberKeyHash],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllLanes(String groupId) async {
    final db = await _database;
    return db.query(
      'group_lanes',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'slot_index ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getEmptyLanes(String groupId) async {
    final db = await _database;
    return db.query(
      'group_lanes',
      where: 'group_id = ? AND member_key_hash IS NULL',
      whereArgs: [groupId],
      orderBy: 'slot_index ASC',
    );
  }

  Future<void> updateLaneWriteOffset(
    String groupId,
    int slotIndex,
    int newOffset,
  ) async {
    final db = await _database;
    await db.update(
      'group_lanes',
      {'current_write_offset': newOffset},
      where: 'group_id = ? AND slot_index = ?',
      whereArgs: [groupId, slotIndex],
    );
  }

  Future<void> assignLaneToMember(
    String groupId,
    int slotIndex,
    String memberKeyHash,
  ) async {
    final db = await _database;
    await db.update(
      'group_lanes',
      {'member_key_hash': memberKeyHash},
      where: 'group_id = ? AND slot_index = ?',
      whereArgs: [groupId, slotIndex],
    );
  }

  Future<void> freeLane(String groupId, int slotIndex) async {
    final db = await _database;
    await db.update(
      'group_lanes',
      {'member_key_hash': null, 'current_write_offset': 0, 'header_written': 0},
      where: 'group_id = ? AND slot_index = ?',
      whereArgs: [groupId, slotIndex],
    );
  }

  Future<int> getUsedSlotCount(String groupId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM group_lanes WHERE group_id = ? AND member_key_hash IS NOT NULL',
      [groupId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalSlotCount(String groupId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM group_lanes WHERE group_id = ?',
      [groupId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Profile CRUD
  // ---------------------------------------------------------------------------

  Future<void> upsertProfile({
    required String groupId,
    required String memberKeyHash,
    required String name,
    required String profileImage,
    required int arrivalOrder,
  }) async {
    final db = await _database;
    await db.insert('group_profiles', {
      'group_id': groupId,
      'member_key_hash': memberKeyHash,
      'name': name,
      'profile_image': profileImage,
      'arrival_order': arrivalOrder,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getProfile(
    String groupId,
    String memberKeyHash,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'group_profiles',
      where: 'group_id = ? AND member_key_hash = ?',
      whereArgs: [groupId, memberKeyHash],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllProfiles(String groupId) async {
    final db = await _database;
    return db.query(
      'group_profiles',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'arrival_order ASC',
    );
  }

  Future<void> deleteProfile(String groupId, String memberKeyHash) async {
    final db = await _database;
    await db.delete(
      'group_profiles',
      where: 'group_id = ? AND member_key_hash = ?',
      whereArgs: [groupId, memberKeyHash],
    );
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> deleteAll() async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('group_profiles');
      await txn.delete('group_lanes');
      await txn.delete('group_info');
      await txn.delete('messages');
      await txn.delete('contacts');
    });
  }

  Future<void> closeDb() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<void> deleteDbFile() async {
    await closeDb();
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'wiltkey.db');
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      print('[DB] Deleted SQLite database file wiltkey.db');
    }
  }
}

class GroupDatabase {
  static WiltkeyDatabase get instance => WiltkeyDatabase.instance;
}
