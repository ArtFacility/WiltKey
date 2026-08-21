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
  bool isPendingEmergency; // True while waiting for peer to ack emergency chat request
  String notificationMode; // 'all', 'mentions_only', 'muted'

  bool get isMuted => notificationMode == 'muted';
  bool get isMentionsOnly => notificationMode == 'mentions_only';

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
  String? themeId; // Peer's active theme id (e.g. cyberpunk, garden, paperink)
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

  // Group Time Wilt: the group's configured lifetime in seconds. Non-null marks
  // a Time Wilt GROUP (the per-member model means the host stores no personal
  // [wiltExpiresAt], so this — not [wiltExpiresAt] — is the group's Time Wilt
  // marker). The host persists it to stamp every invite/re-meet with the same
  // lifetime; each member also stores it (for display) and derives its own
  // [wiltExpiresAt] = whenTheyMetHost + lifetime.
  int? groupWiltLifetimeSecs;

  bool get isTimeWilt => wiltExpiresAt != null || groupWiltLifetimeSecs != null;

  /// True for the host of a Time Wilt group. The host is "infinite" — it renders
  /// ∞ rather than a personal countdown, and only greys out once every member
  /// has wilted (tracked via the host's hidden [wiltExpiresAt] = latest-meet +
  /// lifetime, bumped on every register/re-meet).
  bool get isTimeWiltGroupHost =>
      isGroup && isHost && groupWiltLifetimeSecs != null;

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
  String get timeWiltCountdownLabel => formatWiltCountdown(wiltExpiresAt);

  /// Same compact form as [timeWiltCountdownLabel] but for an ARBITRARY expiry —
  /// used to render another group member's remaining time in the roster (their
  /// clock is broadcast by the host, not stored on our own contact). Returns ''
  /// for a null expiry and 'Wilted' once it's in the past.
  static String formatWiltCountdown(DateTime? end) {
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
    this.themeId,
    this.avatarBorderId,
    this.outgoingOffset = 0,
    this.outgoingMaxOffset = 0,
    this.incomingOffset = 0,
    this.incomingMaxOffset = 0,
    this.wiltExpiresAt,
    this.streamSeedHex,
    this.wiltCreatedAt,
    this.groupWiltLifetimeSecs,
    this.groupSeed,
    this.laneSize,
    this.totalGroupSize,
    this.slotIndex,
    List<int> additionalSlots = const [],
    this.groupRechargePending = false,
    this.isPendingEmergency = false,
    this.notificationMode = 'all',
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
    String? themeId,
    String? avatarBorderId,
    int? outgoingOffset,
    int? outgoingMaxOffset,
    int? incomingOffset,
    int? incomingMaxOffset,
    DateTime? wiltExpiresAt,
    String? streamSeedHex,
    DateTime? wiltCreatedAt,
    int? groupWiltLifetimeSecs,
    String? groupSeed,
    int? laneSize,
    int? totalGroupSize,
    int? slotIndex,
    List<int>? additionalSlots,
    bool? groupRechargePending,
    bool? isPendingEmergency,
    String? notificationMode,
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
      themeId: themeId ?? this.themeId,
      avatarBorderId: avatarBorderId ?? this.avatarBorderId,
      outgoingOffset: outgoingOffset ?? this.outgoingOffset,
      outgoingMaxOffset: outgoingMaxOffset ?? this.outgoingMaxOffset,
      incomingOffset: incomingOffset ?? this.incomingOffset,
      incomingMaxOffset: incomingMaxOffset ?? this.incomingMaxOffset,
      wiltExpiresAt: wiltExpiresAt ?? this.wiltExpiresAt,
      streamSeedHex: streamSeedHex ?? this.streamSeedHex,
      wiltCreatedAt: wiltCreatedAt ?? this.wiltCreatedAt,
      groupWiltLifetimeSecs:
          groupWiltLifetimeSecs ?? this.groupWiltLifetimeSecs,
      groupSeed: groupSeed ?? this.groupSeed,
      laneSize: laneSize ?? this.laneSize,
      totalGroupSize: totalGroupSize ?? this.totalGroupSize,
      slotIndex: slotIndex ?? this.slotIndex,
      additionalSlots: additionalSlots ?? this.additionalSlots,
      groupRechargePending: groupRechargePending ?? this.groupRechargePending,
      isPendingEmergency: isPendingEmergency ?? this.isPendingEmergency,
      notificationMode: notificationMode ?? this.notificationMode,
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
    'themeId': themeId,
    'avatarBorderId': avatarBorderId,
    'outgoingOffset': outgoingOffset,
    'outgoingMaxOffset': outgoingMaxOffset,
    'incomingOffset': incomingOffset,
    'incomingMaxOffset': incomingMaxOffset,
    'wiltExpiresAt': wiltExpiresAt?.toIso8601String(),
    'streamSeedHex': streamSeedHex,
    'wiltCreatedAt': wiltCreatedAt?.toIso8601String(),
    'groupWiltLifetimeSecs': groupWiltLifetimeSecs,
    'groupSeed': groupSeed,
    'laneSize': laneSize,
    'totalGroupSize': totalGroupSize,
    'slotIndex': slotIndex,
    'additionalSlots': additionalSlots,
    'groupRechargePending': groupRechargePending,
    'isPendingEmergency': isPendingEmergency,
    'notificationMode': notificationMode,
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
      themeId: json['themeId'] as String?,
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
      groupWiltLifetimeSecs: json['groupWiltLifetimeSecs'] as int?,
      groupSeed: json['groupSeed'] as String?,
      laneSize: json['laneSize'] as int?,
      totalGroupSize: json['totalGroupSize'] as int?,
      slotIndex: json['slotIndex'] as int?,
      additionalSlots:
          (json['additionalSlots'] as List<dynamic>?)?.cast<int>() ?? [],
      groupRechargePending: json['groupRechargePending'] as bool? ?? false,
      isPendingEmergency: json['isPendingEmergency'] as bool? ?? false,
      notificationMode: json['notificationMode'] as String? ?? 'all',
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

  // --- Message Editing & Deletion --------------------------------------------
  // Edits/deletions ride as new messages advancing the keystream offset (no crypto
  // reuse). An edit frame carries `editTargetId` pointing to the original message;
  // once applied, the original row sets `isEdited = true` and `editedAt = timestamp`.
  // A delete frame marks `isDeleted = true` and wipes local media/ciphertext.
  bool isEdited;
  String? editTargetId;
  int? editedAt;
  bool isDeleted;

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
    this.isEdited = false,
    this.editTargetId,
    this.editedAt,
    this.isDeleted = false,
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

  // --- Edit & Delete Body Framing --------------------------------------------
  // Delimiter `\x02` (STX) is used for edit and delete commands inside the OTP body.
  // Format: `\x02e\x02<targetId>\x02<newText>` or `\x02d\x02<targetId>\x02`
  static const String _editPrefix = '\x02e\x02';
  static const String _deletePrefix = '\x02d\x02';
  static const String _editDelim = '\x02';

  static String buildEditBody(String targetId, String newText) =>
      '$_editPrefix$targetId$_editDelim$newText';

  static String buildDeleteBody(String targetId) =>
      '$_deletePrefix$targetId$_editDelim';

  static ({String? editTargetId, String? deleteTargetId, String text}) parseEditOrDelete(
    String body,
  ) {
    if (body.startsWith(_editPrefix)) {
      final rest = body.substring(_editPrefix.length);
      final delimIdx = rest.indexOf(_editDelim);
      if (delimIdx != -1) {
        final targetId = rest.substring(0, delimIdx);
        final newText = rest.substring(delimIdx + 1);
        return (editTargetId: targetId, deleteTargetId: null, text: newText);
      }
    } else if (body.startsWith(_deletePrefix)) {
      final rest = body.substring(_deletePrefix.length);
      final delimIdx = rest.indexOf(_editDelim);
      final targetId = delimIdx != -1 ? rest.substring(0, delimIdx) : rest;
      return (editTargetId: null, deleteTargetId: targetId, text: '');
    }
    return (editTargetId: null, deleteTargetId: null, text: body);
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

  /// Mark message as deleted in memory.
  void deleteInMemory() {
    isDeleted = true;
    text = '';
    decryptedText = '[Message deleted]';
    decodedImageBytes = null;
    decodedAudioBytes = null;
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
    if (isEdited) 'isEdited': true,
    if (editTargetId != null) 'editTargetId': editTargetId,
    if (editedAt != null) 'editedAt': editedAt,
    if (isDeleted) 'isDeleted': true,
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
      isEdited: json['isEdited'] as bool? ?? false,
      editTargetId: json['editTargetId'] as String?,
      editedAt: json['editedAt'] as int?,
      isDeleted: json['isDeleted'] as bool? ?? false,
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

/// A social contact (friend) — independent of chat contacts.
/// Established via mutual contact request over an existing 1-on-1 chat.
/// The [sharedSecretSeed] = sha256(sorted(myKeyHash + peerKeyHash)) is the
/// single source of truth for all derived peer-to-peer content (theme,
/// stories, etc.). Derives from the two key hashes (not raw pubkeys) so both
/// sides compute an identical seed — see `_deriveSharedSecretSeed`.
class SocialContact {
  final int id;
  final String keyHash; // Peer's identity hash (64-char hex)
  final String name;
  final String? shortNick;
  final String? profileImageB64;
  final String? avatarBorderId;
  final String? themeId; // Peer's active theme id
  final String sharedSecretSeed;
  final String myPubkey;
  final String peerPubkey;
  final int addedAt; // Unix millis
  final bool isBlocked;
  final String? themeSeed; // Derived: sha256(sharedSecretSeed + "theme")
  final int? lastSyncedAt;
  final bool isPinned;
  final String? status; // Peer's synced status message
  final String? statusEmoji; // Peer's synced status emoji
  final int? statusExpiresAt; // Unix timestamp in ms when status expires

  SocialContact({
    required this.id,
    required this.keyHash,
    required this.name,
    this.shortNick,
    this.profileImageB64,
    this.avatarBorderId,
    this.themeId,
    required this.sharedSecretSeed,
    required this.myPubkey,
    required this.peerPubkey,
    required this.addedAt,
    this.isBlocked = false,
    this.themeSeed,
    this.lastSyncedAt,
    this.isPinned = false,
    this.status,
    this.statusEmoji,
    this.statusExpiresAt,
  });

  bool get isStatusExpired =>
      statusExpiresAt != null &&
      statusExpiresAt! > 0 &&
      DateTime.now().millisecondsSinceEpoch > statusExpiresAt!;

  String? get activeStatus => isStatusExpired ? null : status;
  String? get activeStatusEmoji => isStatusExpired ? null : statusEmoji;

  factory SocialContact.fromRow(Map<String, dynamic> row) => SocialContact(
    id: row['id'] as int,
    keyHash: row['key_hash'] as String,
    name: row['name'] as String,
    shortNick: row['short_nick'] as String?,
    profileImageB64: row['profile_image_b64'] as String?,
    avatarBorderId: row['avatar_border_id'] as String?,
    themeId: row['theme_id'] as String?,
    sharedSecretSeed: row['shared_secret_seed'] as String,
    myPubkey: row['my_pubkey'] as String,
    peerPubkey: row['peer_pubkey'] as String,
    addedAt: row['added_at'] as int,
    isBlocked: (row['is_blocked'] as int? ?? 0) == 1,
    themeSeed: row['theme_seed'] as String?,
    lastSyncedAt: row['last_synced_at'] as int?,
    isPinned: (row['is_pinned'] as int? ?? 0) == 1,
    status: row['status'] as String?,
    statusEmoji: row['status_emoji'] as String?,
    statusExpiresAt: row['status_expires_at'] as int?,
  );

  Map<String, Object?> toRow() => {
    'key_hash': keyHash,
    'name': name,
    'short_nick': shortNick,
    'profile_image_b64': profileImageB64,
    'avatar_border_id': avatarBorderId,
    'theme_id': themeId,
    'shared_secret_seed': sharedSecretSeed,
    'my_pubkey': myPubkey,
    'peer_pubkey': peerPubkey,
    'added_at': addedAt,
    'is_blocked': isBlocked ? 1 : 0,
    'theme_seed': themeSeed,
    'last_synced_at': lastSyncedAt,
    'is_pinned': isPinned ? 1 : 0,
    'status': status,
    'status_emoji': statusEmoji,
    'status_expires_at': statusExpiresAt,
  };

  /// Derives the theme seed from the shared secret (lazy, cached in DB).
  String getOrCreateThemeSeed() {
    if (themeSeed != null) return themeSeed!;
    // sha256(sharedSecretSeed + "theme")
    // Note: actual computation done in Dart when needed, stored back to DB.
    return '';
  }
}

/// A locally-blocked peer — inbound contact requests are silently dropped.
class ContactBlock {
  final int id;
  final String keyHash;
  final int blockedAt;
  final String? reason;

  ContactBlock({
    required this.id,
    required this.keyHash,
    required this.blockedAt,
    this.reason,
  });

  factory ContactBlock.fromRow(Map<String, dynamic> row) => ContactBlock(
    id: row['id'] as int,
    keyHash: row['key_hash'] as String,
    blockedAt: row['blocked_at'] as int,
    reason: row['reason'] as String?,
  );

  Map<String, Object?> toRow() => {
    'key_hash': keyHash,
    'blocked_at': blockedAt,
    'reason': reason,
  };
}
