import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_codec.dart';

/// The bytes + metadata captured from one completed recording.
class VoiceCapture {
  /// The raw, container'd audio (Ogg-Opus or MP4-AAC) — NOT yet header-wrapped.
  final Uint8List bytes;
  final Duration duration;
  final VoiceCodec codec;

  const VoiceCapture({
    required this.bytes,
    required this.duration,
    required this.codec,
  });
}

/// Thin wrapper over the `record` plugin for capturing a single voice note to a
/// private temp file and handing back its bytes. The chat layer wraps those bytes
/// with a [VoiceHeader], base64-encodes, and sends them over the OTP pad exactly
/// like an image attachment. Playback lives elsewhere (just_audio).
///
/// One instance per active recording session; call [dispose] when done.
class VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();
  VoiceCodec? _codec; // cached device capability (never changes at runtime)
  String? _path;
  DateTime? _startedAt;

  /// The best *encodable* codec on this device (Opus where supported, else
  /// AAC-LC). Probed once, then cached.
  Future<VoiceCodec> codec() async => _codec ??= await pickRecordCodec(_rec);

  /// Whether the mic permission is granted; [request] prompts if undecided.
  Future<bool> hasPermission({bool request = true}) =>
      _rec.hasPermission(request: request);

  Future<bool> get isRecording => _rec.isRecording();

  /// dBFS amplitude stream for the live level meter / seeded pseudo-waveform,
  /// sampled every [interval].
  Stream<Amplitude> amplitude([
    Duration interval = const Duration(milliseconds: 120),
  ]) => _rec.onAmplitudeChanged(interval);

  /// Begin recording at [quality]. Returns false (and records nothing) if the
  /// mic permission is denied. Writes to a private temp file.
  Future<bool> start(VoiceQuality quality) async {
    if (!await hasPermission()) return false;
    final c = await codec();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/wk_voice_${DateTime.now().millisecondsSinceEpoch}.${c.fileExtension}';
    await _rec.start(buildVoiceRecordConfig(c, quality), path: path);
    _path = path;
    _startedAt = DateTime.now();
    return true;
  }

  /// Stop and return the captured audio, or null if nothing usable was recorded.
  /// The temp file is deleted once read — the bytes never persist to disk beyond
  /// the moment of capture.
  Future<VoiceCapture?> stop() async {
    final startedAt = _startedAt;
    final resultPath = await _rec.stop();
    _startedAt = null;
    final path = resultPath ?? _path;
    _path = null;
    if (path == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } catch (_) {
      // Best-effort cleanup; a stray temp file is harmless.
    }
    if (bytes.isEmpty) return null;

    final duration = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt);
    return VoiceCapture(
      bytes: Uint8List.fromList(bytes),
      duration: duration,
      codec: await codec(),
    );
  }

  /// Abort an in-progress recording and discard its temp file (mis-tap / cancel).
  Future<void> cancel() async {
    try {
      await _rec.stop();
    } catch (_) {
      // May already be stopped.
    }
    final path = _path;
    _path = null;
    _startedAt = null;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<void> dispose() => _rec.dispose();
}
