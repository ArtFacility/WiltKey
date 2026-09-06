package main

import "testing"

// Golden vectors for PuzzleAnswerFromSeed. The Dart mirror
// (wiltkey_client/test/puzzle_golden_test.dart) shares THESE EXACT vectors —
// any change here must be mirrored there and vice versa. Each row:
// {seed, clientRenderRotation k, expected user answer (inverse rotation)}.
func TestPuzzleAnswerFromSeed(t *testing.T) {
	vectors := []struct {
		seed     string
		k        int
		expected int
	}{
		{"00000000000000000000000000000000", 0, 0},
		{"a3f1c2b4d5e6f7089a1b2c3d4e5f60718", 0, 0},
		{"deadbeefcafebabe0123456789abcdef", 2, 3},
		{"cafebabe1234567890abcdefdeadbeef", 3, 2},
		{"ffffffffffffffffffffffffffffffff", 2, 3},
		{"0123456789abcdef0123456789abcdef", 4, 1},
		{"5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a", 3, 2},
		{"e2e3e4e5e6e7e8e9eaebecedeeeff0f1", 0, 0},
	}
	for _, v := range vectors {
		got := PuzzleAnswerFromSeed(v.seed, puzzleStrips)
		if got != v.expected {
			t.Errorf("seed %s: got answer %d, want %d (k=%d)", v.seed, got, v.expected, v.k)
		}
	}
}

func TestPuzzleAnswerFromSeedEdges(t *testing.T) {
	if got := PuzzleAnswerFromSeed("any", 0); got != 0 {
		t.Errorf("strips=0 must return 0, got %d", got)
	}
	if got := PuzzleAnswerFromSeed("any", 1); got != 0 {
		t.Errorf("strips=1 must always return 0, got %d", got)
	}
	// Result must always land in [0, strips).
	for _, s := range []string{"aa", "bb", "cc", "dd", "ee", "ff", "0102", "a1b2c3d4"} {
		if got := PuzzleAnswerFromSeed(s, 5); got < 0 || got >= 5 {
			t.Errorf("seed %s: answer %d out of range [0,5)", s, got)
		}
	}
}
