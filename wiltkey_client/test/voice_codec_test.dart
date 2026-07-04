import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/audio/voice_codec.dart';

void main() {
  group('VoiceHeader wire format', () {
    test('round-trips codec + duration + audio bytes', () {
      final audio = Uint8List.fromList(List<int>.generate(64, (i) => i * 3 % 256));
      final wrapped = const VoiceHeader(
        codec: VoiceCodec.opus,
        duration: Duration(seconds: 12, milliseconds: 300),
      ).wrap(audio);

      // Header adds exactly its fixed length.
      expect(wrapped.length, VoiceHeader.byteLength + audio.length);

      final parsed = VoiceHeader.unwrap(wrapped);
      expect(parsed, isNotNull);
      expect(parsed!.header.codec, VoiceCodec.opus);
      // Duration is quantised to deciseconds (×100 ms).
      expect(parsed.header.duration, const Duration(milliseconds: 12300));
      expect(parsed.audio, equals(audio));
    });

    test('preserves the AAC-LC codec id', () {
      final wrapped = const VoiceHeader(
        codec: VoiceCodec.aacLc,
        duration: Duration(seconds: 1),
      ).wrap(Uint8List(0));
      expect(VoiceHeader.unwrap(wrapped)!.header.codec, VoiceCodec.aacLc);
    });

    test('rejects a non-voice / truncated payload', () {
      expect(VoiceHeader.unwrap(Uint8List.fromList([9, 9])), isNull); // too short
      expect(
        VoiceHeader.unwrap(Uint8List.fromList([0xFF, 1, 0, 0, 1, 2, 3])),
        isNull, // wrong version byte
      );
    });

    test('clamps an over-long duration into 16 bits instead of overflowing', () {
      final wrapped = const VoiceHeader(
        codec: VoiceCodec.opus,
        duration: Duration(hours: 5), // far past kVoiceMaxDuration
      ).wrap(Uint8List(0));
      // 0xFFFF deciseconds = 6553.5 s; must not wrap around to a tiny value.
      expect(VoiceHeader.unwrap(wrapped)!.header.duration.inSeconds, 6553);
    });

    test('fromId falls back to AAC-LC for an unknown id', () {
      expect(VoiceCodec.fromId(99), VoiceCodec.aacLc);
    });
  });

  group('VoiceQuality tiers', () {
    test('span the agreed 8–48 kbps range with voice as the default', () {
      expect(VoiceQuality.lofi.bitRate, 8000);
      expect(VoiceQuality.clear.bitRate, 48000);
      expect(kVoiceQualityDefault, VoiceQuality.voice);
    });
  });
}
