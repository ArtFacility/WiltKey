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

  // A member's group needs a re-meet: the host recharged (reseeded) the group,
  // so this member's old lane/seed is dead — sending would go into the void.
  // Set by the inbound `group_recharge_needed` signal, cleared when the member
  // re-meets the host. Locks the composer to a "meet the host again" prompt.
  bool groupRechargePending;

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

  // Time Wilt: a chat with a lifetime rather than a byte budget.
  // [wiltExpiresAt] is the negotiated ABSOLUTE expiry — the initiator computes
  // it at pairing and both sides store the same instant verbatim, so clock skew
  // can't make one side archive before the other. Non-null is what marks this a
  // Time Wilt chat. At expiry the chat flips to [isArchived] (read-only).
  // [streamSeedHex] is the on-demand keystream seed: 1:1 Time Wilt keeps no
  // stored pad (it derives keystream from the seed like groups do), so unlike
  // byte-budget 1:1 the seed must persist here.
  DateTime? wiltExpiresAt;
  String? streamSeedHex;
  // When the Time Wilt chat was created locally — the other end of the lifetime
  // span, so the budget gauge can render fraction-of-lifetime-remaining. Local
  // (not negotiated): only the EXPIRY needs to match across devices; this is a
  // cosmetic denominator, so a few seconds of skew is irrelevant.
  DateTime? wiltCreatedAt;

  bool get isTimeWilt => wiltExpiresAt != null;

  /// Fraction of the Time Wilt lifetime still remaining (1.0 fresh → 0.0 spent),
  /// for the reused budget gauge. 0 for non-Time-Wilt or once expired.
  double get timeWiltRemainingFraction {
    final start = wiltCreatedAt;
    final end = wiltExpiresAt;
    if (start == null || end == null) return 0.0;
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0.0;
    final left = end.difference(DateTime.now()).inSeconds;
    return (left / total).clamp(0.0, 1.0);
  }

  /// Compact remaining-time label for the countdown beside the gauge, e.g.
  /// "6d 4h", "3h 12m", "12m", "9m 45s", "30s", or "Wilted" once expired.
  ///
  /// Below 10 minutes it carries seconds ("9m 45s") so the per-second tickers
  /// (chat + dashboard, which only rebuild inside that same window) actually
  /// paint a changing string — above 10 minutes the coarse form is enough since
  /// nothing ticks it faster than a minute anyway.
  String get timeWiltCountdownLabel {
    final end = wiltExpiresAt;
    if (end == null) return '';
    final d = end.difference(DateTime.now());
    if (d.isNegative || d.inSeconds == 0) return 'Wilted';
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes >= 10) return '${d.inMinutes}m';
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

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
    this.wiltExpiresAt,
    this.streamSeedHex,
    this.wiltCreatedAt,
    this.groupSeed,
    this.laneSize,
    this.totalGroupSize,
    this.slotIndex,
    List<int> additionalSlots = const [],
    this.groupRechargePending = false,
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
    DateTime? wiltExpiresAt,
    String? streamSeedHex,
    DateTime? wiltCreatedAt,
    String? groupSeed,
    int? laneSize,
    int? totalGroupSize,
    int? slotIndex,
    List<int>? additionalSlots,
    bool? groupRechargePending,
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
      wiltExpiresAt: wiltExpiresAt ?? this.wiltExpiresAt,
      streamSeedHex: streamSeedHex ?? this.streamSeedHex,
      wiltCreatedAt: wiltCreatedAt ?? this.wiltCreatedAt,
      groupSeed: groupSeed ?? this.groupSeed,
      laneSize: laneSize ?? this.laneSize,
      totalGroupSize: totalGroupSize ?? this.totalGroupSize,
      slotIndex: slotIndex ?? this.slotIndex,
      additionalSlots: additionalSlots ?? this.additionalSlots,
      groupRechargePending: groupRechargePending ?? this.groupRechargePending,
    );
  }

  // Guarded against maxBufferBytes == 0 (Time Wilt chats carry no byte budget).
  double get chargePercentage =>
      maxBufferBytes == 0 ? 0.0 : remainingBufferBytes / maxBufferBytes;

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
    'wiltExpiresAt': wiltExpiresAt?.toIso8601String(),
    'streamSeedHex': streamSeedHex,
    'wiltCreatedAt': wiltCreatedAt?.toIso8601String(),
    'groupSeed': groupSeed,
    'laneSize': laneSize,
    'totalGroupSize': totalGroupSize,
    'slotIndex': slotIndex,
    'additionalSlots': additionalSlots,
    'groupRechargePending': groupRechargePending,
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
      wiltExpiresAt: json['wiltExpiresAt'] != null
          ? DateTime.parse(json['wiltExpiresAt'] as String)
          : null,
      streamSeedHex: json['streamSeedHex'] as String?,
      wiltCreatedAt: json['wiltCreatedAt'] != null
          ? DateTime.parse(json['wiltCreatedAt'] as String)
          : null,
      groupSeed: json['groupSeed'] as String?,
      laneSize: json['laneSize'] as int?,
      totalGroupSize: json['totalGroupSize'] as int?,
      slotIndex: json['slotIndex'] as int?,
      additionalSlots:
          (json['additionalSlots'] as List<dynamic>?)?.cast<int>() ?? [],
      groupRechargePending: json['groupRechargePending'] as bool? ?? false,
    );
  }
}

/// One entry in the global activity feed (see AppStateEvents). Records things
/// that happened when the user wasn't looking or that have no chat to live in
/// (a nuke that deleted the chat). Stored plaintext locally — wiped by nuke.
class AppEvent {
  final String id;
  final String type; // e.g. 'nuke_received', 'group_recharged', 'kicked'
  final String title;
  final String body;
  final String? chatKey; // deep-link target keyHash, if the chat still exists
  final DateTime timestamp;
  bool read;

  AppEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.chatKey,
    required this.timestamp,
    this.read = false,
  });

  Map<String, Object?> toRow() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'chat_key': chatKey,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'read': read ? 1 : 0,
  };

  factory AppEvent.fromRow(Map<String, dynamic> r) => AppEvent(
    id: r['id'] as String,
    type: r['type'] as String? ?? '',
    title: r['title'] as String? ?? '',
    body: r['body'] as String? ?? '',
    chatKey: r['chat_key'] as String?,
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (r['timestamp'] as int?) ?? 0,
    ),
    read: (r['read'] as int? ?? 0) == 1,
  );
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

  // --- Pending large-file download -------------------------------------------
  // Large payloads (>= the relay's bucket threshold) are no longer pushed down
  // the socket: the relay sends a FILE_OFFER carrying only routing metadata, and
  // the body stays in its bucket until we fetch it and confirm receipt. While
  // [remoteFileId] is set this message is a placeholder — it has no ciphertext
  // and renders as a tap-to-download bubble sized by [remoteSize]. Both fields
  // are cleared once the body has been downloaded, decrypted and stored.
  String? remoteFileId; // relay-side message id to request, null once fetched
  int remoteSize; // advertised envelope size in bytes (for the visual)

  /// True while the body still lives on the relay and hasn't been downloaded.
  bool get isPendingDownload => (remoteFileId?.isNotEmpty ?? false) && !wilted;

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
    this.remoteFileId,
    this.remoteSize = 0,
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
