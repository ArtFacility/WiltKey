import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/network/puzzle.dart';

// Golden vectors SHARED with wiltkey_server/puzzle_test.go — the Go relay
// and this Dart mirror must derive identical answers or every correct-looking
// solution gets rejected. Each row: {seed, client render rotation k,
// expected user answer (inverse rotation)}.
void main() {
  test('stripRotationFromSeed / expectedUserAnswer match the Go vectors', () {
    const vectors = <(String, int, int)>[
      ('00000000000000000000000000000000', 0, 0),
      ('a3f1c2b4d5e6f7089a1b2c3d4e5f60718', 0, 0),
      ('deadbeefcafebabe0123456789abcdef', 2, 3),
      ('cafebabe1234567890abcdefdeadbeef', 3, 2),
      ('ffffffffffffffffffffffffffffffff', 2, 3),
      ('0123456789abcdef0123456789abcdef', 4, 1),
      ('5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a', 3, 2),
      ('e2e3e4e5e6e7e8e9eaebecedeeeff0f1', 0, 0),
    ];
    for (final (seed, k, expected) in vectors) {
      expect(stripRotationFromSeed(seed, 5), k, reason: 'k for $seed');
      expect(expectedUserAnswer(seed, 5), expected, reason: 'answer for $seed');
    }
  });

  test('edge cases', () {
    expect(expectedUserAnswer('any', 0), 0);
    expect(expectedUserAnswer('any', 1), 0);
    for (final s in ['aa', 'bb', 'cc', 'dd', 'ee', 'ff', '0102', 'a1b2c3d4']) {
      final a = expectedUserAnswer(s, 5);
      expect(a, inInclusiveRange(0, 4), reason: 'answer in [0,5) for $s');
    }
  });

  test('rotateSpriteStrips round-trips and scatters correctly', () {
    // A sprite with a single marked cell per strip lets us track placement.
    // Strip i contains the marker at column 2i.
    final sprite = List.filled(100, '0');
    for (var i = 0; i < 5; i++) {
      sprite[i * 2] = (i + 1).toRadixString(16); // column 2i, row 0
    }
    final hex = sprite.join();

    // Rotating right by 1: strip 0's marker wraps to the LAST strip, and
    // strip 1's marker takes its place.
    final rotated = rotateSpriteStrips(hex, 5, 1);
    expect(rotated[0], '2'); // strip 1's marker now at column 0
    expect(rotated[8], '1'); // strip 0's marker wrapped to column 8

    // Full rotation returns the original.
    expect(rotateSpriteStrips(rotated, 5, 4), hex);
    expect(rotateSpriteStrips(hex, 5, 0), hex);
  });

  test('puzzleSpriteFromSeed is deterministic and symmetric', () {
    final a = puzzleSpriteFromSeed('deadbeefcafebabe0123456789abcdef');
    final b = puzzleSpriteFromSeed('deadbeefcafebabe0123456789abcdef');
    expect(a, b);
    expect(a.length, 100);
    // Horizontal mirror symmetry (same rule as onboarding avatars).
    for (var y = 0; y < 10; y++) {
      for (var x = 0; x < 5; x++) {
        expect(a[y * 10 + x], a[y * 10 + (9 - x)],
            reason: 'row $y col $x must mirror');
      }
    }
  });
}
