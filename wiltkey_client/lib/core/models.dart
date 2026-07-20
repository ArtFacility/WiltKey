import 'dart:convert';
import 'dart:typed_data';

import 'custom_emoji.dart' show stickerPayload;

class Contact {
  final String id;
  final String name;
  final String keyHash;
  final String relayUrl;
  final bool isPrivateNode;
  final int maxBufferBytes;
  int remainingBufferBytes;
  int peerRemainingBufferBytes;
  final DateTime lastActivity;
  bool isWilted; // True when charge is 0
  bool
  isArchived; // True once the OTP pad has been dropped to save space (read-only)
  bool isPinned; // User-pinned to the top of the chats list

  // Group chat specific attributes
  final bool isGroup;
  final int? memberCount;
  final String? hostName;
  final bool isHost; // Whether current user is the host of this group
  final String? hostKeyHash; // Key hash of the group host (for spoke routing)
  final List<String> memberKeyHashes; // All member key hashes in the group
  final String? groupIconHex; // 10x10 pixel art hex for group avatar
  final int? maxMembers; // Max allowed members
  final int? maxMessageSize; // Max message payload size in bytes
  final bool? imagesAllowed; // Whether image attachments are permitted
  final DateTime?
  joinedAt; // When this member joined (for hiding pre-join messages)

  // Shared Pad with Lanes architecture
  final String? groupSeed; // Shared seed for deterministic keystream generation
  final int? laneSize; // Size of each member lane in bytes
  final int? totalGroupSize; // Total keystream file size in bytes
  final int? slotIndex; // This member's primary lane slot index
  final List<int> additionalSlots; // Extra lane slots from refills

  // Profile metadata sync
  String? shortNick;
  String? profileImageB64; // Stored as a 100-character hex matrix for pixel art
  // The peer's equipped avatar border id (see WkAvatarBorderRegistry), synced
  // over the 1-on-1 metadata channel like the avatar/nick. Cosmetic broadcast
  // art — always renders for everyone; null/'none' = no border.
  String? avatarBorderId;

  // OTP partition offsets
  int outgoingOffset;
  int outgoingMaxOffset;
  int incomingOffset;
  int incomingMaxOffset;

  Contact({
    required this.id,
    required this.name,
    required this.keyHash,
    required this.relayUrl,
    required this.isPrivateNode,
    required this.maxBufferBytes,
    required this.remainingBufferBytes,
    required this.peerRemainingBufferBytes,
    required this.lastActivity,
    this.isWilted = false,
    this.isArchived = false,
    this.isPinned = false,
    this.isGroup = false,
    this.memberCount,
    this.hostName,
    this.isHost = false,
    this.hostKeyHash,
    this.memberKeyHashes = const [],
    this.groupIconHex,
    this.maxMembers,
    this.maxMessageSize,
    this.imagesAllowed,
    this.joinedAt,
    this.shortNick,
    this.profileImageB64,
    this.avatarBorderId,
    this.outgoingOffset = 0,
    this.outgoingMaxOffset = 0,
    this.incomingOffset = 0,
    this.incomingMaxOffset = 0,
    this.groupSeed,
    this.laneSize,
    this.totalGroupSize,
    this.slotIndex,
    List<int> additionalSlots = const [],
  }) : additionalSlots = List<int>.from(additionalSlots);

  Contact copyWith({
    String? id,
    String? name,
    String? keyHash,
    String? relayUrl,
    bool? isPrivateNode,
    int? maxBufferBytes,
    int? remainingBufferBytes,
    int? peerRemainingBufferBytes,
    DateTime? lastActivity,
    bool? isWilted,
    bool? isArchived,
    bool? isPinned,
    bool? isGroup,
    int? memberCount,
    String? hostName,
    bool? isHost,
    String? hostKeyHash,
    List<String>? memberKeyHashes,
    String? groupIconHex,
    int? maxMembers,
    int? maxMessageSize,
    bool? imagesAllowed,
    DateTime? joinedAt,
    String? shortNick,
    String? profileImageB64,
    String? avatarBorderId,
    int? outgoingOffset,
    int? outgoingMaxOffset,
    int? incomingOffset,
    int? incomingMaxOffset,
    String? groupSeed,
    int? laneSize,
    int? totalGroupSize,
    int? slotIndex,
    List<int>? additionalSlots,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      keyHash: keyHash ?? this.keyHash,
      relayUrl: relayUrl ?? this.relayUrl,
      isPrivateNode: isPrivateNode ?? this.isPrivateNode,
      maxBufferBytes: maxBufferBytes ?? this.maxBufferBytes,
      remainingBufferBytes: remainingBufferBytes ?? this.remainingBufferBytes,
      peerRemainingBufferBytes:
          peerRemainingBufferBytes ?? this.peerRemainingBufferBytes,
      lastActivity: lastActivity ?? this.lastActivity,
      isWilted: isWilted ?? this.isWilted,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      isGroup: isGroup ?? this.isGroup,
      memberCount: memberCount ?? this.memberCount,
      hostName: hostName ?? this.hostName,
      isHost: isHost ?? this.isHost,
      hostKeyHash: hostKeyHash ?? this.hostKeyHash,
      memberKeyHashes: memberKeyHashes ?? this.memberKeyHashes,
      groupIconHex: groupIconHex ?? this.groupIconHex,
      maxMembers: maxMembers ?? this.maxMembers,
      maxMessageSize: maxMessageSize ?? this.maxMessageSize,
      imagesAllowed: imagesAllowed ?? this.imagesAllowed,
      joinedAt: joinedAt ?? this.joinedAt,
      shortNick: shortNick ?? this.shortNick,
      profileImageB64: profileImageB64 ?? this.profileImageB64,
      avatarBorderId: avatarBorderId ?? this.avatarBorderId,
      outgoingOffset: outgoingOffset ?? this.outgoingOffset,
      outgoingMaxOffset: outgoingMaxOffset ?? this.outgoingMaxOffset,
      incomingOffset: incomingOffset ?? this.incomingOffset,
      incomingMaxOffset: incomingMaxOffset ?? this.incomingMaxOffset,
      groupSeed: groupSeed ?? this.groupSeed,
      laneSize: laneSize ?? this.laneSize,
      totalGroupSize: totalGroupSize ?? this.totalGroupSize,
      slotIndex: slotIndex ?? this.slotIndex,
      additionalSlots: additionalSlots ?? this.additionalSlots,
    );
  }

  double get chargePercentage => remainingBufferBytes / maxBufferBytes;

  int getTheirRemainingBytes(String myUserId) {
    if (isGroup) return 0;
    return peerRemainingBufferBytes;
  }

  double getTheirChargePercentage(String myUserId) {
    if (maxBufferBytes == 0) return 0.0;
    return getTheirRemainingBytes(myUserId) / maxBufferBytes;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'keyHash': keyHash,
    'relayUrl': relayUrl,
    'isPrivateNode': isPrivateNode,
    'maxBufferBytes': maxBufferBytes,
    'remainingBufferBytes': remainingBufferBytes,
    'peerRemainingBufferBytes': peerRemainingBufferBytes,
    'lastActivity': lastActivity.toIso8601String(),
    'isWilted': isWilted,
    'isArchived': isArchived,
    'isPinned': isPinned,
    'isGroup': isGroup,
    'memberCount': memberCount,
    'hostName': hostName,
    'isHost': isHost,
    'hostKeyHash': hostKeyHash,
    'memberKeyHashes': memberKeyHashes,
    'groupIconHex': groupIconHex,
    'maxMembers': maxMembers,
    'maxMessageSize': maxMessageSize,
    'imagesAllowed': imagesAllowed,
    'joinedAt': joinedAt?.toIso8601String(),
    'shortNick': shortNick,
    'profileImageB64': profileImageB64,
    'avatarBorderId': avatarBorderId,
    'outgoingOffset': outgoingOffset,
    'outgoingMaxOffset': outgoingMaxOffset,
    'incomingOffset': incomingOffset,
    'incomingMaxOffset': incomingMaxOffset,
    'groupSeed': groupSeed,
    'laneSize': laneSize,
    'totalGroupSize': totalGroupSize,
    'slotIndex': slotIndex,
    'additionalSlots': additionalSlots,
  };

  factory Contact.fromJson(Map<String, dynamic> json) {
    final maxBuffer = json['maxBufferBytes'] as int? ?? 0;
    final remaining = json['remainingBufferBytes'] as int;
    return Contact(
      id: json['id'] as String,
      name: json['name'] as String,
      keyHash: json['keyHash'] as String,
      relayUrl: json['relayUrl'] as String,
      isPrivateNode: json['isPrivateNode'] as bool,
      maxBufferBytes: maxBuffer,
      remainingBufferBytes: remaining,
      peerRemainingBufferBytes:
          json['peerRemainingBufferBytes'] as int? ?? (maxBuffer - remaining),
      lastActivity: DateTime.parse(json['lastActivity'] as String),
      isWilted: json['isWilted'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      isGroup: json['isGroup'] as bool? ?? false,
      memberCount: json['memberCount'] as int?,
      hostName: json['hostName'] as String?,
      isHost: json['isHost'] as bool? ?? false,
      hostKeyHash: json['hostKeyHash'] as String?,
      memberKeyHashes:
          (json['memberKeyHashes'] as List<dynamic>?)?.cast<String>() ?? [],
      groupIconHex: json['groupIconHex'] as String?,
      maxMembers: json['maxMembers'] as int?,
      maxMessageSize: json['maxMessageSize'] as int?,
      imagesAllowed: json['imagesAllowed'] as bool?,
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'] as String)
          : null,
      shortNick: json['shortNick'] as String?,
      profileImageB64: json['profileImageB64'] as String?,
      avatarBorderId: json['avatarBorderId'] as String?,
      outgoingOffset: json['outgoingOffset'] as int? ?? 0,
      outgoingMaxOffset: json['outgoingMaxOffset'] as int? ?? maxBuffer ~/ 2,
      incomingOffset: json['incomingOffset'] as int? ?? maxBuffer ~/ 2,
      incomingMaxOffset: json['incomingMaxOffset'] as int? ?? maxBuffer,
      groupSeed: json['groupSeed'] as String?,
      laneSize: json['laneSize'] as int?,
      totalGroupSize: json['totalGroupSize'] as int?,
      slotIndex: json['slotIndex'] as int?,
      additionalSlots:
          (json['additionalSlots'] as List<dynamic>?)?.cast<int>() ?? [],
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  String text; // Ciphertext (Base64) when encrypted; empty while pending
  final String contentType; // 'text', 'image'
  final DateTime timestamp;
  final bool isSentByMe;
  int
  offset; // Keystream offset used for encryption (set on finalize when sending)
  bool isFailed;
  bool isDelivered;
  // True between the instant the bubble is shown and encryption/send completing.
  // In-memory only — a message is never persisted while still pending.
  bool isPending;
  Uint8List? decodedImageBytes;
  // Sender opt-in: whether the recipient may save/download this image to their
  // gallery. Rides as frame metadata (`dl`), NOT baked into the image bytes, so
  // rendering stays backward compatible. Absent on legacy/older-peer images →
  // defaults false (treat as non-downloadable).
  final bool allowSave;
  // Reply target: the (cross-peer-stable) id of the message this one quotes, or
  // null for a normal message. Immutable content metadata — rides the message
  // envelope as `re` (like `dl`/`eph`), threaded through send/inbound/resync/DB.
  // The quoted preview is rendered from the locally-stored parent, so only the id
  // travels. See [MessageBubble] reply rendering.
  final String? replyToId;
  // In-memory decoded voice payload (VoiceHeader + container'd audio), set when a
  // 'voice' message is sent or its ciphertext is decrypted. Never persisted (the
  // DB keeps the base64 ciphertext in `text`, like images).
  Uint8List? decodedAudioBytes;
  String? decryptedText; // In-memory cached decrypted plaintext

  // Emoji reactions: token -> set of reactor identity ids (userId for us, the
  // sender's keyHash for others). Token is a unicode emoji or a `:name:` custom
  // emoji ref. Mutable side-metadata synced over the AES meta channel (NOT the
  // OTP append log), so — unlike the ciphertext — a persisted message can change.
  Map<String, Set<String>> reactions;

  // --- Wilting (disappearing) messages ---------------------------------------
  // A wilting message carries only its *config* on the wire (`eph`, `ttl`); the
  // timing is resolved on the RECIPIENT's device. It reveals behind a tap, runs a
  // countdown once opened, then "wilts": its stored ciphertext is destroyed
  // in-place. Cooperative (like all disappearing messages) — a peer can't be
  // cryptographically forced to wilt — but FLAG_SECURE + consensual screenshots
  // close the usual retention routes. See [AppStateWilting].
  //
  // Wire (OTP envelope): eph=1, ttl=<seconds>. Everything below is LOCAL state.
  final bool ephemeral; // is this a wilting message
  final int ttlSeconds; // configured lifetime once opened (1..60)
  int? openedAt; // epoch ms of first reveal (recipient) — null until opened
  int? expiresAt; // epoch ms it wilts (openedAt + ttl*1000)
  bool wilted; // true once destroyed; content columns are then blanked
  // Sender-side confirmation that peers have wilted their copy: reactor identity
  // ids (keyHash) who reported wilt. 1:1 → the single peer; group → "n/m wilted".
  // Synced over the AES meta channel, like [reactions].
  Set<String> wiltedBy;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.contentType = 'text',
    required this.timestamp,
    required this.isSentByMe,
    this.offset = 0,
    this.isFailed = false,
    this.isDelivered = false,
    this.isPending = false,
    this.decodedImageBytes,
    this.allowSave = false,
    this.replyToId,
    this.decodedAudioBytes,
    this.decryptedText,
    Map<String, Set<String>>? reactions,
    this.ephemeral = false,
    this.ttlSeconds = 0,
    this.openedAt,
    this.expiresAt,
    this.wilted = false,
    Set<String>? wiltedBy,
  }) : reactions = reactions ?? {},
       wiltedBy = wiltedBy ?? {};

  bool get isSystem =>
      senderId == 'system' ||
      text.startsWith('Connected. Chat session secure.');

  bool get hasReactions => reactions.isNotEmpty;

  /// Reply framing lives in the OTP-encrypted body (never the relay-visible
  /// envelope), so the reply relationship never leaves the pad — at the cost of a
  /// few extra pad bytes. A reply body is `<DELIM><parentId><DELIM><text>`; a normal
  /// body is unchanged. The delimiter is the SOH control byte (U+0001), chosen
  /// because it never occurs in real text or base64 image/voice payloads.
  ///
  /// ⚠️ Stickers ([kStickerMarker] = `\x01stk\x01…`) predate this feature and are
  /// wrapped in the SAME SOH byte, so [parseReplyBody] must explicitly exclude a
  /// sticker body — otherwise a plain sticker is mis-read as a reply to a phantom
  /// parent `"stk"` on the recipient (the sender never re-parses its own body, so
  /// only the recipient saw the bogus quote).
  static final String _replyDelim = String.fromCharCode(1);

  static String buildReplyBody(String? replyToId, String text) => replyToId == null
      ? text
      : '$_replyDelim$replyToId$_replyDelim$text';

  /// Inverse of [buildReplyBody]: returns (parentId, strippedText), or (null, body)
  /// when there's no reply header.
  static (String?, String) parseReplyBody(String body) {
    if (body.isEmpty || body.codeUnitAt(0) != 1) return (null, body);
    // A sticker shares the SOH sentinel but is NOT a reply — leave it whole so it
    // still renders as a sticker (see the delimiter note above).
    if (stickerPayload(body) != null) return (null, body);
    final end = body.indexOf(_replyDelim, 1);
    if (end < 1) return (null, body);
    return (body.substring(1, end), body.substring(end + 1));
  }

  /// A live wilting message (ephemeral and not yet destroyed).
  bool get isWilting => ephemeral && !wilted;

  /// True once an opened wilting message has passed its expiry instant. Unopened
  /// messages (openedAt/expiresAt null) never report expired — they persist until
  /// the recipient taps to reveal them.
  bool get isExpired {
    final e = expiresAt;
    return ephemeral && !wilted && e != null && DateTime.now().millisecondsSinceEpoch >= e;
  }

  /// Destroy this message's content *in memory* (the DB row is blanked separately
  /// via [WiltkeyDatabase.wiltMessageRow]). Irreversible: the plaintext/ciphertext
  /// and any decoded media are dropped and the pad offset is scrambled so a
  /// wilted row can't be re-derived from a retained pad.
  void wiltInMemory() {
    wilted = true;
    text = '';
    decryptedText = null;
    decodedImageBytes = null;
    decodedAudioBytes = null;
    offset = -1;
  }

  /// Serialise [reactions] (sets → lists) to a JSON string, or null if empty.
  /// Used for the DB `reactions` column.
  static String? encodeReactions(Map<String, Set<String>> r) {
    if (r.isEmpty) return null;
    return jsonEncode(r.map((k, v) => MapEntry(k, v.toList())));
  }

  /// Inverse of [encodeReactions]; tolerant of null/garbage (→ empty map).
  static Map<String, Set<String>> decodeReactions(String? s) {
    if (s == null || s.isEmpty) return {};
    try {
      final raw = jsonDecode(s) as Map<String, dynamic>;
      return raw.map(
        (k, v) => MapEntry(k, {...(v as List).map((e) => e.toString())}),
      );
    } catch (_) {
      return {};
    }
  }

  String? get reactionsJson => encodeReactions(reactions);

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'text': text,
    'contentType': contentType,
    'timestamp': timestamp.toIso8601String(),
    'isSentByMe': isSentByMe,
    'offset': offset,
    'isDelivered': isDelivered,
    if (allowSave) 'allowSave': allowSave,
    if (replyToId != null) 'replyToId': replyToId,
    if (reactions.isNotEmpty)
      'reactions': reactions.map((k, v) => MapEntry(k, v.toList())),
    if (ephemeral) 'ephemeral': true,
    if (ephemeral) 'ttlSeconds': ttlSeconds,
    if (openedAt != null) 'openedAt': openedAt,
    if (expiresAt != null) 'expiresAt': expiresAt,
    if (wilted) 'wilted': true,
    if (wiltedBy.isNotEmpty) 'wiltedBy': wiltedBy.toList(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String;
    final senderId = json['senderId'] as String;
    final contentType = json['contentType'] as String? ?? 'text';
    final offset = json['offset'] as int? ?? 0;

    final isSystem =
        senderId == 'system' ||
        text.startsWith('Connected. Chat session secure.');

    return ChatMessage(
      id: json['id'] as String,
      senderId: senderId,
      text: text,
      contentType: contentType,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSentByMe: json['isSentByMe'] as bool,
      offset: offset,
      isDelivered: json['isDelivered'] as bool? ?? false,
      allowSave: json['allowSave'] as bool? ?? false,
      replyToId: json['replyToId'] as String?,
      decryptedText: isSystem ? text : null,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, {...(v as List).map((e) => e.toString())}),
      ),
      ephemeral: json['ephemeral'] as bool? ?? false,
      ttlSeconds: json['ttlSeconds'] as int? ?? 0,
      openedAt: json['openedAt'] as int?,
      expiresAt: json['expiresAt'] as int?,
      wilted: json['wilted'] as bool? ?? false,
      wiltedBy: (json['wiltedBy'] as List?)
          ?.map((e) => e.toString())
          .toSet(),
    );
  }
}
