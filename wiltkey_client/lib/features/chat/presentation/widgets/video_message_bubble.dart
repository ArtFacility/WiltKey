import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:wiltkey_client/core/db/wiltkey_db.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/theme/wk.dart';
import 'package:wiltkey_client/core/video/video_message_service.dart';
import 'video_player_modal.dart';

/// Fixed-size, lazily-loaded video message bubble.
/// Displays the WebP keyframe thumbnail with a play icon and duration badge.
/// Tapping opens [WkVideoPlayerModal].
class VideoMessageBubble extends StatefulWidget {
  final AppState appState;
  final Contact contact;
  final ChatMessage message;
  final double width;
  final double height;

  const VideoMessageBubble({
    super.key,
    required this.appState,
    required this.contact,
    required this.message,
    this.width = 232,
    this.height = 260,
  });

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  Uint8List? _thumbBytes;
  VideoMessagePayload? _payload;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VideoMessageBubble old) {
    super.didUpdateWidget(old);
    if (old.message.id != widget.message.id) {
      _thumbBytes = null;
      _payload = null;
      _loading = true;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    // 1. Check in-memory cached thumbnail
    if (widget.message.decodedVideoThumbnail != null) {
      setState(() {
        _thumbBytes = widget.message.decodedVideoThumbnail;
        _loading = false;
      });
      return;
    }

    // 2. If decryptedText is available in memory
    final dt = widget.message.decryptedText;
    if (dt != null && dt.isNotEmpty) {
      final payload = VideoMessagePayload.tryParse(dt);
      if (payload != null) {
        _payload = payload;
        widget.message.decodedVideoThumbnail = payload.thumbnailBytes;
        if (mounted) {
          setState(() {
            _thumbBytes = payload.thumbnailBytes;
            _loading = false;
          });
        }
        return;
      }
    }

    // 3. Lazy DB load
    try {
      final raw = await WiltkeyDatabase.instance.loadMessagePayloadString(
        widget.contact.keyHash,
        widget.message.id,
        masterKeyHex: widget.appState.masterKeyHex,
      );

      if (raw != null && raw.isNotEmpty) {
        final payload = VideoMessagePayload.tryParse(raw);
        if (payload != null) {
          _payload = payload;
          widget.message.decodedVideoThumbnail = payload.thumbnailBytes;
          if (mounted) {
            setState(() {
              _thumbBytes = payload.thumbnailBytes;
              _loading = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _openPlayer() async {
    VideoMessagePayload? p = _payload;
    if (p == null) {
      final dt = widget.message.decryptedText ??
          await WiltkeyDatabase.instance.loadMessagePayloadString(
            widget.contact.keyHash,
            widget.message.id,
            masterKeyHex: widget.appState.masterKeyHex,
          );
      if (dt != null) {
        p = VideoMessagePayload.tryParse(dt);
        _payload = p;
      }
    }

    if (p == null || !mounted) return;

    File? localFile;
    if (widget.message.cachedVideoPath != null) {
      final f = File(widget.message.cachedVideoPath!);
      if (await f.exists()) localFile = f;
    }

    await WkVideoPlayerModal.show(
      context,
      message: widget.message,
      payload: p,
      localFile: localFile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;

    return GestureDetector(
      onTap: _openPlayer,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusControl),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail background
              if (_thumbBytes != null && _thumbBytes!.isNotEmpty)
                Image.memory(
                  _thumbBytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              else if (_loading)
                Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(t.action),
                    ),
                  ),
                )
              else if (_failed)
                Center(
                  child: Icon(Icons.broken_image_outlined, color: t.textTertiary, size: 36),
                )
              else
                Container(color: Colors.black26),

              // Gradient shadow
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black54,
                    ],
                  ),
                ),
              ),

              // Play Button Overlay
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),

              // Duration Badge
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(t.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        _payload != null
                            ? VideoMessageService.formatDurationMs(_payload!.durationMs)
                            : 'Video',
                        style: t.dataMono.copyWith(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
