import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

/// Structured payload for encrypted short video messages.
class VideoMessagePayload {
  final Uint8List thumbnailBytes;
  final String videoBase64;
  final int durationMs;
  final int? width;
  final int? height;

  const VideoMessagePayload({
    required this.thumbnailBytes,
    required this.videoBase64,
    required this.durationMs,
    this.width,
    this.height,
  });

  Map<String, dynamic> toMap() => {
    'thumb': base64Encode(thumbnailBytes),
    'video': videoBase64,
    'duration_ms': durationMs,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
  };

  String toJsonString() => jsonEncode(toMap());

  static VideoMessagePayload? tryParse(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final thumbStr = map['thumb'] as String?;
      final videoStr = map['video'] as String?;
      if (thumbStr == null || videoStr == null) return null;
      return VideoMessagePayload(
        thumbnailBytes: base64Decode(thumbStr),
        videoBase64: videoStr,
        durationMs: (map['duration_ms'] as num?)?.toInt() ?? 0,
        width: (map['width'] as num?)?.toInt(),
        height: (map['height'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Extracts just the thumbnail without needing to retain or allocate large video buffers.
  static Uint8List? extractThumbnail(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final thumbStr = map['thumb'] as String?;
      if (thumbStr != null && thumbStr.isNotEmpty) {
        return base64Decode(thumbStr);
      }
    } catch (_) {}
    return null;
  }
}

/// Preparation result containing the compressed video file, byte payload, and metadata.
class VideoPrepareResult {
  final VideoMessagePayload payload;
  final File file;
  final int sizeBytes;
  final int durationMs;

  const VideoPrepareResult({
    required this.payload,
    required this.file,
    required this.sizeBytes,
    required this.durationMs,
  });
}

/// Helper service for video compression, keyframe thumbnail extraction, and local cache management.
class VideoMessageService {
  VideoMessageService._();

  static const int maxDurationSeconds = 15;

  /// Rough compressed-bytes-per-second by quality tier (video+audio, H.264).
  /// The plugin maps: LowQuality≈360p, MediumQuality≈640p, DefaultQuality≈720p,
  /// HighQuality≈custom 3.7Mbps builder. Estimates only — the real size comes
  /// back from the compressor and replaces these in the send dialog.
  static int estimateCompressedBytes(int durationSecs, VideoQuality quality) {
    final double bytesPerSec = switch (quality) {
      VideoQuality.LowQuality => 80 * 1024,
      VideoQuality.MediumQuality => 160 * 1024,
      _ => 380 * 1024, // DefaultQuality (720p) and HighQuality
    };
    return (durationSecs * bytesPerSec).round();
  }

  /// Pure conversion of (clip selection → native trim params).
  ///
  /// ANDROID GOTCHA (jonataslaw/VideoCompress#292): the plugin passes
  /// (startTime, duration) onto Transcoder's TrimDataSource(startTrim,
  /// endTrim) — `duration` is the seconds cut from the END of the file, NOT
  /// the clip length. Passing the selected length produced exactly the
  /// "15s selected → 2s sent" bug (camera overshoot: 17s total − 15 = 2s)
  /// and hard failures whenever start + length exceeded the total
  /// (end-trim landing before start-trim → transcoder error). iOS uses
  /// AVAssetExportSession where `duration` IS the clip length, so the two
  /// platforms need different values.
  ///
  /// Returns (startTime, duration) in integer seconds.
  static (int, int?) trimParamsForPlatform({
    required bool isIos,
    required int startSecs,
    required int lengthSecs,
    required double totalSecs,
  }) {
    if (isIos) {
      return (startSecs, lengthSecs);
    }
    // Floor the end-trim: rounding the total up would eat into our clip.
    final endTrimSecs =
        ((totalSecs - startSecs - lengthSecs).floor()).clamp(0, 1 << 20);
    return (startSecs, endTrimSecs);
  }

  /// Compresses a video file to H.264/AAC, extracts a WebP keyframe thumbnail,
  /// and prepares a VideoMessagePayload. Supports trimming via [startTime] and
  /// [duration] (clip selection in seconds; converted per platform — see
  /// [trimParamsForPlatform]). Verifies the output and retries once as a
  /// full-clip transcode when the trimmed pass produced something broken.
  static Future<VideoPrepareResult?> prepareVideo(
    String sourcePath, {
    int? startTime,
    int? duration,
    VideoQuality quality = VideoQuality.MediumQuality,
  }) async {
    try {
      // 1. Source duration (MediaMetadataRetriever, milliseconds) — needed for
      //    the Android end-trim conversion and for output verification.
      double totalSecs = 0;
      try {
        final src = await VideoCompress.getMediaInfo(sourcePath);
        if (src.duration != null && src.duration! > 0) {
          totalSecs = src.duration! / 1000.0;
        }
      } catch (_) {}

      final hasTrim =
          (startTime != null && startTime > 0) ||
          (duration != null && totalSecs > 0 && duration < totalSecs);
      final startSecs = (startTime ?? 0).clamp(0, 1 << 20);
      final lengthSecs =
          duration != null ? duration.clamp(1, 1 << 20) : null;

      // 2. Compress, converting the trim parameters per platform.
      final (nativeStart, nativeDuration) = (lengthSecs != null && hasTrim)
          ? trimParamsForPlatform(
              isIos: Platform.isIOS,
              startSecs: startSecs,
              lengthSecs: lengthSecs,
              totalSecs: totalSecs,
            )
          : (0, null);

      final MediaInfo? info = await _compressOnce(
        sourcePath,
        quality: quality,
        startTime: nativeStart > 0 ? nativeStart : null,
        duration: nativeDuration,
      );

      // 3. Verify: a trimmed pass must yield roughly the requested length.
      //    (Short/garbled output = the exact failure mode that shipped 2s
      //    clips before the trim-semantics fix; retry untrimmed once so a
      //    broken trim never results in a broken message.)
      var result = await _buildResult(info, lengthSecs);
      if (result == null && lengthSecs != null && hasTrim) {
        final retry = await _compressOnce(
          sourcePath,
          quality: quality,
          startTime: null,
          duration: null,
        );
        result = await _buildResult(retry, null);
      }
      if (result == null) {
        return null;
      }
      return result;
    } catch (e) {
      // ignore: avoid_print
      print('[VideoMessageService] Failed to prepare video: $e');
      return null;
    }
  }

  static Future<MediaInfo?> _compressOnce(
    String sourcePath, {
    required VideoQuality quality,
    required int? startTime,
    required int? duration,
  }) {
    return VideoCompress.compressVideo(
      sourcePath,
      quality: quality,
      deleteOrigin: false,
      includeAudio: true,
      // NOTE: `frameRate` is only honored by the plugin for its custom
      // HighQuality builder; other tiers keep the source frame rate.
      frameRate: 24,
      startTime: startTime,
      duration: duration,
    );
  }

  /// Wraps compressor output into a [VideoPrepareResult], or null when the
  /// pass failed outright. [requestedSecs] enables output-length plausibility
  /// checking (video_player-hostile truncations are rejected here).
  static Future<VideoPrepareResult?> _buildResult(
    MediaInfo? info,
    int? requestedSecs,
  ) async {
    if (info == null || info.filesize == null || info.filesize! <= 0) {
      return null;
    }
    final file = info.file;
    if (file == null || !file.existsSync()) return null;
    final outputSecs = (info.duration != null && info.duration! > 0)
        ? info.duration! / 1000.0
        : 0.0;
    if (requestedSecs != null && outputSecs > 0) {
      // Keyframe-aligned trims round to segment boundaries; allow 30% slack.
      if (outputSecs < requestedSecs * 0.7) return null;
    }
    final durationMs = outputSecs > 0
        ? outputSecs.round() * 1000
        : ((requestedSecs ?? maxDurationSeconds) * 1000);
    return _extractAndBuild(info, file, durationMs);
  }

  static Future<VideoPrepareResult?> _extractAndBuild(
    MediaInfo info,
    File compressedFile,
    int durationMs,
  ) async {
    // Extract keyframe thumbnail
    Uint8List? thumbBytes;
    try {
      final rawThumb = await VideoCompress.getByteThumbnail(
        compressedFile.path,
        quality: 70,
      );
      if (rawThumb != null && rawThumb.isNotEmpty) {
        // Compress thumbnail to WebP for compact size (~4-8KB)
        final webp = await FlutterImageCompress.compressWithList(
          rawThumb,
          minWidth: 320,
          minHeight: 320,
          quality: 75,
          format: CompressFormat.webp,
        );
        thumbBytes = (webp?.isNotEmpty ?? false) ? webp! : rawThumb;
      }
    } catch (e) {
      // Fallback thumbnail extraction from source
      try {
        final rawThumb = await VideoCompress.getByteThumbnail(
          compressedFile.path,
          quality: 70,
          position: (durationMs ~/ 2),
        );
        if (rawThumb != null) {
          thumbBytes = rawThumb;
        }
      } catch (_) {}
    }

    thumbBytes ??= Uint8List(0);

    // Read compressed MP4 bytes & base64 encode
    final videoBytes = await compressedFile.readAsBytes();
    final videoBase64 = base64Encode(videoBytes);

    final payload = VideoMessagePayload(
      thumbnailBytes: thumbBytes,
      videoBase64: videoBase64,
      durationMs: durationMs,
      width: info.width,
      height: info.height,
    );

    return VideoPrepareResult(
      payload: payload,
      file: compressedFile,
      sizeBytes: videoBytes.length,
      durationMs: durationMs,
    );
  }

  /// Ensures a temporary .mp4 file exists for playback of [messageId] or [payload].
  static Future<File?> getOrWriteVideoFile({
    required String messageId,
    required VideoMessagePayload payload,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File(p.join(tempDir.path, 'wk_video_$messageId.mp4'));
      if (await targetFile.exists() && (await targetFile.length()) > 0) {
        return targetFile;
      }
      final bytes = base64Decode(payload.videoBase64);
      await targetFile.writeAsBytes(bytes, flush: true);
      return targetFile;
    } catch (e) {
      // ignore: avoid_print
      print('[VideoMessageService] Failed to write temp video: $e');
      return null;
    }
  }

  /// Deletes cached video file for a wilted or deleted message.
  static Future<void> cleanupVideoFile(String messageId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File(p.join(tempDir.path, 'wk_video_$messageId.mp4'));
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
    } catch (_) {}
  }

  /// Formats milliseconds into m:ss format (e.g. 0:14).
  static String formatDurationMs(int ms) {
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
