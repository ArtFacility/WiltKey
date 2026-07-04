import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

import '../../../../core/audio/voice_codec.dart';
import '../../../../core/models.dart';
import '../../../../core/theme/wk.dart';

/// Inline voice-note player for a chat bubble. Unwraps the [VoiceHeader] from the
/// decoded payload for its duration up front, and lazily writes the audio to a
/// temp file + loads `just_audio` on the first play (so scrolling past many voice
/// bubbles doesn't spin up a decoder for each). The scrubber itself is the theme's
/// [WiltkeyComponents.voiceScrubber] so playback looks native per theme.
class VoiceMessagePlayer extends StatefulWidget {
  final ChatMessage message;

  /// Tint (e.g. the sender's identity colour in groups); defaults to `action`.
  final Color? accent;

  const VoiceMessagePlayer({super.key, required this.message, this.accent});

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  AudioPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _headerOk = false; // parsed a valid header (can render controls)
  bool _loading = false; // audio source being set up
  bool _loaded = false; // audio source ready
  bool _error = false;
  String? _tempPath;

  @override
  void initState() {
    super.initState();
    _parseHeader();
  }

  @override
  void didUpdateWidget(VoiceMessagePlayer old) {
    super.didUpdateWidget(old);
    // A late decrypt can swap decodedAudioBytes in after the first build.
    if (!_headerOk &&
        !_error &&
        old.message.decodedAudioBytes == null &&
        widget.message.decodedAudioBytes != null) {
      _parseHeader();
    }
  }

  void _parseHeader() {
    final bytes = widget.message.decodedAudioBytes;
    if (bytes == null) return; // not decrypted yet; didUpdateWidget retries
    final parsed = VoiceHeader.unwrap(bytes);
    if (parsed == null) {
      if (mounted) setState(() => _error = true);
      return;
    }
    if (mounted) {
      setState(() {
        _duration = parsed.header.duration;
        _headerOk = true;
      });
    }
  }

  Future<bool> _ensureLoaded() async {
    if (_loaded) return true;
    if (_loading) return false;
    final bytes = widget.message.decodedAudioBytes;
    if (bytes == null) return false;
    final parsed = VoiceHeader.unwrap(bytes);
    if (parsed == null) {
      if (mounted) setState(() => _error = true);
      return false;
    }
    setState(() => _loading = true);
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/wk_play_${widget.message.id.hashCode}.${parsed.header.codec.fileExtension}';
      await File(path).writeAsBytes(parsed.audio, flush: true);
      _tempPath = path;

      final player = AudioPlayer();
      _player = player;
      final probed = await player.setFilePath(path);
      if (probed != null && probed > Duration.zero) _duration = probed;

      _posSub = player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _stateSub = player.playerStateStream.listen((s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          player.pause();
          player.seek(Duration.zero);
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
        } else {
          setState(() => _playing = s.playing);
        }
      });
      if (mounted) setState(() => _loaded = true);
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = true);
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    final p = _tempPath;
    if (p != null) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_headerOk) return;
    if (!_loaded) {
      final ok = await _ensureLoaded();
      if (!ok) return;
    }
    final player = _player;
    if (player == null) return;
    if (_playing) {
      player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        player.seek(Duration.zero);
      }
      player.play();
    }
  }

  void _seekFraction(double f) {
    if (!_loaded || _duration <= Duration.zero) return;
    _player?.seek(_duration * f);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final accent = widget.accent ?? t.action;

    if (_error) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_off_outlined, size: 16, color: t.textTertiary),
          const SizedBox(width: 6),
          Text(l10n.chatVoiceUnavailable, style: t.bodySecondary),
        ],
      );
    }

    final total = _duration.inMilliseconds;
    final progress = total > 0
        ? (_position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    // Elapsed while playing / scrubbed, otherwise the full length.
    final shown = (_playing || _position > Duration.zero)
        ? _position
        : _duration;

    final IconData icon;
    if (_loading) {
      icon = Icons.hourglass_empty;
    } else if (_playing) {
      icon = Icons.pause;
    } else {
      icon = Icons.play_arrow;
    }

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Icon(icon, color: t.onAction, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                context.wkc.voiceScrubber(
                  progress: progress,
                  isPlaying: _playing,
                  seed: widget.message.id.hashCode,
                  accent: accent,
                  onSeek: _seekFraction,
                ),
                const SizedBox(height: 2),
                Text(
                  _fmt(shown),
                  style: t.dataMono.copyWith(
                    color: t.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
