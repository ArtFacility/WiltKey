import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Captures the widget subtree under [boundaryKey] as a raster image, for
/// themed nuke overlays that use the real screen as their animation base
/// (see `WiltkeyComponents.nukeOverlay(screen: …)`).
///
/// The key must sit on a [RepaintBoundary] that is currently mounted and has
/// painted at least once — e.g. a `RepaintBoundary(key: …)` wrapped around a
/// chat screen's `Scaffold`. Returns null (never throws) when capture isn't
/// possible, so call sites can always hand `nukeOverlay` a nullable image.
Future<ui.Image?> captureNukeScreen(
  GlobalKey boundaryKey, {
  double pixelRatio = 1.0,
}) async {
  try {
    final ro = boundaryKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;
    if (ro.debugNeedsPaint) return null;
    return await ro.toImage(pixelRatio: pixelRatio);
  } catch (_) {
    return null;
  }
}
