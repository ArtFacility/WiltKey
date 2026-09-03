import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/audio/voice_codec.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/payload_limits.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic Voice Duration & Budget Calculation', () {
    test('calculates duration for tight byte-budget contact', () {
      // Create contact with 15 KB (15360 bytes) remaining budget
      final contact = Contact(
        id: 'contact_1',
        name: 'Alice',
        keyHash: 'hash_1',
        relayUrl: '',
        isPrivateNode: false,
        lastActivity: DateTime.now(),
        incomingOffset: 0,
        incomingMaxOffset: 524288,
        outgoingOffset: 524288,
        outgoingMaxOffset: 1048576,
        maxBufferBytes: 1048576,
        remainingBufferBytes: 15360,
        peerRemainingBufferBytes: 524288,
      );

      // Codec: voice tier (24 kbps -> 3000 B/s)
      const quality = VoiceQuality.voice;
      final int byteRate = quality.bitRate ~/ 8; // 3000 B/s

      // Buffer headroom: 15360 - 73 framing = 15287 bytes base64 max
      final int maxBase64FromBuffer = contact.remainingBufferBytes - 73;
      final int maxRawPayload = (maxBase64FromBuffer * 3) ~/ 4;
      final int maxAudioBytes = maxRawPayload - VoiceHeader.byteLength;

      expect(maxAudioBytes, greaterThan(0));
      final int rawSeconds = (maxAudioBytes / byteRate).floor();
      final int safeSeconds = rawSeconds > 2 ? rawSeconds - 1 : rawSeconds;

      // ~11.4 kB raw audio at 3 kB/s is ~3 seconds (3-4s with safety margin)
      expect(safeSeconds, inInclusiveRange(2, 4));
    });

    test('calculates duration for large byte-budget contact capped at 10 minutes', () {
      final contact = Contact(
        id: 'contact_2',
        name: 'Bob',
        keyHash: 'hash_2',
        relayUrl: '',
        isPrivateNode: false,
        lastActivity: DateTime.now(),
        incomingOffset: 0,
        incomingMaxOffset: 524288,
        outgoingOffset: 524288,
        outgoingMaxOffset: 1048576,
        maxBufferBytes: 1048576,
        remainingBufferBytes: 524288, // 512 KB
        peerRemainingBufferBytes: 524288,
      );

      const quality = VoiceQuality.voice; // 3000 B/s
      final int byteRate = quality.bitRate ~/ 8;
      final int maxBase64FromBuffer = contact.remainingBufferBytes - 73;
      final int maxRawPayload = (maxBase64FromBuffer * 3) ~/ 4;
      final int maxAudioBytes = maxRawPayload - VoiceHeader.byteLength;

      final int rawSeconds = (maxAudioBytes / byteRate).floor();
      final int safeSeconds = rawSeconds > 2 ? rawSeconds - 1 : rawSeconds;
      const int maxCapSeconds = 10 * 60; // 600s
      final int clampedSeconds = safeSeconds.clamp(1, maxCapSeconds);

      // 512 KB allows ~130s at 3 kB/s, which is well below the 10-minute cap
      expect(clampedSeconds, inInclusiveRange(120, 140));
    });

    test('calculates duration for Time Wilt chat up to relay payload limit', () {
      final contact = Contact(
        id: 'contact_tw',
        name: 'Carol',
        keyHash: 'hash_tw',
        relayUrl: '',
        isPrivateNode: false,
        lastActivity: DateTime.now(),
        incomingOffset: 0,
        incomingMaxOffset: 0,
        outgoingOffset: 0,
        outgoingMaxOffset: 0,
        maxBufferBytes: 0,
        remainingBufferBytes: 0,
        peerRemainingBufferBytes: 0,
        wiltExpiresAt: DateTime.now().add(const Duration(hours: 24)),
        streamSeedHex: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      expect(contact.isTimeWilt, isTrue);

      const quality = VoiceQuality.voice; // 3000 B/s
      final int byteRate = quality.bitRate ~/ 8;
      final int maxOutgoing = WkPayloadLimits.maxOutgoingPayload; // 5 MB free tier
      final int maxBase64FromEnvelope = ((maxOutgoing - 256) * 3) ~/ 4;
      final int maxRawPayload = (maxBase64FromEnvelope * 3) ~/ 4;
      final int maxAudioBytes = maxRawPayload - VoiceHeader.byteLength;

      final int rawSeconds = (maxAudioBytes / byteRate).floor();
      final int safeSeconds = rawSeconds > 2 ? rawSeconds - 1 : rawSeconds;
      const int maxCapSeconds = 10 * 60;
      final int clampedSeconds = safeSeconds.clamp(1, maxCapSeconds);

      // 5 MB on free tier allows more than 10 minutes at 3 kB/s, so capped at 10m (600s)
      expect(clampedSeconds, equals(600));
    });

    test('returns zero duration when remaining budget is exhausted', () {
      final contact = Contact(
        id: 'contact_empty',
        name: 'Dave',
        keyHash: 'hash_empty',
        relayUrl: '',
        isPrivateNode: false,
        lastActivity: DateTime.now(),
        incomingOffset: 0,
        incomingMaxOffset: 524288,
        outgoingOffset: 524288,
        outgoingMaxOffset: 1048576,
        maxBufferBytes: 1048576,
        remainingBufferBytes: 50, // Less than 73 + header
        peerRemainingBufferBytes: 524288,
      );

      final int maxBase64FromBuffer = contact.remainingBufferBytes - 73;
      expect(maxBase64FromBuffer, lessThanOrEqualTo(0));
    });
  });
}
