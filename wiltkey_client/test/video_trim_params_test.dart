import 'package:flutter_test/flutter_test.dart';
import 'package:video_compress/video_compress.dart';
import 'package:wiltkey_client/core/video/video_message_service.dart';

void main() {
  group('trimParamsForPlatform (video_compress Android end-trim semantics)', () {
    test('Android: full-clip selection of an overshooting camera recording',
        () {
      // The exact "15s selected → 2s sent" bug: camera records ~17s, the user
      // selects 0→15s. Native duration must be the END-TRIM (17-0-15 = 2),
      // NOT the clip length.
      final (start, duration) = VideoMessageService.trimParamsForPlatform(
        isIos: false,
        startSecs: 0,
        lengthSecs: 15,
        totalSecs: 17,
      );
      expect(start, 0);
      expect(duration, 2);
    });

    test('Android: middle selection 5s→10s of a 17s clip', () {
      final (start, duration) = VideoMessageService.trimParamsForPlatform(
        isIos: false,
        startSecs: 5,
        lengthSecs: 5,
        totalSecs: 17,
      );
      expect(start, 5);
      expect(duration, 7); // 17 - 5 - 5
    });

    test('Android: selection ending at video end (end-trim zero)', () {
      final (start, duration) = VideoMessageService.trimParamsForPlatform(
        isIos: false,
        startSecs: 13,
        lengthSecs: 4,
        totalSecs: 17,
      );
      expect(start, 13);
      expect(duration, 0);
    });

    test('Android: trailing selection that overshoots the total clamps to 0',
        () {
      // 8+3 = 11 > 10 → the old semantics (passing length) sent an end-trim
      // BEFORE the start-trim, which hard-failed the transcoder.
      final (start, duration) = VideoMessageService.trimParamsForPlatform(
        isIos: false,
        startSecs: 8,
        lengthSecs: 3,
        totalSecs: 10,
      );
      expect(start, 8);
      expect(duration, 0);
    });

    test('Android: unknown total duration falls back to no end-trim', () {
      final (start, duration) = VideoMessageService.trimParamsForPlatform(
        isIos: false,
        startSecs: 2,
        lengthSecs: 5,
        totalSecs: 0,
      );
      expect(start, 2);
      expect(duration, 0);
    });

    test('iOS: duration IS the clip length (AVAssetExportSession)', () {
      final (start, duration) = VideoMessageService.trimParamsForPlatform(
        isIos: true,
        startSecs: 5,
        lengthSecs: 5,
        totalSecs: 17,
      );
      expect(start, 5);
      expect(duration, 5);
    });
  });

  group('estimateCompressedBytes', () {
    test('scales with duration', () {
      expect(
        VideoMessageService.estimateCompressedBytes(10, VideoQuality.MediumQuality),
        VideoMessageService.estimateCompressedBytes(5, VideoQuality.MediumQuality) * 2,
      );
    });

    test('ranks Low < Medium < High', () {
      final low =
          VideoMessageService.estimateCompressedBytes(10, VideoQuality.LowQuality);
      final medium =
          VideoMessageService.estimateCompressedBytes(10, VideoQuality.MediumQuality);
      final high =
          VideoMessageService.estimateCompressedBytes(10, VideoQuality.DefaultQuality);
      expect(low, lessThan(medium));
      expect(medium, lessThan(high));
    });
  });
}
