import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/state.dart';

void main() {
  group('computeGroupBudget', () {
    test('full own lane with free lanes -> full flower (was 1 petal bug)', () {
      // Lane full (1000/1000) inside a 1MB pad; pad-based charge would be ~0.001.
      final b = computeGroupBudget(
        isGroup: true,
        laneSize: 1000,
        remaining: 1000,
        additionalSlotCount: 0,
        freeLanes: 17,
        rawMaxBuffer: 1000000,
        rawCharge: 1000 / 1000000,
      );
      expect(b.fraction, 1.0);
      expect(b.usableRemaining, 18000); // 1000 own + 17*1000 free
      expect(b.usableCapacity, 18000);
    });

    test('empty own lane but free lanes remain -> still has budget', () {
      final b = computeGroupBudget(
        isGroup: true,
        laneSize: 1000,
        remaining: 0,
        additionalSlotCount: 0,
        freeLanes: 4,
        rawMaxBuffer: 1000000,
        rawCharge: 0,
      );
      expect(b.usableRemaining, 4000);
      expect(b.usableCapacity, 5000);
      expect(b.fraction, closeTo(0.8, 1e-9));
    });

    test('own lane empty and no free lanes -> wilted (fraction 0)', () {
      final b = computeGroupBudget(
        isGroup: true,
        laneSize: 1000,
        remaining: 0,
        additionalSlotCount: 0,
        freeLanes: 0,
        rawMaxBuffer: 1000000,
        rawCharge: 0,
      );
      expect(b.fraction, 0.0);
    });

    test('refill lanes count toward own capacity', () {
      final b = computeGroupBudget(
        isGroup: true,
        laneSize: 1000,
        remaining: 1500,
        additionalSlotCount: 1, // 2 lanes => capacity 2000
        freeLanes: 0,
        rawMaxBuffer: 1000000,
        rawCharge: 0,
      );
      expect(b.usableCapacity, 2000);
      expect(b.fraction, closeTo(0.75, 1e-9));
    });

    test('non-group falls back to raw charge', () {
      final b = computeGroupBudget(
        isGroup: false,
        laneSize: 0,
        remaining: 400,
        additionalSlotCount: 0,
        freeLanes: 0,
        rawMaxBuffer: 2000,
        rawCharge: 0.2,
      );
      expect(b.fraction, 0.2);
      expect(b.usableRemaining, 400);
      expect(b.usableCapacity, 2000);
    });
  });
}
