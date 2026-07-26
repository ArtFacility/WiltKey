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
  ///
  /// [fullResolution] skips the [maxDimension] downscale entirely (the "send
  /// uncompressed" slider step). When the source is a format Flutter can already
  /// decode (JPEG/PNG/WebP), we send the **original bytes untouched** — that is
  /// what "uncompressed" should mean, and it avoids a nasty size blow-up: WebP
  /// q100 is near-lossless and routinely re-encodes a 3 MB JPEG into a *9 MB*
  /// WebP. Only when the original can't be decoded (notably iPhone HEIC) do we
  /// fall back to a full-size WebP re-encode so the recipient can still render it.
  static Future<Uint8List> prepareForSend(
    Uint8List src, {
    int quality = defaultQuality,
    bool fullResolution = false,
  }) async {
    // Probe the source dimensions so we can downscale to fit 2000x2000 while
    // preserving aspect ratio. Because the target dims keep the source aspect
    // ratio, flutter_image_compress produces exactly those dims. A successful
    // decode also proves Flutter can render these bytes as-is.
    int w = maxDimension;
    int h = maxDimension;
    bool decodable = false;
    try {
      final codec = await ui.instantiateImageCodec(src);
      final frame = await codec.getNextFrame();
      w = frame.image.width;
      h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      decodable = true;
    } catch (_) {
      // Unknown dimensions — fall through with the 2000 cap as the bound.
    }

    // Uncompressed + already renderable → ship the original bytes verbatim. This
    // is genuinely lossless AND smaller than a WebP q100 re-encode for the common
    // JPEG/HEIC-transcoded-to-JPEG case.
    if (fullResolution && decodable) {
      return src;
    }

    final int longest = w > h ? w : h;
    // Full-resolution: bound is the image's own longest edge (scale = 1.0, no
    // downscale). Otherwise clamp to maxDimension.
    final int bound = fullResolution ? (longest < 1 ? 1 : longest) : maxDimension;
    final double scale = longest > bound ? bound / longest : 1.0;
    final int targetW = (w * scale).round().clamp(1, bound);
    final int targetH = (h * scale).round().clamp(1, bound);

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
