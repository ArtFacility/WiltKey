import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/state.dart';
import '../../../../core/theme/wk.dart';
import 'image_viewer.dart';

// Decoded app icon for the banner, loaded once and cached.
ui.Image? _cachedBannerLogo;

Future<ui.Image?> _bannerLogo() async {
  if (_cachedBannerLogo != null) return _cachedBannerLogo;
  try {
    final data = await rootBundle.load('assets/icon/icon.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _cachedBannerLogo = frame.image;
    return _cachedBannerLogo;
  } catch (_) {
    return null;
  }
}

/// Renders the [boundaryKey]'s subtree (the chat message list) to a PNG and opens
/// it in the shared [ImageViewerScreen] with saving enabled. This is a layer-tree
/// render — NOT an OS screen grab — so it works even under `FLAG_SECURE`. Only
/// ever called after the peer(s) consented (see [AppStateScreenshot]).
///
/// A "WiltKey — Screenshot with consent" banner (logo + caption on the theme
/// background) is composited above the capture, and the theme background is
/// baked in behind it (the message list itself is transparent, which otherwise
/// renders black on light themes).
Future<void> captureChatAndOpen(
  BuildContext context,
  GlobalKey boundaryKey,
) async {
  final l10n = AppLocalizations.of(context)!;
  final t = context.wk;
  void fail() {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: t.surface,
        content: Text(
          l10n.screenshotCaptureFailed,
          style: t.bodySecondary.copyWith(color: t.danger),
        ),
      ),
    );
  }

  try {
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      fail();
      return;
    }
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: dpr);
    Uint8List? bytes = await _composeWithBanner(
      image,
      bg: t.bg,
      fg: t.textPrimary,
      accent: t.action,
      caption: l10n.screenshotWatermark,
      dpr: dpr,
    );
    // Fallback: the raw list image (its background is baked in by the ColoredBox
    // wrapper in the chat screens, so this is still correctly themed).
    bytes ??= (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))?.buffer.asUint8List();
    image.dispose();
    if (bytes == null || !context.mounted) {
      fail();
      return;
    }
    await ImageViewerScreen.open(context, imageBytes: bytes, allowSave: true);
  } catch (_) {
    fail();
  }
}

/// Draws the [list] image beneath a themed banner (logo + [caption]) and returns
/// PNG bytes. Returns null on any failure so the caller can fall back.
Future<Uint8List?> _composeWithBanner(
  ui.Image list, {
  required Color bg,
  required Color fg,
  required Color accent,
  required String caption,
  required double dpr,
}) async {
  try {
    final logo = await _bannerLogo();
    final int w = list.width;
    final int bannerH = (46 * dpr).round();
    final int totalH = list.height + bannerH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Banner background strip + a thin accent divider under it.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), bannerH.toDouble()),
      Paint()..color = bg,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, bannerH - dpr, w.toDouble(), dpr),
      Paint()..color = accent.withValues(alpha: 0.5),
    );

    final double pad = 14 * dpr;
    final double cy = bannerH / 2;
    double x = pad;

    if (logo != null) {
      final double side = 26 * dpr;
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromLTWH(x, cy - side / 2, side, side),
        Paint()..filterQuality = FilterQuality.high,
      );
      x += side + 10 * dpr;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: caption,
        style: TextStyle(
          color: fg,
          fontSize: 13 * dpr,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: w - x - pad);
    tp.paint(canvas, Offset(x, cy - tp.height / 2));

    canvas.drawImage(list, Offset(0, bannerH.toDouble()), Paint());

    final picture = recorder.endRecording();
    final composed = await picture.toImage(w, totalH);
    picture.dispose();
    final byteData = await composed.toByteData(format: ui.ImageByteFormat.png);
    composed.dispose();
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// The Allow/Deny consent prompt shown to a peer who was asked for a screenshot.
/// Sends the response back through [AppStateScreenshot.respondToScreenshot];
/// dismissing without choosing counts as a decline.
Future<void> showScreenshotConsentDialog(
  BuildContext context,
  ScreenshotRequestEvent req,
) async {
  final l10n = AppLocalizations.of(context)!;
  final t = context.wk;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusCard),
        side: BorderSide(color: t.border, width: t.borderWidth),
      ),
      title: Text(
        t.uppercaseLabels
            ? l10n.screenshotConsentTitle.toUpperCase()
            : l10n.screenshotConsentTitle,
        style: t.screenTitle.copyWith(fontSize: 16),
      ),
      content: Text(
        l10n.screenshotConsentBody(req.requesterName),
        style: t.bodySecondary.copyWith(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            l10n.pairRequestReject,
            style: TextStyle(color: t.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: t.action,
            foregroundColor: t.onAction,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
          ),
          child: Text(l10n.pairRequestAccept),
        ),
      ],
    ),
  );
  await AppState().respondToScreenshot(req, accepted == true);
}
