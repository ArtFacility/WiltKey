import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Dart mirror of the relay's strip-slide puzzle answer derivation
/// (wiltkey_server/puzzle.go PuzzleAnswerFromSeed). Golden vectors are
/// SHARED with puzzle_test.go — change both sides together or the relay
/// will reject every correct-looking answer.
///
/// The client renders a sprite sliced into [strips] vertical strips and
/// displays it rotated by `k = sha256(seed + "k")[0] % strips`. The user
/// drags to apply an extra rotation u; the sprite locks in when k+u ≡ 0
/// (mod strips). [expectedUserAnswer] is what the relay verifies.
int stripRotationFromSeed(String seed, int strips) {
  if (strips <= 0) return 0;
  final sum = sha256.convert(utf8.encode('$seed' 'k'));
  return sum.bytes[0] % strips;
}

int expectedUserAnswer(String seed, int strips) {
  if (strips <= 0) return 0;
  final k = stripRotationFromSeed(seed, strips);
  return (strips - k) % strips;
}

/// Reassembles the 10×10 sprite hex with its vertical strip groups rotated
/// by [positions] (positive = rightward). Pure so the tester can verify the
/// visual round-trip without a device. The sprite hex is row-major
/// (grid[y*10+x]), so a vertical strip is a scatter-gather, not a substring.
String rotateSpriteStrips(String spriteHex, int strips, int positions) {
  const gridWidth = 10;
  if (strips <= 0 ||
      spriteHex.length != gridWidth * gridWidth ||
      gridWidth % strips != 0) {
    return spriteHex;
  }
  final colsPerStrip = gridWidth ~/ strips;

  String extractStrip(int s) {
    final buf = StringBuffer();
    for (var row = 0; row < gridWidth; row++) {
      for (var c = 0; c < colsPerStrip; c++) {
        buf.write(spriteHex[row * gridWidth + s * colsPerStrip + c]);
      }
    }
    return buf.toString();
  }

  final groups = List.generate(strips, extractStrip);
  final shift = ((positions % strips) + strips) % strips;
  final rotated = [...groups.sublist(shift), ...groups.sublist(0, shift)];

  final out = StringBuffer();
  for (var row = 0; row < gridWidth; row++) {
    for (var s = 0; s < strips; s++) {
      out.write(rotated[s].substring(
          row * colsPerStrip, (row + 1) * colsPerStrip));
    }
  }
  return out.toString();
}

/// Deterministic PRNG (xorshift32) seeded from the puzzle seed — the same
/// sprite must render from the same seed on every device/run.
class SeededRandom {
  int _state;
  SeededRandom(String seed) : _state = _seedState(seed);

  static int _seedState(String seed) {
    final bytes = sha256.convert(utf8.encode(seed)).bytes;
    var v = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
    if (v == 0) v = 0x9e3779b9;
    return v & 0xFFFFFFFF;
  }

  int next() {
    var x = _state;
    x ^= x << 13;
    x &= 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= x << 5;
    x &= 0xFFFFFFFF;
    _state = x;
    return x;
  }

  int nextInt(int max) => max <= 0 ? 0 : next() % max;
}

/// Builds the 10×10 symmetric pixel-art sprite for a seed (hex color-index
/// chars, '0' = transparent — the same format as onboarding avatars).
String puzzleSpriteFromSeed(String seed) {
  final rand = SeededRandom(seed);
  final numColors = rand.nextInt(2) + 2;
  final chosen = <int>{};
  while (chosen.length < numColors) {
    chosen.add(rand.nextInt(15) + 1);
  }
  final palette = chosen.toList();
  final grid = List.filled(100, '0');
  for (int y = 0; y < 10; y++) {
    for (int x = 0; x < 5; x++) {
      final colorIndex = palette[rand.nextInt(palette.length)];
      final colorChar = colorIndex.toRadixString(16);
      grid[y * 10 + x] = colorChar;
      grid[y * 10 + (9 - x)] = colorChar;
    }
  }
  return grid.join();
}
