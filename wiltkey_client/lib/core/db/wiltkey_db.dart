import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models.dart';
import '../persistence.dart';

class WiltkeyDatabase {
  static final WiltkeyDatabase instance = WiltkeyDatabase._();
  WiltkeyDatabase._();

  Database? _db;

  /// Absolute path to the sidecar directory where large message bodies live as
  /// files instead of inline in the `messages` row. Set during [init].
  String? _mediaDir;

  /// A message body (base64 ciphertext or master-encrypted copy) at/above this
  /// many chars is written to a file rather than stored inline. Android's SQLite
  /// reads query results through a ~2 MB-per-row CursorWindow; a row larger than
  /// that throws `SQLiteBlobTooBigException` and — because the page query covers
  /// the whole chat — blanks the ENTIRE chat on load. Each image stored ~3× its
  /// bytes inline (OTP ciphertext + master copy), so anything past a few hundred
  /// KB is offloaded to keep every row comfortably inside the window.
  static const int kInlineBodyLimit = 256 * 1024;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    await init();
    return _db!;
  }

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'wiltkey.db');
    // Sidecar dir for offloaded large bodies. Kept next to the DB so it shares
    // the app's private storage and is wiped by the same clear-all.
    _mediaDir = p.join(dbPath, 'media');
    try {
      await Directory(_mediaDir!).create(recursive: true);
    } catch (_) {}
    _db = await openDatabase(
      path,
      version: 26,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _safeAddColumn(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      final exists = info.any((col) => col['name'] == column);
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
      }
    } catch (_) {
      // Fallback: ignore if already present or if table is created with latest schema
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v2: archived chats keep their (master-key encrypted) messages but drop the
    // OTP pad to save space; flagged read-only via is_archived.
    if (oldVersion < 2) {
      await _safeAddColumn(db, 'contacts', 'is_archived', 'INTEGER DEFAULT 0');
    }
    // v3: user-pinned chats float to the top of the list.
    if (oldVersion < 3) {
      await _safeAddColumn(db, 'contacts', 'is_pinned', 'INTEGER DEFAULT 0');
    }
    // v4: index for windowed message loading + unread counts.
    if (oldVersion < 4) {
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_messages_chat_time ON messages(chat_id, timestamp)',
        );
      } catch (_) {}
    }
    // v5: persist failed-send state so an abandoned failed message can be auto-refunded.
    if (oldVersion < 5) {
      await _safeAddColumn(db, 'messages', 'is_failed', 'INTEGER DEFAULT 0');
    }
    // v6: emoji reactions.
    if (oldVersion < 6) {
      await _safeAddColumn(db, 'messages', 'reactions', 'TEXT');
    }
    // v7: allow_save for image downloads.
    if (oldVersion < 7) {
      await _safeAddColumn(db, 'messages', 'allow_save', 'INTEGER DEFAULT 0');
    }
    // v8: wilting (disappearing) messages.
    if (oldVersion < 8) {
      await _safeAddColumn(db, 'messages', 'ephemeral', 'INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'messages', 'ttl_seconds', 'INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'messages', 'opened_at', 'INTEGER');
      await _safeAddColumn(db, 'messages', 'expires_at', 'INTEGER');
      await _safeAddColumn(db, 'messages', 'wilted', 'INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'messages', 'wilted_by', 'TEXT');
    }
    // v9: reply-to.
    if (oldVersion < 9) {
      await _safeAddColumn(db, 'messages', 'reply_to_id', 'TEXT');
    }
    // v10: avatar border on contacts.
    if (oldVersion < 10) {
      await _safeAddColumn(db, 'contacts', 'avatar_border', 'TEXT');
    }
    // v11: avatar border on group profiles.
    if (oldVersion < 11) {
      await _safeAddColumn(db, 'group_profiles', 'avatar_border', 'TEXT');
    }
    // v12: large message bodies sidecar path.
    if (oldVersion < 12) {
      await _safeAddColumn(db, 'messages', 'media_path', 'TEXT');
    }
    // v13: pending large-file downloads.
    if (oldVersion < 13) {
      await _safeAddColumn(db, 'messages', 'remote_file_id', 'TEXT');
      await _safeAddColumn(db, 'messages', 'remote_size', 'INTEGER DEFAULT 0');
    }

    // v14: Time Wilt chats.
    if (oldVersion < 14) {
      await _safeAddColumn(db, 'contacts', 'wilt_expires_at', 'INTEGER');
      await _safeAddColumn(db, 'contacts', 'stream_seed', 'TEXT');
      await _safeAddColumn(db, 'contacts', 'wilt_created_at', 'INTEGER');
    }

    // v15: group recharge pending.
    if (oldVersion < 15) {
      await _safeAddColumn(db, 'contacts', 'group_recharge_pending', 'INTEGER DEFAULT 0');
    }

    // v16: activity-feed event log.
    if (oldVersion < 16) {
      try {
        await db.execute(_createEventsTableSql);
      } catch (_) {}
    }

    // v17: group Time Wilt lifetime.
    if (oldVersion < 17) {
      await _safeAddColumn(db, 'contacts', 'group_wilt_lifetime_secs', 'INTEGER');
    }

    // v18: per-member Time Wilt expiry.
    if (oldVersion < 18) {
      await _safeAddColumn(db, 'group_profiles', 'wilt_expires_at', 'TEXT');
    }

    // v19: Social contact list (friends list) & block list.
    if (oldVersion < 19) {
      try {
        await db.execute(_createSocialContactsTableSql);
      } catch (_) {}
      try {
        await db.execute(_createContactBlocksTableSql);
      } catch (_) {}
    }

    // v20: user-pinned social contacts & status message.
    if (oldVersion < 20) {
      await _safeAddColumn(db, 'social_contacts', 'is_pinned', 'INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'social_contacts', 'status', 'TEXT');
    }

    // v21: theme_id on social_contacts and contacts.
    if (oldVersion < 21) {
      await _safeAddColumn(db, 'social_contacts', 'theme_id', 'TEXT');
      await _safeAddColumn(db, 'contacts', 'theme_id', 'TEXT');
    }

    // v22: message editing and deletion.
    if (oldVersion < 22) {
      await _safeAddColumn(db, 'messages', 'is_edited', 'INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'messages', 'edit_target_id', 'TEXT');
      await _safeAddColumn(db, 'messages', 'edited_at', 'INTEGER');
      await _safeAddColumn(db, 'messages', 'is_deleted', 'INTEGER DEFAULT 0');
    }

    // v23: is_pending_emergency flag on contacts.
    if (oldVersion < 23) {
      await _safeAddColumn(db, 'contacts', 'is_pending_emergency', 'INTEGER DEFAULT 0');
    }

    // v24: status_emoji and status_expires_at on social_contacts for rich status & ephemeral expiry.
    if (oldVersion < 24) {
      await _safeAddColumn(db, 'social_contacts', 'status_emoji', 'TEXT');
      await _safeAddColumn(db, 'social_contacts', 'status_expires_at', 'INTEGER');
    }

    // v25: notification_mode on contacts ('all', 'mentions_only', 'muted').
    if (oldVersion < 25) {
      await _safeAddColumn(db, 'contacts', 'notification_mode', "TEXT DEFAULT 'all'");
    }

    // v26: Google Play Integrity client attestation and attestation_expires_at.
    if (oldVersion < 26) {
      await _safeAddColumn(db, 'contacts', 'client_attestation', 'TEXT');
      await _safeAddColumn(db, 'contacts', 'attestation_expires_at', 'INTEGER');
      await _safeAddColumn(db, 'social_contacts', 'client_attestation', 'TEXT');
      await _safeAddColumn(db, 'social_contacts', 'attestation_expires_at', 'INTEGER');
      await _safeAddColumn(db, 'group_profiles', 'client_attestation', 'TEXT');
      await _safeAddColumn(db, 'group_profiles', 'attestation_expires_at', 'INTEGER');
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
        avatar_border TEXT,
        wilt_expires_at TEXT,
        client_attestation TEXT,
        attestation_expires_at INTEGER,
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
        theme_id TEXT,
        avatar_border TEXT,
        client_attestation TEXT,
        attestation_expires_at INTEGER,
        outgoing_offset INTEGER,
        outgoing_max_offset INTEGER,
        incoming_offset INTEGER,
        incoming_max_offset INTEGER,
        wilt_expires_at INTEGER,
        stream_seed TEXT,
        wilt_created_at INTEGER,
        group_wilt_lifetime_secs INTEGER,
        group_seed TEXT,
        lane_size INTEGER,
        total_group_size INTEGER,
        slot_index INTEGER,
        additional_slots TEXT,
        group_recharge_pending INTEGER DEFAULT 0,
        is_pending_emergency INTEGER DEFAULT 0,
        notification_mode TEXT DEFAULT 'all'
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
        wilted_by TEXT,
        reply_to_id TEXT,
        media_path TEXT,
        remote_file_id TEXT,
        remote_size INTEGER DEFAULT 0,
        is_edited INTEGER DEFAULT 0,
        edit_target_id TEXT,
        edited_at INTEGER,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    // Speeds windowed paging (chat_id + timestamp ORDER/LIMIT) and unread counts.
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_chat_time ON messages(chat_id, timestamp)',
    );

    // 6. Activity feed events (see AppEvent / AppStateEvents).
    await db.execute(_createEventsTableSql);

    // 7. Social contact list (friends list) — independent of chat contacts.
    await db.execute(_createSocialContactsTableSql);

    // 8. Local block list for contact requests.
    await db.execute(_createContactBlocksTableSql);
  }

  // Activity-feed event log. `chat_key` (nullable) deep-links to a chat when it
  // still exists; `read` drives the bell badge. Kept as its own table (not
  // messages) because some events — a nuke that deleted the chat — have no chat
  // to live in. Defined once so `_onCreate` and the v16 upgrade stay identical.
  static const String _createEventsTableSql = '''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        type TEXT,
        title TEXT,
        body TEXT,
        chat_key TEXT,
        timestamp INTEGER,
        read INTEGER DEFAULT 0
      )
    ''';

  // Social contact list (friends list) — independent of chat contacts.
  // Established via mutual contact requests over existing 1-on-1 chats.
  static const String _createSocialContactsTableSql = '''
      CREATE TABLE IF NOT EXISTS social_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key_hash TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        short_nick TEXT,
        profile_image_b64 TEXT,
        avatar_border_id TEXT,
        theme_id TEXT,
        shared_secret_seed TEXT NOT NULL,
        my_pubkey TEXT NOT NULL,
        peer_pubkey TEXT NOT NULL,
        added_at INTEGER NOT NULL,
        is_blocked INTEGER DEFAULT 0,
        theme_seed TEXT,
        last_synced_at INTEGER,
        is_pinned INTEGER DEFAULT 0,
        status TEXT,
        status_emoji TEXT,
        status_expires_at INTEGER,
        client_attestation TEXT,
        attestation_expires_at INTEGER
      )
    ''';

  // Local block list — silently drops inbound contact requests from blocked peers.
  static const String _createContactBlocksTableSql = '''
      CREATE TABLE IF NOT EXISTS contact_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key_hash TEXT UNIQUE NOT NULL,
        blocked_at INTEGER NOT NULL,
        reason TEXT
      )
    ''';

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
      'theme_id': contact.themeId,
      'avatar_border': contact.avatarBorderId,
      'client_attestation': contact.clientAttestation,
      'attestation_expires_at': contact.attestationExpiresAt,
      'outgoing_offset': contact.outgoingOffset,
      'outgoing_max_offset': contact.outgoingMaxOffset,
      'incoming_offset': contact.incomingOffset,
      'incoming_max_offset': contact.incomingMaxOffset,
      'wilt_expires_at': contact.wiltExpiresAt?.millisecondsSinceEpoch,
      'stream_seed': contact.streamSeedHex,
      'wilt_created_at': contact.wiltCreatedAt?.millisecondsSinceEpoch,
      'group_wilt_lifetime_secs': contact.groupWiltLifetimeSecs,
      'group_seed': contact.groupSeed,
      'lane_size': contact.laneSize,
      'total_group_size': contact.totalGroupSize,
      'slot_index': contact.slotIndex,
      'additional_slots': jsonEncode(contact.additionalSlots),
      'group_recharge_pending': contact.groupRechargePending ? 1 : 0,
      'is_pending_emergency': contact.isPendingEmergency ? 1 : 0,
      'notification_mode': contact.notificationMode,
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
        themeId: row['theme_id'] as String?,
        avatarBorderId: row['avatar_border'] as String?,
        clientAttestation: row['client_attestation'] as String?,
        attestationExpiresAt: row['attestation_expires_at'] as int?,
        outgoingOffset: row['outgoing_offset'] as int? ?? 0,
        outgoingMaxOffset: row['outgoing_max_offset'] as int? ?? 0,
        incomingOffset: row['incoming_offset'] as int? ?? 0,
        incomingMaxOffset: row['incoming_max_offset'] as int? ?? 0,
        wiltExpiresAt: row['wilt_expires_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(row['wilt_expires_at'] as int)
            : null,
        streamSeedHex: row['stream_seed'] as String?,
        wiltCreatedAt: row['wilt_created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(row['wilt_created_at'] as int)
            : null,
        groupWiltLifetimeSecs: row['group_wilt_lifetime_secs'] as int?,
        groupSeed: row['group_seed'] as String?,
        laneSize: row['lane_size'] as int?,
        totalGroupSize: row['total_group_size'] as int?,
        slotIndex: row['slot_index'] as int?,
        additionalSlots:
            (jsonDecode(row['additional_slots'] as String? ?? '[]')
                    as List<dynamic>)
                .cast<int>(),
        groupRechargePending:
            (row['group_recharge_pending'] as int? ?? 0) == 1,
        isPendingEmergency:
            (row['is_pending_emergency'] as int? ?? 0) == 1,
        notificationMode: row['notification_mode'] as String? ?? 'all',
      );
    }).toList();
  }

  Future<void> updateContactNotificationMode(
    String keyHash,
    String mode,
  ) async {
    final db = await _database;
    await db.update(
      'contacts',
      {'notification_mode': mode},
      where: 'key_hash = ?',
      whereArgs: [keyHash],
    );
  }

  Future<void> updateContactPendingEmergency(
    String keyHash,
    bool isPending,
  ) async {
    final db = await _database;
    await db.update(
      'contacts',
      {'is_pending_emergency': isPending ? 1 : 0},
      where: 'key_hash = ?',
      whereArgs: [keyHash],
    );
  }

  Future<void> deleteContactRecord(String chatId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
      await txn.delete('contacts', where: 'id = ?', whereArgs: [chatId]);
    });
    await _deleteMediaForChat(chatId); // drop any offloaded body files too
  }

  // ---------------------------------------------------------------------------
  // Messages CRUD
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Large-body sidecar files (see [kInlineBodyLimit])
  //
  // A message whose stored body would blow past the CursorWindow keeps its two
  // big strings — the OTP ciphertext (`text_otp`, needed for resync) and the
  // master-encrypted copy (`text_encrypted_master`, needed for display) — in a
  // pair of files: `<base>.o` and `<base>.m`. `base` is deterministic from
  // (chatId, id) so a re-save (resync / redelivery) overwrites in place instead
  // of orphaning files. The row then stores media_path=base and blank bodies.
  // ---------------------------------------------------------------------------

  String _mediaBase(String chatId, String messageId) {
    String clean(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '${clean(chatId)}__${clean(messageId)}';
  }

  Future<void> _writeMediaFiles(String base, String otp, String? master) async {
    final dir = _mediaDir;
    if (dir == null) return;
    await File(p.join(dir, '$base.o')).writeAsString(otp, flush: true);
    final mf = File(p.join(dir, '$base.m'));
    if (master != null) {
      await mf.writeAsString(master, flush: true);
    } else if (await mf.exists()) {
      await mf.delete();
    }
  }

  /// Synchronously reload an offloaded body pair. Returns (otp, master?) or null
  /// if the sidecar is missing/unreadable (row then renders as unavailable).
  /// Sync on purpose: [_rowToMessage] is sync and already does heavy sync work
  /// (base64Decode), so a blocking read here keeps the decode path uniform.
  (String, String?)? _readMediaFilesSync(String base) {
    try {
      final dir = _mediaDir;
      if (dir == null) return null;
      final of = File(p.join(dir, '$base.o'));
      if (!of.existsSync()) return null;
      final otp = of.readAsStringSync();
      final mf = File(p.join(dir, '$base.m'));
      final master = mf.existsSync() ? mf.readAsStringSync() : null;
      return (otp, master);
    } catch (_) {
      return null;
    }
  }

  /// Async sidecar read, for the lazy image loader (off the sync page-load path).
  Future<(String, String?)?> _readMediaFilesAsync(String base) async {
    try {
      final dir = _mediaDir;
      if (dir == null) return null;
      final of = File(p.join(dir, '$base.o'));
      if (!await of.exists()) return null;
      final otp = await of.readAsString();
      final mf = File(p.join(dir, '$base.m'));
      final master = await mf.exists() ? await mf.readAsString() : null;
      return (otp, master);
    } catch (_) {
      return null;
    }
  }

  /// Lazily fetch & decode ONE plain image's bytes — called by its on-screen
  /// thumbnail so the heavy sidecar read + master-key decrypt + base64 decode
  /// happen only when the image is actually visible, not for every row at page
  /// load (see [_rowToMessage]'s `deferImage`). Uses the DURABLE master-key copy
  /// so it still works after a pad reset. Returns null if unavailable/unreadable.
  ///
  /// Reads the deterministic sidecar path FIRST (where every large image lives),
  /// which also sidesteps the ~2 MB CursorWindow limit a big inline column query
  /// would hit; only small inline images fall back to a direct column read.
  Future<Uint8List?> loadImageBytes(
    String chatId,
    String messageId, {
    String? masterKeyHex,
  }) async {
    if (masterKeyHex == null) return null;
    String? master;
    final loaded = await _readMediaFilesAsync(_mediaBase(chatId, messageId));
    if (loaded != null) {
      master = loaded.$2;
    } else {
      try {
        final db = await _database;
        final rows = await db.query(
          'messages',
          columns: ['text_encrypted_master', 'wilted'],
          where: 'chat_id = ? AND id = ?',
          whereArgs: [chatId, messageId],
          limit: 1,
        );
        if (rows.isEmpty) return null;
        if ((rows.first['wilted'] as int? ?? 0) == 1) return null;
        master = rows.first['text_encrypted_master'] as String?;
      } catch (_) {
        return null;
      }
    }
    if (master == null) return null;
    try {
      return base64Decode(WiltkeyPersistence().decryptString(master, masterKeyHex));
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteMediaFiles(String base) async {
    try {
      final dir = _mediaDir;
      if (dir == null) return;
      for (final ext in const ['.o', '.m']) {
        final f = File(p.join(dir, '$base$ext'));
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }

  /// Delete every offloaded sidecar belonging to [chatId] (nuke / chat delete).
  Future<void> _deleteMediaForChat(String chatId) async {
    try {
      final dir = _mediaDir;
      if (dir == null) return;
      final prefix = '${chatId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}__';
      final d = Directory(dir);
      if (!await d.exists()) return;
      await for (final e in d.list()) {
        if (e is File && p.basename(e.path).startsWith(prefix)) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Reads a possibly-oversized TEXT column in CursorWindow-safe chunks, so a
  /// legacy inline row too big for a normal query can still be recovered.
  Future<String> _readColumnChunked(
    Database db,
    String id,
    String column,
  ) async {
    const int chunk = 256 * 1024;
    final buf = StringBuffer();
    int start = 1; // SQLite substr is 1-indexed
    while (true) {
      final r = await db.rawQuery(
        'SELECT substr($column, ?, ?) AS s FROM messages WHERE id = ?',
        [start, chunk, id],
      );
      if (r.isEmpty) break;
      final s = r.first['s'] as String?;
      if (s == null || s.isEmpty) break;
      buf.write(s);
      if (s.length < chunk) break;
      start += chunk;
    }
    return buf.toString();
  }

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

    // Offload oversized bodies to a sidecar file so the row stays inside the
    // CursorWindow. Never for wilted rows (they keep no recoverable body). The
    // base is deterministic, so a re-save overwrites in place; when NOT
    // offloading we still best-effort delete any stale sidecar from a prior save.
    final String otpBody = wilted ? '' : msg.text;
    final bool offload =
        !wilted &&
        (otpBody.length > kInlineBodyLimit ||
            (textEncryptedMaster?.length ?? 0) > kInlineBodyLimit);
    final String base = _mediaBase(chatId, msg.id);
    String? mediaPath;
    if (offload) {
      await _writeMediaFiles(base, otpBody, textEncryptedMaster);
      mediaPath = base;
    } else {
      await _deleteMediaFiles(base);
    }

    await db.insert('messages', {
      'id': msg.id,
      'chat_id': chatId,
      'sender_id': msg.senderId,
      // A wilted row keeps NO recoverable body — blank both ciphertext copies.
      // An offloaded row keeps its bodies in the sidecar file, blank in the row.
      'text_otp': (wilted || offload) ? '' : otpBody,
      'content_type': msg.contentType,
      'timestamp': msg.timestamp.toIso8601String(),
      'is_sent_by_me': msg.isSentByMe ? 1 : 0,
      'offset': wilted ? -1 : msg.offset,
      'is_delivered': msg.isDelivered ? 1 : 0,
      'text_encrypted_master': (wilted || offload) ? null : textEncryptedMaster,
      'is_failed': msg.isFailed ? 1 : 0,
      'reactions': reactionsJson,
      'allow_save': msg.allowSave ? 1 : 0,
      'ephemeral': msg.ephemeral ? 1 : 0,
      'ttl_seconds': msg.ttlSeconds,
      'opened_at': msg.openedAt,
      'expires_at': msg.expiresAt,
      'wilted': wilted ? 1 : 0,
      'wilted_by': wiltedByJson,
      'reply_to_id': msg.replyToId,
      'media_path': mediaPath,
      // A wilted placeholder must never stay fetchable.
      'remote_file_id': wilted ? null : msg.remoteFileId,
      'remote_size': msg.remoteSize,
      'is_edited': msg.isEdited ? 1 : 0,
      'edit_target_id': msg.editTargetId,
      'edited_at': msg.editedAt,
      'is_deleted': msg.isDeleted ? 1 : 0,
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
    // Destroy any offloaded body files too, then drop the pointer.
    final existing = await db.query(
      'messages',
      columns: ['media_path'],
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    final base = existing.isNotEmpty ? existing.first['media_path'] as String? : null;
    if (base != null && base.isNotEmpty) await _deleteMediaFiles(base);
    await db.update(
      'messages',
      {
        'text_otp': '',
        'text_encrypted_master': null,
        'offset': -1,
        'wilted': 1,
        'media_path': null,
        // A wilted message must not remain downloadable from the relay.
        'remote_file_id': null,
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
  /// Decodes a raw `messages` row into a [ChatMessage], decrypting the body from
  /// the master-key copy when [masterKeyHex] is given (system lines store
  /// plaintext in text_otp). Pass a null key to skip decryption — fine for
  /// resync forwarding, which only needs the OTP ciphertext + metadata.
  ChatMessage _rowToMessage(
    Map<String, Object?> row, {
    String? masterKeyHex,
    bool eagerOtp = false,
    bool? deferImage,
  }) {
    final senderId = row['sender_id'] as String;
    final contentType = row['content_type'] as String;
    final wilted = (row['wilted'] as int? ?? 0) == 1;

    // Body may live inline OR in a sidecar file (large images/voice). Tolerate a
    // missing text_otp key: the CursorWindow-safe page loader omits it from the
    // batch select and reloads it per-row.
    // Plain images are loaded LAZILY by their on-screen thumbnail (see
    // [loadImageBytes] / ChatImageThumbnail): reading the sidecar, decrypting the
    // master copy, and base64-decoding here for EVERY row at page load is what
    // froze chats full of large images. Wilting/hidden images keep the eager path
    // (special lifecycle / need a pre-reveal size).
    final bool shouldDefer = deferImage ?? (
      !eagerOtp &&
      !wilted &&
      contentType == 'image' &&
      (row['ephemeral'] as int? ?? 0) == 0
    );

    String textOtp = (row['text_otp'] as String?) ?? '';
    String? textEncryptedMaster = row['text_encrypted_master'] as String?;
    final mediaPath = row['media_path'] as String?;
    if (!shouldDefer && !wilted && mediaPath != null && mediaPath.isNotEmpty) {
      final loaded = _readMediaFilesSync(mediaPath);
      if (loaded != null) {
        textOtp = loaded.$1;
        textEncryptedMaster = loaded.$2 ?? textEncryptedMaster;
      }
      // If the sidecar is gone, textOtp/master stay empty → renders as an empty
      // body rather than throwing, so one lost file can't brick the chat.
    }

    final isDeleted = (row['is_deleted'] as int? ?? 0) == 1;
    final isEdited = (row['is_edited'] as int? ?? 0) == 1;
    final editTargetId = row['edit_target_id'] as String?;
    final editedAt = row['edited_at'] as int?;

    String? decryptedText;
    if (wilted || shouldDefer) {
      // wilted: destroyed content. deferImage: body fetched on demand when the
      // thumbnail scrolls into view — nothing to decrypt here.
    } else if (isDeleted) {
      decryptedText = '[Message deleted]';
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
      decodedImageBytes: (!shouldDefer &&
              !isDeleted &&
              contentType == 'image' &&
              decryptedText != null)
          ? base64Decode(decryptedText)
          : null,
      decodedAudioBytes: (!isDeleted &&
              contentType == 'voice' &&
              decryptedText != null &&
              decryptedText.isNotEmpty)
          ? base64Decode(decryptedText)
          : null,
      reactions: ChatMessage.decodeReactions(row['reactions'] as String?),
      ephemeral: (row['ephemeral'] as int? ?? 0) == 1,
      ttlSeconds: row['ttl_seconds'] as int? ?? 0,
      openedAt: row['opened_at'] as int?,
      expiresAt: row['expires_at'] as int?,
      wilted: wilted,
      wiltedBy: _decodeWiltedBy(row['wilted_by'] as String?),
      replyToId: row['reply_to_id'] as String?,
      remoteFileId: row['remote_file_id'] as String?,
      remoteSize: row['remote_size'] as int? ?? 0,
      isEdited: isEdited,
      editTargetId: editTargetId,
      editedAt: editedAt,
      isDeleted: isDeleted,
    );
  }

  /// Retrieves a single message by ID.
  Future<ChatMessage?> getMessageById(
    String messageId, {
    String? chatId,
    String? masterKeyHex,
  }) async {
    final db = await _database;
    final where = chatId != null ? 'id = ? AND chat_id = ?' : 'id = ?';
    final whereArgs = chatId != null ? [messageId, chatId] : [messageId];
    final rows = await db.query(
      'messages',
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToMessage(rows.first, masterKeyHex: masterKeyHex);
  }

  /// Updates message content when edited.
  Future<void> updateMessageContent(
    String messageId, {
    String? chatId,
    required String newText,
    required bool isEdited,
    required bool isDeleted,
    int? editedAt,
    String? masterKeyHex,
  }) async {
    final db = await _database;
    final updateMap = <String, Object?>{
      'is_edited': isEdited ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      if (editedAt != null) 'edited_at': editedAt,
    };
    if (masterKeyHex != null) {
      updateMap['text_encrypted_master'] = WiltkeyPersistence().encryptString(
        newText,
        masterKeyHex,
      );
    }
    final where = chatId != null ? 'id = ? AND chat_id = ?' : 'id = ?';
    final whereArgs = chatId != null ? [messageId, chatId] : [messageId];
    await db.update(
      'messages',
      updateMap,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Wipes media files and marks a row as deleted.
  Future<void> deleteMessageRow(String messageId, {String? chatId}) async {
    final db = await _database;
    final where = chatId != null ? 'id = ? AND chat_id = ?' : 'id = ?';
    final whereArgs = chatId != null ? [messageId, chatId] : [messageId];
    final existing = await db.query(
      'messages',
      columns: ['media_path'],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    final base =
        existing.isNotEmpty ? existing.first['media_path'] as String? : null;
    if (base != null && base.isNotEmpty) {
      await _deleteMediaFiles(base);
    }
    await db.update(
      'messages',
      {
        'is_deleted': 1,
        'text_otp': '',
        'text_encrypted_master': null,
        'media_path': null,
      },
      where: where,
      whereArgs: whereArgs,
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
    final where = beforeTimestamp == null
        ? 'chat_id = ?'
        : 'chat_id = ? AND timestamp < ?';
    final whereArgs = beforeTimestamp == null
        ? [chatId]
        : [chatId, beforeTimestamp];
    try {
      final rows = await db.query(
        'messages',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      // Query is newest-first; reverse to chronological for display.
      return [
        for (final r in rows.reversed)
          _rowToMessage(r, masterKeyHex: masterKeyHex),
      ];
    } catch (e) {
      // A legacy inline row too big for the CursorWindow makes the whole batch
      // query throw. Recover it row-by-row (never selecting the huge columns in
      // one shot) so the chat loads instead of blanking.
      print('[DB] page query fell back to safe row-by-row load: $e');
      return _getMessagesPageSafe(
        db,
        where,
        whereArgs,
        limit,
        masterKeyHex,
      );
    }
  }

  /// CursorWindow-safe fallback: selects only the small columns in the batch
  /// (never the big body columns), then reconstructs each body — from the sidecar
  /// file if offloaded, else via chunked reads for a legacy oversized inline row,
  /// which it also migrates to a sidecar so the next load takes the fast path.
  static const List<String> _smallMessageColumns = [
    'id', 'chat_id', 'sender_id', 'content_type', 'timestamp', 'is_sent_by_me',
    'offset', 'is_delivered', 'is_failed', 'reactions', 'allow_save',
    'ephemeral', 'ttl_seconds', 'opened_at', 'expires_at', 'wilted',
    'wilted_by', 'reply_to_id', 'media_path', 'remote_file_id', 'remote_size',
  ];

  Future<List<ChatMessage>> _getMessagesPageSafe(
    Database db,
    String where,
    List<Object?> whereArgs,
    int limit,
    String? masterKeyHex,
  ) async {
    final rows = await db.query(
      'messages',
      columns: _smallMessageColumns,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    final out = <ChatMessage>[];
    for (final r in rows.reversed) {
      final wilted = (r['wilted'] as int? ?? 0) == 1;
      final mediaPath = r['media_path'] as String?;
      if (wilted || (mediaPath != null && mediaPath.isNotEmpty)) {
        // File-backed or bodyless — _rowToMessage handles both safely.
        out.add(_rowToMessage(r, masterKeyHex: masterKeyHex));
        continue;
      }
      // Legacy oversized inline row: pull the bodies in chunks, then migrate.
      try {
        final id = r['id'] as String;
        final otp = await _readColumnChunked(db, id, 'text_otp');
        final master = await _readColumnChunked(db, id, 'text_encrypted_master');
        final masterOrNull = master.isEmpty ? null : master;
        final oversized =
            otp.length > kInlineBodyLimit ||
            (masterOrNull?.length ?? 0) > kInlineBodyLimit;
        if (oversized) {
          final base = _mediaBase(r['chat_id'] as String, id);
          await _writeMediaFiles(base, otp, masterOrNull);
          await db.update(
            'messages',
            {
              'text_otp': '',
              'text_encrypted_master': null,
              'media_path': base,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        out.add(
          _rowToMessage(
            {
              ...r,
              'text_otp': otp,
              'text_encrypted_master': masterOrNull,
              'media_path': null, // use the inline strings we just built
            },
            masterKeyHex: masterKeyHex,
          ),
        );
      } catch (e) {
        print('[DB] could not recover message ${r['id']}: $e');
        // Unreadable — surface a placeholder so the rest of the chat still loads.
        out.add(
          _rowToMessage(
            {...r, 'text_otp': '', 'text_encrypted_master': null, 'media_path': null},
            masterKeyHex: masterKeyHex,
          ),
        );
      }
    }
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

  /// Returns the most recent non-system sender in [chatId] excluding [excludeUserId].
  Future<String?> getMostRecentSender(
    String chatId, {
    String? excludeUserId,
  }) async {
    final db = await _database;
    final where = excludeUserId != null
        ? "chat_id = ? AND sender_id != 'system' AND sender_id != ? AND is_sent_by_me = 0"
        : "chat_id = ? AND sender_id != 'system' AND is_sent_by_me = 0";
    final whereArgs = excludeUserId != null
        ? [chatId, excludeUserId]
        : [chatId];
    final rows = await db.query(
      'messages',
      columns: ['sender_id'],
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['sender_id'] as String?;
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
    return [for (final r in rows) _rowToMessage(r, eagerOtp: true)];
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

  /// Mark a large file as fully downloaded + stored: drops the relay pointer so
  /// the message stops rendering as a pending download. Called immediately before
  /// the FILE_RECEIVED ack that lets the relay delete its copy.
  Future<void> clearPendingDownload(String messageId) async {
    final db = await _database;
    await db.update(
      'messages',
      {'remote_file_id': null},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// How many message bodies are still waiting on the relay (any chat).
  Future<int> countPendingDownloads() async {
    final db = await _database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM messages "
      "WHERE remote_file_id IS NOT NULL AND remote_file_id != '' AND wilted = 0",
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<void> deleteMessagesForChat(String chatId) async {
    final db = await _database;
    await db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
    await _deleteMediaForChat(chatId); // drop any offloaded body files too
  }

  /// Prunes message history for [chatId], retaining only the [keepLastCount] most recent messages.
  /// Deletes older messages and any offloaded media sidecar files (.o, .m) associated with pruned rows.
  /// Returns the number of pruned messages.
  Future<int> pruneChatMessages(String chatId, int keepLastCount) async {
    if (keepLastCount <= 0) return 0;
    final db = await _database;

    final cutoffRows = await db.query(
      'messages',
      columns: ['timestamp'],
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
      limit: 1,
      offset: keepLastCount - 1,
    );
    if (cutoffRows.isEmpty) return 0;

    final cutoffTimestamp = cutoffRows.first['timestamp'] as String;

    // Collect media paths of messages older than cutoff to delete sidecars
    final toDeleteRows = await db.query(
      'messages',
      columns: ['id', 'media_path'],
      where: 'chat_id = ? AND timestamp < ?',
      whereArgs: [chatId, cutoffTimestamp],
    );

    for (final row in toDeleteRows) {
      final base = row['media_path'] as String?;
      if (base != null && base.isNotEmpty) {
        await _deleteMediaFiles(base);
      }
    }

    final deletedCount = await db.delete(
      'messages',
      where: 'chat_id = ? AND timestamp < ?',
      whereArgs: [chatId, cutoffTimestamp],
    );

    return deletedCount;
  }

  /// Fetches media messages (photos / images) for [chatId] for the media gallery.
  Future<List<ChatMessage>> getChatMediaMessages(
    String chatId, {
    String? masterKeyHex,
    int limit = 300,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where:
          "chat_id = ? AND (content_type = 'image' OR content_type = 'image_hidden') AND wilted = 0 AND is_deleted = 0",
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return [
      for (final r in rows)
        _rowToMessage(r, masterKeyHex: masterKeyHex, deferImage: true),
    ];
  }

  /// Fetches voice messages for [chatId] for the audio gallery.
  Future<List<ChatMessage>> getChatVoiceMessages(
    String chatId, {
    String? masterKeyHex,
    int limit = 300,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where:
          "chat_id = ? AND content_type = 'voice' AND wilted = 0 AND is_deleted = 0",
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return [for (final r in rows) _rowToMessage(r, masterKeyHex: masterKeyHex)];
  }

  /// Fetches messages containing links for [chatId] for the links gallery.
  Future<List<ChatMessage>> getChatLinkMessages(
    String chatId, {
    String? masterKeyHex,
    int limit = 300,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where:
          "chat_id = ? AND content_type = 'text' AND wilted = 0 AND is_deleted = 0",
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    final linkRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final List<ChatMessage> result = [];
    for (final r in rows) {
      final msg = _rowToMessage(r, masterKeyHex: masterKeyHex);
      final text = msg.decryptedText ?? msg.text;
      if (linkRegex.hasMatch(text)) {
        result.add(msg);
      }
    }
    return result;
  }

  Future<void> deleteMessage(String id) async {
    final db = await _database;
    final existing = await db.query(
      'messages',
      columns: ['media_path'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final base =
        existing.isNotEmpty ? existing.first['media_path'] as String? : null;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
    if (base != null && base.isNotEmpty) await _deleteMediaFiles(base);
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
    String? avatarBorder,
    String? wiltExpiresAt,
    String? clientAttestation,
    int? attestationExpiresAt,
  }) async {
    final db = await _database;
    String? border = avatarBorder;
    String? wiltExpiry = wiltExpiresAt;
    String? attestation = clientAttestation;
    int? attExpires = attestationExpiresAt;
    if (border == null || wiltExpiry == null || attestation == null || attExpires == null) {
      final existing = await getProfile(groupId, memberKeyHash);
      border ??= existing?['avatar_border'] as String?;
      wiltExpiry ??= existing?['wilt_expires_at'] as String?;
      attestation ??= existing?['client_attestation'] as String?;
      attExpires ??= existing?['attestation_expires_at'] as int?;
    }
    await db.insert('group_profiles', {
      'group_id': groupId,
      'member_key_hash': memberKeyHash,
      'name': name,
      'profile_image': profileImage,
      'arrival_order': arrivalOrder,
      'avatar_border': border,
      'wilt_expires_at': wiltExpiry,
      'client_attestation': attestation,
      'attestation_expires_at': attExpires,
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
  // Activity feed events
  // ---------------------------------------------------------------------------

  Future<void> insertEvent(Map<String, Object?> row) async {
    final db = await _database;
    await db.insert(
      'events',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Newest-first, capped so the log can't grow unbounded.
  Future<List<Map<String, dynamic>>> getEvents({int limit = 200}) async {
    final db = await _database;
    return db.query('events', orderBy: 'timestamp DESC', limit: limit);
  }

  Future<int> getUnreadEventCount() async {
    final db = await _database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM events WHERE read = 0');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<void> markAllEventsRead() async {
    final db = await _database;
    await db.update('events', {'read': 1}, where: 'read = 0');
  }

  Future<void> deleteEventsForChat(String chatKey) async {
    final db = await _database;
    await db.delete('events', where: 'chat_key = ?', whereArgs: [chatKey]);
  }

  Future<void> clearEvents() async {
    final db = await _database;
    await db.delete('events');
  }

  /// Trim the log to the newest [keep] rows so it stays bounded over time.
  Future<void> pruneEvents({int keep = 200}) async {
    final db = await _database;
    await db.rawDelete(
      'DELETE FROM events WHERE id NOT IN '
      '(SELECT id FROM events ORDER BY timestamp DESC LIMIT ?)',
      [keep],
    );
  }

  // ---------------------------------------------------------------------------
  // Social Contacts (Friends List)
  // ---------------------------------------------------------------------------

  Future<int> insertSocialContact(SocialContact contact) async {
    final db = await _database;
    return await db.insert(
      'social_contacts',
      contact.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertSocialContact(SocialContact contact) async {
    final db = await _database;
    await db.insert(
      'social_contacts',
      contact.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SocialContact>> getAllSocialContacts() async {
    final db = await _database;
    final rows = await db.query(
      'social_contacts',
      orderBy: 'is_pinned DESC, added_at DESC',
    );
    return rows.map((r) => SocialContact.fromRow(r)).toList();
  }

  Future<SocialContact?> getSocialContact(String keyHash) async {
    final db = await _database;
    final rows = await db.query(
      'social_contacts',
      where: 'key_hash = ?',
      whereArgs: [keyHash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SocialContact.fromRow(rows.first);
  }

  Future<void> deleteSocialContact(String keyHash) async {
    final db = await _database;
    await db.delete('social_contacts', where: 'key_hash = ?', whereArgs: [keyHash]);
  }

  Future<void> updateSocialContactThemeSeed(String keyHash, String themeSeed) async {
    final db = await _database;
    await db.update(
      'social_contacts',
      {'theme_seed': themeSeed},
      where: 'key_hash = ?',
      whereArgs: [keyHash],
    );
  }

  Future<void> updateSocialContactLastSynced(String keyHash, int timestamp) async {
    final db = await _database;
    await db.update(
      'social_contacts',
      {'last_synced_at': timestamp},
      where: 'key_hash = ?',
      whereArgs: [keyHash],
    );
  }

  Future<void> updateSocialContactPinned(String keyHash, bool pinned) async {
    final db = await _database;
    await db.update(
      'social_contacts',
      {'is_pinned': pinned ? 1 : 0},
      where: 'key_hash = ?',
      whereArgs: [keyHash],
    );
  }

  /// Apply an incoming profile_update snapshot from [keyHash]. Passing null for a
  /// field leaves it untouched; passing an empty string clears a nullable field.
  Future<void> updateSocialContactProfile({
    required String keyHash,
    String? name,
    String? shortNick,
    String? profileImageB64,
    String? avatarBorderId,
    String? themeId,
    String? status,
    String? statusEmoji,
    int? statusExpiresAt,
    int? lastSyncedAt,
    String? clientAttestation,
    int? attestationExpiresAt,
  }) async {
    final db = await _database;
    await db.update(
      'social_contacts',
      {
        'name': ?name,
        'short_nick': ?shortNick,
        'profile_image_b64': ?profileImageB64,
        'avatar_border_id': ?avatarBorderId,
        'theme_id': ?themeId,
        'status': ?status,
        'status_emoji': ?statusEmoji,
        'status_expires_at': ?statusExpiresAt,
        'last_synced_at': ?lastSyncedAt,
        'client_attestation': ?clientAttestation,
        'attestation_expires_at': ?attestationExpiresAt,
      },
      where: 'key_hash = ?',
      whereArgs: [keyHash],
    );
  }

  // ---------------------------------------------------------------------------
  // Contact Blocks
  // ---------------------------------------------------------------------------

  Future<int> insertContactBlock(ContactBlock block) async {
    final db = await _database;
    return await db.insert(
      'contact_blocks',
      block.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ContactBlock>> getAllContactBlocks() async {
    final db = await _database;
    final rows = await db.query(
      'contact_blocks',
      orderBy: 'blocked_at DESC',
    );
    return rows.map((r) => ContactBlock.fromRow(r)).toList();
  }

  Future<ContactBlock?> getContactBlock(String keyHash) async {
    final db = await _database;
    final rows = await db.query(
      'contact_blocks',
      where: 'key_hash = ?',
      whereArgs: [keyHash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ContactBlock.fromRow(rows.first);
  }

  Future<void> deleteContactBlock(String keyHash) async {
    final db = await _database;
    await db.delete('contact_blocks', where: 'key_hash = ?', whereArgs: [keyHash]);
  }

  Future<bool> isContactBlocked(String keyHash) async {
    final block = await getContactBlock(keyHash);
    return block != null;
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
      await txn.delete('social_contacts');
      await txn.delete('contact_blocks');
      // The activity feed is plaintext ("a chat was destroyed", "host recharged
      // group X") — a nuke must wipe it too, or the new identity inherits a
      // metadata trail the rest of the app is built to avoid.
      await txn.delete('events');
    });
    // Purge every offloaded body file (self-destruct leaves no media behind).
    try {
      final dir = _mediaDir;
      if (dir != null) {
        final d = Directory(dir);
        if (await d.exists()) {
          await for (final e in d.list()) {
            if (e is File) {
              try {
                await e.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
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
