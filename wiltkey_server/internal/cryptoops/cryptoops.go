// Package cryptoops holds the pure shared math both the relay and its local
// tooling must agree on byte-for-byte. Extracted so cmd/puzzleplay (the
// endless puzzle tester) imports the SAME implementation instead of a
// drift-prone copy. Golden vectors live in the package-internal tests
// (puzzle_test.go) and the Dart mirror (wiltkey_client test/puzzle_golden_test.dart).
package cryptoops

import (
	"crypto/sha256"
	"fmt"
	"strings"
)

// VerifyPoW checks if SHA256(challenge + nonce_str + payload) has the required
// number of leading hex zeros. Byte-layout matches the Flutter solver
// (pow_solver.dart solvePoWSync).
func VerifyPoW(challenge string, nonce int64, payload string, difficulty int) bool {
	data := fmt.Sprintf("%s%d%s", challenge, nonce, payload)
	hash := sha256.Sum256([]byte(data))
	hashHex := hexEncode(hash[:])

	prefix := strings.Repeat("0", difficulty)
	return strings.HasPrefix(hashHex, prefix)
}

// PuzzleStrips is the strip count of the strip_slide human-verification
// puzzle (v1; owner-set — see HUMAN_VERIFICATION_DESIGN.md).
const PuzzleStrips = 5

// PuzzleAnswerFromSeed derives the expected user rotation u for a seed.
// MUST stay byte-identical with the Dart mirror (puzzle.dart +
// test/puzzle_golden_test.dart, which share vectors with puzzle_test.go).
func PuzzleAnswerFromSeed(seed string, strips int) int {
	if strips <= 0 {
		return 0
	}
	sum := sha256.Sum256([]byte(seed + "k"))
	k := int(sum[0]) % strips
	if k == 0 {
		return 0
	}
	return strips - k
}

func hexEncode(b []byte) string {
	const hexDigits = "0123456789abcdef"
	out := make([]byte, len(b)*2)
	for i, v := range b {
		out[i*2] = hexDigits[v>>4]
		out[i*2+1] = hexDigits[v&0x0F]
	}
	return string(out)
}
