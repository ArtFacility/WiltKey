import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/video/video_message_service.dart';

void main() {
  group('VideoMessagePayload', () {
    test('serializes and deserializes correctly', () {
      final sampleThumb = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      const sampleVideoBase64 = 'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDE=';

      final payload = VideoMessagePayload(
        thumbnailBytes: sampleThumb,
        videoBase64: sampleVideoBase64,
        durationMs: 12500,
        width: 720,
        height: 1280,
      );

      final jsonStr = payload.toJsonString();
      expect(jsonStr.contains('"duration_ms":12500'), isTrue);
      expect(jsonStr.contains('"width":720'), isTrue);
      expect(jsonStr.contains('"height":1280'), isTrue);

      final parsed = VideoMessagePayload.tryParse(jsonStr);
      expect(parsed, isNotNull);
      expect(parsed!.thumbnailBytes, equals(sampleThumb));
      expect(parsed.videoBase64, equals(sampleVideoBase64));
      expect(parsed.durationMs, equals(12500));
      expect(parsed.width, equals(720));
      expect(parsed.height, equals(1280));
    });

    test('extractThumbnail extracts thumbnail without parsing entire payload', () {
      final sampleThumb = Uint8List.fromList([10, 20, 30, 40]);
      final payload = VideoMessagePayload(
        thumbnailBytes: sampleThumb,
        videoBase64: 'heavy_video_base64_data',
        durationMs: 8000,
      );

      final jsonStr = payload.toJsonString();
      final extracted = VideoMessagePayload.extractThumbnail(jsonStr);
      expect(extracted, isNotNull);
      expect(extracted, equals(sampleThumb));
    });

    test('tryParse handles invalid JSON gracefully', () {
      expect(VideoMessagePayload.tryParse('not_a_json'), isNull);
      expect(VideoMessagePayload.tryParse('{"incomplete": true}'), isNull);
      expect(VideoMessagePayload.extractThumbnail('invalid'), isNull);
    });
  });

  group('VideoMessageService', () {
    test('formats duration correctly', () {
      expect(VideoMessageService.formatDurationMs(0), equals('0:00'));
      expect(VideoMessageService.formatDurationMs(5000), equals('0:05'));
      expect(VideoMessageService.formatDurationMs(14200), equals('0:14'));
      expect(VideoMessageService.formatDurationMs(65000), equals('1:05'));
    });
  });
}
