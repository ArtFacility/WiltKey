import 'dart:typed_data';
import 'package:record/record.dart';

/// Hard cap on a single voice note. The OTP pad is finite, so length is a real
/// cost — see [VoiceQuality] and the live budget meter in the recorder UI.
const Duration kVoiceMaxDuration = Duration(seconds: 60);

/// Below this the release is treated as a mis-tap / cancel, not a message.
const Duration kVoiceMinDuration = Duration(milliseconds: 700);

/// Audio codec used for a voice message. The chosen codec's [id] is written into
/// the message payload header ([VoiceHeader]) so the receiver decodes correctly
/// regardless of what the *sender's* device was able to encode.
enum VoiceCodec {
  /// Opus in an Ogg container. Best voice efficiency; only *encodable* on
  /// Android 10+ (API 29 / `VERSION_CODES.Q`). Decodable on every supported
  /// device (Opus decode is available from API 21).
  opus(
    id: 1,
    fileExtension: 'ogg',
    encoder: AudioEncoder.opus,
    sampleRate: 16000,
  ),

  /// AAC-LC in an MPEG-4 container. Universal fallback — encodable on every
  /// supported API level, for Android 7–9 which can't encode Opus.
  aacLc(
    id: 2,
    fileExtension: 'm4a',
    encoder: AudioEncoder.aacLc,
    sampleRate: 22050,
  );

  const VoiceCodec({
    required this.id,
    required this.fileExtension,
    required this.encoder,
    required this.sampleRate,
  });

  /// Stable wire id (persisted in the payload header — never renumber).
  final int id;

  /// Temp-file extension so the platform player can sniff the container.
  final String fileExtension;

  /// The `record` plugin encoder this codec maps to.
  final AudioEncoder encoder;

  /// Requested capture sample rate. `record` snaps this to the nearest the
  /// encoder/device actually supports and writes back the real value, so this is
  /// a target, not a guarantee. 16 kHz suits voice-band Opus; AAC likes 22.05 k.
  final int sampleRate;

  static VoiceCodec fromId(int id) =>
      values.firstWhere((c) => c.id == id, orElse: () => VoiceCodec.aacLc);
}

/// User-facing quality tiers, labelled by *vibe* (see l10n) rather than raw kbps
/// so the low end reads as an intentional lo-fi choice, not a broken one. The
/// floor is a deliberately crunchy ~8 kbps: Opus stays legible that low (it's a
/// VoIP codec at heart), while the AAC-LC fallback on older devices effectively
/// clamps nearer ~24 kbps — an accepted degradation on exactly the phones that
/// can't run Opus anyway.
enum VoiceQuality {
  /// Tiny + crunchy. Charming on Opus; AAC clamps up on old devices.
  lofi(bitRate: 8000),

  /// The default — clear speech at a modest pad cost.
  voice(bitRate: 24000),

  /// Fuller, higher-budget capture.
  clear(bitRate: 48000);

  const VoiceQuality({required this.bitRate});

  final int bitRate;
}

/// The default tier a new recording starts at.
const VoiceQuality kVoiceQualityDefault = VoiceQuality.voice;

/// Build the `record` config for a [codec] + [quality]. Always mono — voice
/// notes never need stereo and it halves the pad cost.
RecordConfig buildVoiceRecordConfig(VoiceCodec codec, VoiceQuality quality) =>
    RecordConfig(
      encoder: codec.encoder,
      bitRate: quality.bitRate,
      sampleRate: codec.sampleRate,
      numChannels: 1,
    );

/// Pick the best *encodable* codec for this device: Opus where the platform
/// supports encoding it (~API 29+), else the universal AAC-LC fallback. Callers
/// should cache the result — it can't change at runtime.
Future<VoiceCodec> pickRecordCodec(AudioRecorder recorder) async {
  if (await recorder.isEncoderSupported(AudioEncoder.opus)) {
    return VoiceCodec.opus;
  }
  return VoiceCodec.aacLc;
}

/// A fixed-size header prepended to the raw audio before base64-encoding, so a
/// voice payload is self-describing on the receiver without a DB schema change
/// (it rides inside the existing base64 `ChatMessage.text`, like an image).
///
/// Layout (big-endian): `[0] version | [1] codec id | [2..3] duration ×100 ms`.
class VoiceHeader {
  static const int _version = 1;

  /// Header size in bytes.
  static const int byteLength = 4;

  final VoiceCodec codec;
  final Duration duration;

  const VoiceHeader({required this.codec, required this.duration});

  /// Prepend the header to [audio], yielding the payload to base64-encode + send.
  Uint8List wrap(Uint8List audio) {
    // Duration stored in deciseconds (×100 ms) → max ~109 min in 16 bits, far
    // beyond [kVoiceMaxDuration].
    final ds = (duration.inMilliseconds / 100).round().clamp(0, 0xFFFF);
    final out = Uint8List(byteLength + audio.length);
    out[0] = _version;
    out[1] = codec.id;
    out[2] = (ds >> 8) & 0xFF;
    out[3] = ds & 0xFF;
    out.setRange(byteLength, out.length, audio);
    return out;
  }

  /// Parse a payload produced by [wrap]. Returns null if [payload] isn't a v1
  /// voice blob (wrong version / too short), so callers can fail soft.
  static VoicePayload? unwrap(Uint8List payload) {
    if (payload.length < byteLength || payload[0] != _version) return null;
    final codec = VoiceCodec.fromId(payload[1]);
    final ds = (payload[2] << 8) | payload[3];
    return VoicePayload(
      header: VoiceHeader(
        codec: codec,
        duration: Duration(milliseconds: ds * 100),
      ),
      audio: Uint8List.sublistView(payload, byteLength),
    );
  }
}

/// A parsed voice payload: its [header] plus the raw (still-container'd) audio.
class VoicePayload {
  final VoiceHeader header;
  final Uint8List audio;

  const VoicePayload({required this.header, required this.audio});
}
