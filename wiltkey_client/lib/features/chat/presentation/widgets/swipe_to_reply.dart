import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/wk.dart';

/// Swipe-to-reply gesture with the "small nudge, growing resistance, spring back"
/// feel of mainstream chat apps — NOT a [Dismissible] (which slides the whole item
/// across and floats back). The bubble follows the finger 1:1 at first, then
/// resists harder and asymptotes to a small [_maxOffset]; crossing [_armRaw] of
/// finger travel arms the reply (one haptic tick), and releasing while armed fires
/// [onReply] and springs the bubble back.
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  // How far the bubble can visually travel (px) — a small nudge, never a full slide.
  static const double _maxOffset = 64;
  // Finger travel (px) needed to arm the reply.
  static const double _armRaw = 62;

  double _rawDx = 0; // accumulated finger travel (rightward only)
  double _dx = 0; // displayed (damped) offset
  bool _armed = false;

  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Animation<double>? _springAnim;

  /// Damped resistance: slope 1 near 0 (follows the finger), asymptotes to
  /// [_maxOffset] as you pull further — so it gets "heavier" the more you drag.
  double _resist(double raw) =>
      raw <= 0 ? 0 : raw * _maxOffset / (raw + _maxOffset);

  void _onStart(DragStartDetails _) {
    _spring.stop();
    _rawDx = 0;
  }

  void _onUpdate(DragUpdateDetails d) {
    _rawDx = (_rawDx + d.delta.dx).clamp(0.0, 400.0);
    final armedNow = _rawDx >= _armRaw;
    if (armedNow && !_armed) HapticFeedback.selectionClick();
    setState(() {
      _armed = armedNow;
      _dx = _resist(_rawDx);
    });
  }

  void _onEnd(DragEndDetails _) {
    final fire = _armed;
    _armed = false;
    _rawDx = 0;
    _springAnim =
        Tween<double>(begin: _dx, end: 0).animate(
          CurvedAnimation(parent: _spring, curve: Curves.easeOutBack),
        )..addListener(() {
          setState(() => _dx = _springAnim!.value);
        });
    _spring.forward(from: 0);
    if (fire) widget.onReply();
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final t = context.wk;
    // The arrow reveals to the left as the bubble nudges right; it firms up to the
    // accent colour and grows slightly once armed.
    final double revealT = (_dx / (_maxOffset * 0.55)).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragStart: _onStart,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: revealT,
                child: Icon(
                  Icons.reply,
                  size: _armed ? 22 : 18,
                  color: _armed ? t.action : t.textTertiary,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
