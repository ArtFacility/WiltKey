import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Paints an animated avatar border into [size]. [t] is elapsed time in seconds
/// (shared across every animated border so they stay in phase); [reduceMotion]
/// asks for a single still frame. Fixed colours only — a border is broadcast
/// profile art, so it must look identical on every peer's screen regardless of
/// their active theme (never read theme tokens here).
typedef AvatarBorderPaint =
    void Function(Canvas canvas, Size size, double t, bool reduceMotion);

/// One process-wide clock that every animated avatar border shares, so a list of
/// avatars costs ONE frame callback instead of one per avatar. It only runs
/// while something is listening (started on the first listener, stopped on the
/// last), so a screen with no animated borders visible burns nothing.
class AvatarBorderTicker extends ChangeNotifier {
  AvatarBorderTicker._();
  static final AvatarBorderTicker instance = AvatarBorderTicker._();

  Ticker? _ticker;
  Duration _elapsed = Duration.zero;

  /// Elapsed seconds since the clock first started ticking.
  double get seconds => _elapsed.inMicroseconds / 1e6;

  void _onTick(Duration d) {
    _elapsed = d;
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _ticker ??= Ticker(_onTick)..start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _ticker?.dispose();
      _ticker = null;
    }
  }
}

/// Renders an [AvatarBorderPaint] as a live, self-repainting overlay driven by
/// the shared [AvatarBorderTicker]. Wrapped in a [RepaintBoundary] so a ticking
/// border repaints only itself, never the avatar or the surrounding list. Under
/// reduce-motion it paints one still frame and never subscribes to the clock.
class AnimatedAvatarBorder extends StatelessWidget {
  final AvatarBorderPaint paint;
  const AnimatedAvatarBorder({super.key, required this.paint});

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return CustomPaint(
        size: Size.infinite,
        painter: _BorderPainter(paint, 0, true),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: AvatarBorderTicker.instance,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _BorderPainter(paint, AvatarBorderTicker.instance.seconds, false),
        ),
      ),
    );
  }
}

class _BorderPainter extends CustomPainter {
  final AvatarBorderPaint _paint;
  final double t;
  final bool reduceMotion;
  _BorderPainter(this._paint, this.t, this.reduceMotion);

  @override
  void paint(Canvas canvas, Size size) => _paint(canvas, size, t, reduceMotion);

  @override
  bool shouldRepaint(covariant _BorderPainter old) =>
      old.t != t || old.reduceMotion != reduceMotion;
}
