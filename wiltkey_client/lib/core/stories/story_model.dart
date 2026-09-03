import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Represents a 24-hour Wilting Story post.
class Story {
  final String id;
  final String senderId;
  final String storyType; // 'text', 'photo', 'pixel_art'
  final String content; // Plaintext, hex string for pixel art, or base64 WebP for photo
  final String? bucketUrl;
  final String mediaMeta;
  final String? themeId;
  final String? caption;
  final String? textBorderId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int bytesUsed;
  final List<StoryReaction> reactions;
  final bool isViewed;
  final bool isMine;

  const Story({
    required this.id,
    required this.senderId,
    required this.storyType,
    required this.content,
    this.bucketUrl,
    this.mediaMeta = '',
    this.themeId,
    this.caption,
    this.textBorderId,
    required this.createdAt,
    required this.expiresAt,
    required this.bytesUsed,
    this.reactions = const [],
    this.isViewed = false,
    this.isMine = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  double get remainingProgress {
    final total = expiresAt.difference(createdAt).inSeconds;
    if (total <= 0) return 0.0;
    final left = expiresAt.difference(DateTime.now()).inSeconds;
    return (left / total).clamp(0.0, 1.0);
  }

  String get remainingTimeLabel {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return '${diff.inSeconds}s';
  }

  Story copyWith({
    String? id,
    String? senderId,
    String? storyType,
    String? content,
    String? bucketUrl,
    String? mediaMeta,
    String? themeId,
    String? caption,
    String? textBorderId,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? bytesUsed,
    List<StoryReaction>? reactions,
    bool? isViewed,
    bool? isMine,
  }) {
    return Story(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      storyType: storyType ?? this.storyType,
      content: content ?? this.content,
      bucketUrl: bucketUrl ?? this.bucketUrl,
      mediaMeta: mediaMeta ?? this.mediaMeta,
      themeId: themeId ?? this.themeId,
      caption: caption ?? this.caption,
      textBorderId: textBorderId ?? this.textBorderId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      bytesUsed: bytesUsed ?? this.bytesUsed,
      reactions: reactions ?? this.reactions,
      isViewed: isViewed ?? this.isViewed,
      isMine: isMine ?? this.isMine,
    );
  }
}

/// A reaction left on a story.
class StoryReaction {
  final String id;
  final String storyId;
  final String reactorId;
  final String emoji;
  final DateTime createdAt;

  const StoryReaction({
    required this.id,
    required this.storyId,
    required this.reactorId,
    required this.emoji,
    required this.createdAt,
  });

  factory StoryReaction.fromJson(Map<String, dynamic> json) {
    return StoryReaction(
      id: json['id'] as String? ?? '',
      storyId: json['story_id'] as String? ?? '',
      reactorId: json['reactor_id'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '❤️',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'story_id': storyId,
    'reactor_id': reactorId,
    'emoji': emoji,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Tracks weekly budget information authoritative from relay server.
class SocialBudgetInfo {
  final String userId;
  final int bytesUsed;
  final int maxBytes;
  final bool isPlus;
  final DateTime weekStart;
  final int resetInSeconds;

  const SocialBudgetInfo({
    required this.userId,
    required this.bytesUsed,
    required this.maxBytes,
    required this.isPlus,
    required this.weekStart,
    required this.resetInSeconds,
  });

  factory SocialBudgetInfo.fromJson(Map<String, dynamic> json) {
    DateTime parsedWeekStart = DateTime.now();
    final rawWeekStart = json['week_start'];
    if (rawWeekStart is num) {
      parsedWeekStart = DateTime.fromMillisecondsSinceEpoch(rawWeekStart.toInt() * 1000);
    } else if (rawWeekStart is String) {
      final parsedInt = int.tryParse(rawWeekStart);
      if (parsedInt != null) {
        parsedWeekStart = DateTime.fromMillisecondsSinceEpoch(parsedInt * 1000);
      } else {
        parsedWeekStart = DateTime.tryParse(rawWeekStart) ?? DateTime.now();
      }
    }

    return SocialBudgetInfo(
      userId: json['user_id'] as String? ?? '',
      bytesUsed: (json['bytes_used'] as num?)?.toInt() ?? 0,
      maxBytes: (json['max_bytes'] as num?)?.toInt() ?? (10 * 1024 * 1024),
      isPlus: json['is_plus'] as bool? ?? false,
      weekStart: parsedWeekStart,
      resetInSeconds: (json['reset_in_seconds'] as num?)?.toInt() ?? (7 * 24 * 3600),
    );
  }

  double get usedFraction => maxBytes > 0 ? (bytesUsed / maxBytes).clamp(0.0, 1.0) : 0.0;
  int get remainingBytes => (maxBytes - bytesUsed).clamp(0, maxBytes);
  String get usedMbFormatted => (bytesUsed / (1024 * 1024)).toStringAsFixed(1);
  String get maxMbFormatted => (maxBytes / (1024 * 1024)).toStringAsFixed(0);
  String get remainingMbFormatted => (remainingBytes / (1024 * 1024)).toStringAsFixed(1);
}
