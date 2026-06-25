import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Shared image preparation for outbound messages (1-on-1 and group).
///
/// Every sent image is **forced to WebP** and downscaled so its longest side is
/// at most [maxDimension] px, keeping aspect ratio. This minimizes the OTP
/// keystream consumed per image (bytes are precious — the pad is finite).
class ImageUtils {
  ImageUtils._();

  /// Hard cap on the longest edge of a sent image.
  static const int maxDimension = 2000;

  /// Default WebP quality (0-100) when the caller doesn't specify one.
  static const int defaultQuality = 75;

  /// Returns the WebP-encoded, size-capped bytes ready to base64-encode + send.
  /// [quality] is 0-100. Falls back to the original bytes if encoding fails.
  static Future<Uint8List> prepareForSend(
    Uint8List src, {
    int quality = defaultQuality,
  }) async {
    // Probe the source dimensions so we can downscale to fit 2000x2000 while
    // preserving aspect ratio. Because the target dims keep the source aspect
    // ratio, flutter_image_compress produces exactly those dims.
    int w = maxDimension;
    int h = maxDimension;
    try {
      final codec = await ui.instantiateImageCodec(src);
      final frame = await codec.getNextFrame();
      w = frame.image.width;
      h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      // Unknown dimensions — fall through with the 2000 cap as the bound.
    }

    final int longest = w > h ? w : h;
    final double scale = longest > maxDimension ? maxDimension / longest : 1.0;
    final int targetW = (w * scale).round().clamp(1, maxDimension);
    final int targetH = (h * scale).round().clamp(1, maxDimension);

    try {
      final out = await FlutterImageCompress.compressWithList(
        src,
        format: CompressFormat.webp,
        minWidth: targetW,
        minHeight: targetH,
        quality: quality.clamp(1, 100),
      );
      return Uint8List.fromList(out);
    } catch (_) {
      return src;
    }
  }

  /// Edge length of a stored custom emoji.
  static const int emojiDimension = 150;

  /// Re-encodes a (square) emoji capture as a small ~150×150 WebP so the shared
  /// emoji pool stays tiny within the metadata budget. Falls back to the source
  /// bytes if encoding fails.
  static Future<Uint8List> prepareEmoji(
    Uint8List src, {
    int quality = 80,
  }) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        src,
        format: CompressFormat.webp,
        minWidth: emojiDimension,
        minHeight: emojiDimension,
        quality: quality.clamp(1, 100),
      );
      return Uint8List.fromList(out);
    } catch (_) {
      return src;
    }
  }
}
