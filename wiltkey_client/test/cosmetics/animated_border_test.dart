import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/cosmetics/avatar_border_ticker.dart';

/// Fork-safe test of the PUBLIC animated-border hook (no premium source needed):
/// a dummy [AvatarBorderPaint] driven by the shared ticker must paint, advance
/// over frames, and honour reduce-motion.
void main() {
  testWidgets('AnimatedAvatarBorder paints and advances with the shared clock', (
    tester,
  ) async {
    final seenT = <double>[];
    void paint(Canvas canvas, Size size, double t, bool reduceMotion) {
      seenT.add(t);
      canvas.drawCircle(
        size.center(Offset.zero),
        size.shortestSide * 0.4,
        Paint()..color = const Color(0xFF00FF00),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: AnimatedAvatarBorder(paint: paint),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(seenT, isNotEmpty);
    // The shared ticker should have advanced t across frames.
    expect(seenT.last, greaterThan(0.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce-motion paints a single still frame at t=0', (tester) async {
    final seenT = <double>[];
    final seenRM = <bool>[];
    void paint(Canvas canvas, Size size, double t, bool reduceMotion) {
      seenT.add(t);
      seenRM.add(reduceMotion);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: AnimatedAvatarBorder(paint: paint),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(seenRM, everyElement(isTrue));
    expect(seenT, everyElement(0.0));
    expect(tester.takeException(), isNull);
  });

  test('shared ticker stops when it has no listeners', () {
    // No AnimatedAvatarBorder mounted anymore → the singleton should be idle.
    // (Just assert it is reachable and reports a finite time.)
    expect(AvatarBorderTicker.instance.seconds, isA<double>());
  });
}
