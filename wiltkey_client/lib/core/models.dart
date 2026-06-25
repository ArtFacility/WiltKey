import 'dart:typed_data';

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
  String? decryptedText; // In-memory cached decrypted plaintext

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
    this.decryptedText,
  });

  bool get isSystem =>
      senderId == 'system' ||
      text.startsWith('Connected. Chat session secure.');

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'text': text,
    'contentType': contentType,
    'timestamp': timestamp.toIso8601String(),
    'isSentByMe': isSentByMe,
    'offset': offset,
    'isDelivered': isDelivered,
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
      decryptedText: isSystem ? text : null,
    );
  }
}
