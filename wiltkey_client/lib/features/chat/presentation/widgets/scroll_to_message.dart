import 'package:flutter/material.dart';
import '../../../../core/models.dart';

/// Scrolls a lazy [ListView.builder] (rows keyed by message id in [rowKeys]) to
/// the row for [targetId], then returns it. The list is lazy + variable-height,
/// so this can't compute a pixel offset up front: it jumps to a proportional
/// estimate (index/length × maxScrollExtent), then corrects the estimate using
/// the nearest built row (linear-scaling assumption), and finally snaps exactly
/// with [Scrollable.ensureVisible] once the row is built. Keying by message id
/// keeps this correct even if loading older history shifts indices mid-scroll.
Future<void> scrollToMessageInList({
  required ScrollController controller,
  required List<ChatMessage> messages,
  required String targetId,
  required Map<String, GlobalKey> rowKeys,
}) async {
  if (!controller.hasClients) return;
  final index = messages.indexWhere((m) => m.id == targetId);
  if (index < 0 || messages.isEmpty) return;

  final key = rowKeys.putIfAbsent(targetId, GlobalKey.new);
  var ctx = key.currentContext;

  if (ctx == null) {
    final pos = controller.position;
    final maxScroll = pos.maxScrollExtent;
    var offset = maxScroll * (index / messages.length);

    // Jump to the estimate; the lazy builder may already have the row in its
    // cache extent, or close enough to reach on the next frame.
    pos.jumpTo(offset.clamp(0.0, maxScroll));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    ctx = key.currentContext;

    // Correct the estimate against the nearest built row (linear scale).
    for (var attempt = 0; attempt < 4 && ctx == null; attempt++) {
      if (!controller.hasClients) return;
      final nearest = _nearestBuiltIndex(messages, rowKeys);
      if (nearest == null || nearest == 0 || nearest == index) break;
      final pos2 = controller.position;
      final corrected =
          pos2.pixels * (index / nearest);
      pos2.jumpTo(corrected.clamp(0.0, pos2.maxScrollExtent));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      ctx = key.currentContext;
      if (ctx != null) break;
    }

    // Last resort: sweep toward the target in viewport-sized steps.
    if (ctx == null) {
      if (!controller.hasClients) return;
      final p = controller.position;
      final step = p.viewportDimension * 0.8;
      final max = p.maxScrollExtent;
      var offset2 = p.pixels;
      final builtIndex = _nearestBuiltIndex(messages, rowKeys);
      final forward = builtIndex == null || builtIndex < index;
      for (var i = 0; i < 30 && ctx == null; i++) {
        offset2 =
            (offset2 + (forward ? step : -step)).clamp(0.0, max);
        if (controller.hasClients) {
          controller.position.jumpTo(offset2);
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
        ctx = key.currentContext;
      }
    }
  }

  if (ctx != null && ctx.mounted) {
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      alignment: 0.4, // land the message just below the top of the viewport
    );
  }
}

/// Index of the lowest currently-built row (context mounted), or null if none.
/// "Lowest" (not nearest-to-target) is intentional: the linear-scaling correction
/// and the sweep direction both anchor on the origin of the built range.
int? _nearestBuiltIndex(
  List<ChatMessage> messages,
  Map<String, GlobalKey> rowKeys,
) {
  for (var i = 0; i < messages.length; i++) {
    final k = rowKeys[messages[i].id];
    if (k != null && k.currentContext != null) return i;
  }
  return null;
}
