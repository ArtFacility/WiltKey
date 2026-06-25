import 'dart:math';
import 'package:flutter/material.dart';
import '../../wiltkey_components.dart';
import '../../wk.dart';

/// Cyberpunk proximity scan effect: the rotating radar sweep with device dots
/// and a terminal-log tail. Moved here from the old `radar_scanner.dart` and
/// decoupled from the BLE controller (it now takes neutral [SyncBlip]s), so the
/// theme layer never imports a feature controller. Owns its own sweep
/// controller. Only the `scanning` state has a bespoke visual; the later sync
/// states keep the inline progress/success cards for now.
class CyberpunkSyncVisual extends StatefulWidget {
  final List<SyncBlip> blips;
  final List<String> log;

  const CyberpunkSyncVisual({
    super.key,
    required this.blips,
    required this.log,
  });

  @override
  State<CyberpunkSyncVisual> createState() => _CyberpunkSyncVisualState();
}

class _CyberpunkSyncVisualState extends State<CyberpunkSyncVisual>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wantMotion = !context.reduceMotion;
    if (wantMotion && _pulse == null) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat();
    } else if (!wantMotion && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: t.bg,
        border: Border.all(color: t.positive.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _pulse == null
                ? CustomPaint(
                    painter: _RadarPainter(
                      blips: widget.blips,
                      pulseValue: 0,
                      ringColor: t.positive,
                      sweepColor: t.action,
                      nearColor: t.action,
                      farColor: t.positive,
                      farDeviceColor: t.textTertiary,
                    ),
                  )
                : AnimatedBuilder(
                    animation: _pulse!,
                    builder: (context, child) => CustomPaint(
                      painter: _RadarPainter(
                        blips: widget.blips,
                        pulseValue: _pulse!.value,
                        ringColor: t.positive,
                        sweepColor: t.action,
                        nearColor: t.action,
                        farColor: t.positive,
                        farDeviceColor: t.textTertiary,
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Row(
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: t.action,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t.uppercaseLabels
                      ? 'BLE SCANNING ACTIVE (FOUND: ${widget.blips.length})'
                      : 'Scanning nearby · ${widget.blips.length} found',
                  style: t.dataMono.copyWith(
                    color: t.textTertiary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 10,
            bottom: 8,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: widget.log.skip(max(0, widget.log.length - 5)).map((
                line,
              ) {
                return Text(
                  line,
                  style: t.dataMono.copyWith(
                    color: t.textTertiary,
                    fontSize: 8.5,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<SyncBlip> blips;
  final double pulseValue;
  final Color ringColor;
  final Color sweepColor;
  final Color nearColor;
  final Color farColor;
  final Color farDeviceColor;

  _RadarPainter({
    required this.blips,
    required this.pulseValue,
    required this.ringColor,
    required this.sweepColor,
    required this.nearColor,
    required this.farColor,
    required this.farDeviceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ringColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width / 2, size.height / 2) - 10;

    canvas.drawCircle(center, maxRadius * 0.25, paint);
    canvas.drawCircle(center, maxRadius * 0.5, paint);
    canvas.drawCircle(center, maxRadius * 0.75, paint);
    canvas.drawCircle(center, maxRadius, paint);

    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      paint,
    );

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          sweepColor.withValues(alpha: 0.0),
          sweepColor.withValues(alpha: 0.4),
        ],
        stops: const [0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pulseValue * 2 * pi);

    final sweepRect = Rect.fromCircle(
      center: const Offset(0, 0),
      radius: maxRadius,
    );
    final sweepPath = Path()
      ..moveTo(0, 0)
      ..arcTo(sweepRect, -pi / 4, pi / 4, false)
      ..close();
    canvas.drawPath(sweepPath, sweepPaint);
    canvas.restore();

    for (final dev in blips) {
      // strength: 1 = near (center), 0 = far (edge) — preserves old RSSI mapping.
      final r = (1.0 - dev.strength.clamp(0.0, 1.0)) * maxRadius;
      final dx = center.dx + r * cos(dev.angle);
      final dy = center.dy + r * sin(dev.angle);

      final dotPaint = Paint()
        ..color = dev.isWiltkey
            ? (dev.isNear ? nearColor : farColor)
            : farDeviceColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dx, dy), 5, dotPaint);

      if (dev.isNear) {
        canvas.drawCircle(
          Offset(dx, dy),
          12 * (pulseValue % 1.0),
          Paint()
            ..color = nearColor.withValues(alpha: 1.0 - (pulseValue % 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || oldDelegate.blips != blips;
  }
}
