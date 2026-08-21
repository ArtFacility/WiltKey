import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/models.dart';
import '../../../../core/theme/wk.dart';

/// Wraps revealed wilting message content with its countdown progress bar or
/// a static wilting tag.
Widget wrapWiltingContent({
  required BuildContext context,
  required ChatMessage message,
  required bool isMe,
  required Widget content,
}) {
  if (!message.isWilting) return content;
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  final accent = isMe ? t.bubbleMeText : t.action;

  final Widget footer;
  if (message.openedAt != null && message.expiresAt != null) {
    footer = WiltCountdownBar(
      openedAt: message.openedAt!,
      expiresAt: message.expiresAt!,
      color: accent,
    );
  } else {
    footer = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_florist_outlined,
          size: 11,
          color: accent.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          t.uppercaseLabels
              ? l10n.wiltingMessageTag.toUpperCase()
              : l10n.wiltingMessageTag,
          style: t.dataMono.copyWith(
            fontSize: 9,
            color: accent.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [content, const SizedBox(height: 5), footer],
  );
}

/// The gated placeholder for a received, not-yet-revealed wilting message.
class WiltGate extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onTap;

  const WiltGate({
    super.key,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final secs = message.ttlSeconds <= 0 ? 5 : message.ttlSeconds;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: t.action.withValues(alpha: 0.08),
          border: Border.all(color: t.action.withValues(alpha: 0.35), width: 1),
          borderRadius: BorderRadius.circular(t.radiusControl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_florist_outlined, color: t.action, size: 16),
            const SizedBox(width: 8),
            Text(
              t.uppercaseLabels
                  ? l10n.wiltingTapToReveal.toUpperCase()
                  : l10n.wiltingTapToReveal,
              style: t.dataMono.copyWith(color: t.action, fontSize: 11),
            ),
            const SizedBox(width: 6),
            Text(
              '${secs}s',
              style: t.dataMono.copyWith(color: t.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tombstone left after a message has wilted (content destroyed).
class WiltedTombstone extends StatelessWidget {
  final bool isMe;

  const WiltedTombstone({super.key, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final color = isMe ? t.bubbleMeText.withValues(alpha: 0.6) : t.textTertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_florist_outlined, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          t.uppercaseLabels
              ? l10n.wiltedMessage.toUpperCase()
              : l10n.wiltedMessage,
          style: t.dataMono.copyWith(
            fontSize: 11.5,
            color: color,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// Active countdown progress bar for a wilting message with tabular seconds.
class WiltCountdownBar extends StatefulWidget {
  final int openedAt;
  final int expiresAt;
  final Color color;

  const WiltCountdownBar({
    super.key,
    required this.openedAt,
    required this.expiresAt,
    required this.color,
  });

  @override
  State<WiltCountdownBar> createState() => _WiltCountdownBarState();
}

class _WiltCountdownBarState extends State<WiltCountdownBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      if (DateTime.now().millisecondsSinceEpoch >= widget.expiresAt) {
        _ticker?.cancel();
      }
      setState(() {});
    });
  }

  double _fraction() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final span = widget.expiresAt - widget.openedAt;
    if (span <= 0) return 0;
    return ((widget.expiresAt - now) / span).clamp(0.0, 1.0);
  }

  int _secondsLeft() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ((widget.expiresAt - now) / 1000).ceil().clamp(0, 999);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frac = _fraction();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 4,
              backgroundColor: widget.color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(widget.color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${_secondsLeft()}s',
          style: TextStyle(
            fontSize: 9,
            color: widget.color.withValues(alpha: 0.8),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
