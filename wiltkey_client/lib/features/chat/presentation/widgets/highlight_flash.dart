import 'package:flutter/material.dart';
import '../../../../core/theme/wk.dart';

/// Briefly tints [child] with [color] whenever [tick] changes while [active].
/// Used to flash a chat message after jumping to it from a quote reply — the
/// tint eases out so the row "pulses" once instead of staying tinted.
class HighlightFlash extends StatefulWidget {
  final bool active;
  final int tick;
  final Color color;
  final Widget child;

  const HighlightFlash({
    super.key,
    required this.active,
    required this.tick,
    required this.color,
    required this.child,
  });

  @override
  State<HighlightFlash> createState() => _HighlightFlashState();
}

class _HighlightFlashState extends State<HighlightFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    // If the flashing row is mounted already flashing (e.g. scrolled back into
    // view inside the flash window), start the fade immediately.
    if (widget.active) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(HighlightFlash old) {
    super.didUpdateWidget(old);
    if (widget.active && widget.tick != old.tick) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = context.wk;
        return Container(
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.22 * (1 - _fade.value)),
            borderRadius: BorderRadius.circular(t.radiusCard),
          ),
          child: child,
        );
      },
    );
  }
}
