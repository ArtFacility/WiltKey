import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class WiltkeyOtpService {
  static final Map<String, RandomAccessFile> _openFiles = {};
  static final Map<String, Future<void>> _locks = {};

  // In-memory cache of group seeds so group keystream can be computed on demand
  // instead of read from a giant on-disk `.pad`. The "pad" is a deterministic
  // SHA-256 counter-mode keystream, so any byte is recomputable from (seed,
  // offset) — dropping the file is a pure space win with zero security change
  // (a 500 MB group pad → a 32-byte seed). Populated wherever a group contact
  // enters memory (DB load, host-create, member-join); the invariant is
  // "every group in AppState.contacts has its seed cached here", so
  // xorWithGroupKeystream never misses for a live group. Never persisted here —
  // the seed already lives in the DB (`group_seed` / `group_seed_encrypted`).
  static final Map<String, ({String seed, int totalSize})> _groupSeeds = {};

  /// Cache a group's seed so its keystream is computed on the fly. [totalSize]
  /// is the logical keystream ceiling (bytes) used as an overflow guard,
  /// replacing the old physical `file.length()` check. Call on group create /
  /// join and for every group contact loaded from the DB.
  static void cacheGroupSeed(String groupId, String seedHex, int totalSize) {
    if (seedHex.isEmpty) return;
    _groupSeeds[groupId] = (seed: seedHex, totalSize: totalSize);
  }

  /// Drop a cached group seed (on nuke / archive / leave). Harmless if absent —
  /// a stale entry only costs RAM, but clearing keeps key material out of memory
  /// once a group is gone.
  static void clearGroupSeed(String groupId) {
    _groupSeeds.remove(groupId);
  }

  // Safely close and release open file descriptor
  static Future<void> closeKeystreamFile(String contactId) async {
    final raf = _openFiles.remove(contactId);
    if (raf != null) {
      try {
        await raf.close();
      } catch (e) {
        print(
          '[Crypto Error] Failed to close keystream file for $contactId: $e',
        );
      }
    }
  }

  static Future<RandomAccessFile> _getOpenFile(
    String contactId,
    File file,
  ) async {
    final existing = _openFiles[contactId];
    if (existing != null) {
      return existing;
    }
    final raf = await file.open(mode: FileMode.read);
    _openFiles[contactId] = raf;
    return raf;
  }

  // Generates a high-entropy keystream file of size 'bufferSize' from 'seedHex'.
  // [onProgress] (bytesWritten, total) fires once per flushed chunk so callers can
  // drive a real progress bar — a large pad (up to 500 MB now) can take many
  // seconds and the UI must not look frozen.
  static Future<File> generateKeystreamFile(
    String contactId,
    String seedHex,
    int bufferSize, {
    void Function(int written, int total)? onProgress,
  }) async {
    await closeKeystreamFile(contactId);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/keystream_$contactId.pad');

    // Overwrite any existing pad (e.g. on recharge/re-pairing)
    final seedBytes = utf8.encode(seedHex);
    final IOSink sink = file.openWrite();

    int bytesWritten = 0;
    int counter = 0;

    // Use a 128 KB buffer to hash in chunks, preventing main thread frame stalls
    final int chunkSize = 4096 * 32;
    final chunk = Uint8List(chunkSize);
    int chunkIdx = 0;

    while (bytesWritten < bufferSize) {
      final counterBytes = _intToBytes(counter);
      final hashInput = [...seedBytes, ...counterBytes];
      final hash = sha256.convert(hashInput).bytes;

      for (int i = 0; i < 32; i++) {
        if (bytesWritten + i >= bufferSize) break;
        chunk[chunkIdx++] = hash[i];
      }
      bytesWritten += 32;
      counter++;

      if (chunkIdx >= chunkSize || bytesWritten >= bufferSize) {
        sink.add(chunk.sublist(0, chunkIdx));
        chunkIdx = 0;
        // Yield to the event loop so large pads don't freeze the UI / trigger ANR.
        await Future.delayed(Duration.zero);
        onProgress?.call(
          bytesWritten > bufferSize ? bufferSize : bytesWritten,
          bufferSize,
        );
      }
    }

    await sink.flush();
    await sink.close();
    return file;
  }

  // Generates a deterministic group keystream file identical on all devices given
  // the same seed. [onProgress] (bytesWritten, total) fires once per flushed chunk.
  static Future<File> generateGroupKeystream(
    String groupId,
    String groupSeedHex,
    int totalSize, {
    void Function(int written, int total)? onProgress,
  }) async {
    final cacheKey = 'group_$groupId';
    await closeKeystreamFile(cacheKey);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/keystream_group_$groupId.pad');

    final seedBytes = utf8.encode(groupSeedHex);
    final IOSink sink = file.openWrite();

    int bytesWritten = 0;
    int counter = 0;

    final int chunkSize = 4096 * 32;
    final chunk = Uint8List(chunkSize);
    int chunkIdx = 0;

    while (bytesWritten < totalSize) {
      final counterBytes = _intToBytes(counter);
      final hashInput = [...seedBytes, ...counterBytes];
      final hash = sha256.convert(hashInput).bytes;

      for (int i = 0; i < 32; i++) {
        if (bytesWritten + i >= totalSize) break;
        chunk[chunkIdx++] = hash[i];
      }
      bytesWritten += 32;
      counter++;

      if (chunkIdx >= chunkSize || bytesWritten >= totalSize) {
        sink.add(chunk.sublist(0, chunkIdx));
        chunkIdx = 0;
        // Yield to the event loop so large pads don't freeze the UI / trigger ANR.
        await Future.delayed(Duration.zero);
        onProgress?.call(
          bytesWritten > totalSize ? totalSize : bytesWritten,
          totalSize,
        );
      }
    }

    await sink.flush();
    await sink.close();
    return file;
  }

  static Future<List<int>> xorWithGroupKeystream(
    String groupId,
    List<int> data,
    int offset,
  ) async {
    // Compute-on-demand path: if we have the seed cached (every live group
    // does), derive the keystream bytes directly — no file, no lock, pure
    // function. keystreamRange is proven byte-identical to a generated pad by
    // the golden test, so this is bit-for-bit compatible with old on-disk pads
    // and with FOSS/Play peers still writing files.
    final entry = _groupSeeds[groupId];
    if (entry != null) {
      final total = entry.totalSize;
      if (total > 0 && offset + data.length > total) {
        throw Exception(
          'Group keystream overflow! Needed offset ${offset + data.length}, '
          'logical size $total',
        );
      }
      final ks = keystreamRange(entry.seed, offset, data.length);
      final result = List<int>.filled(data.length, 0);
      for (int i = 0; i < data.length; i++) {
        result[i] = data[i] ^ ks[i];
      }
      return result;
    }
    // Legacy fallback: no cached seed (e.g. a not-yet-migrated on-disk pad).
    // Reads the file exactly as before so nothing regresses during rollout.
    return xorWithKeystream('group_$groupId', data, offset);
  }

  /// Byte gap between the two lanes of a Time Wilt 1:1 chat. Each side sends
  /// from its own base (0 for the lower userId, this value for the higher), so
  /// the two keystreams can never overlap. The gap dwarfs any real chat, and the
  /// 64-bit block counter (see [keystreamRange] `wideCounter`) reaches well past
  /// it, so neither lane can run into the other in practice.
  static const int kWiltLaneStride = 1 << 55;

  /// On-demand keystream XOR for Time Wilt 1:1 chats: derives `data.length`
  /// keystream bytes from [seedHex] at absolute byte [offset] and XORs them in.
  /// Unlike byte-budget 1:1 there is no stored pad file — the keystream is
  /// computed straight from the persisted seed (like groups), using the 64-bit
  /// counter because Time Wilt offsets are time-unbounded. Pure and symmetric:
  /// the same call both encrypts and decrypts.
  static Future<List<int>> xorWithStreamSeed(
    String seedHex,
    List<int> data,
    int offset,
  ) async {
    final ks = keystreamRange(seedHex, offset, data.length, wideCounter: true);
    final out = List<int>.filled(data.length, 0);
    for (int i = 0; i < data.length; i++) {
      out[i] = data[i] ^ ks[i];
    }
    return out;
  }

  /// Computes `length` keystream bytes starting at absolute byte [offset] for a
  /// pad derived from [seedHex], WITHOUT any file I/O. This is the on-demand
  /// equivalent of reading `[offset, offset+length)` out of a pad produced by
  /// [generateGroupKeystream] / [generateKeystreamFile], and MUST stay
  /// byte-identical to them (guarded by the golden test — drift here means
  /// silent, total loss of history). Pure and stateless, so it needs no lock.
  ///
  /// [wideCounter] selects a 64-bit block counter instead of the default
  /// 32-bit one. Existing pads (all groups + 1:1) use the 32-bit counter, so
  /// leave it false for them. The 64-bit counter exists for the future
  /// **time-wilt** mode: an unbounded (time-, not byte-bounded) offset can
  /// exceed the 32-bit counter's ~137 GB reach, so time-wilt streams must widen
  /// it to avoid counter wraparound / keystream reuse. Not wired to anything
  /// live yet — this is groundwork for that feature.
  static Uint8List keystreamRange(
    String seedHex,
    int offset,
    int length, {
    bool wideCounter = false,
  }) {
    final out = Uint8List(length);
    if (length <= 0) return out;

    final seedBytes = utf8.encode(seedHex);
    const blockSize = 32;
    final startBlock = offset ~/ blockSize;
    final endBlock = (offset + length - 1) ~/ blockSize;

    int outPos = 0;
    for (int n = startBlock; n <= endBlock; n++) {
      final counterBytes = wideCounter ? _intToBytes64(n) : _intToBytes(n);
      final block = sha256.convert([...seedBytes, ...counterBytes]).bytes;
      final blockStart = n * blockSize;
      for (int i = 0; i < blockSize; i++) {
        final abs = blockStart + i;
        if (abs < offset) continue;
        if (abs >= offset + length) break;
        out[outPos++] = block[i];
      }
    }
    return out;
  }

  static Future<void> deleteGroupKeystreamFile(String groupId) async {
    return deleteKeystreamFile('group_$groupId');
  }

  // Encrypts/decrypts bytes by XORing with the keystream file starting at 'offset'
  static Future<List<int>> xorWithKeystream(
    String contactId,
    List<int> data,
    int offset,
  ) async {
    // Acquire lock for serialized access
    final prevLock = _locks[contactId] ?? Future.value();
    final completer = Completer<void>();
    _locks[contactId] = completer.future;
    await prevLock;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/keystream_$contactId.pad');

      if (!await file.exists()) {
        throw Exception('Keystream file not found for contact $contactId');
      }

      final fileLength = await file.length();
      if (offset + data.length > fileLength) {
        throw Exception(
          'Keystream buffer overflow! Needed offset ${offset + data.length}, file size $fileLength',
        );
      }

      // Read from cached open RandomAccessFile descriptor
      final raf = await _getOpenFile(contactId, file);
      await raf.setPosition(offset);
      final keystreamBytes = await raf.read(data.length);

      final result = List<int>.filled(data.length, 0);
      for (int i = 0; i < data.length; i++) {
        result[i] = data[i] ^ keystreamBytes[i];
      }
      return result;
    } finally {
      completer.complete();
    }
  }

  static Future<void> deleteKeystreamFile(String contactId) async {
    await closeKeystreamFile(contactId);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/keystream_$contactId.pad');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// True when the existing pad file for [contactId] was generated from
  /// [seedHex] (compares the first keystream block against the file's head).
  /// Cheap replay detector: a recharge that would regenerate the SAME pad
  /// (same seed) and reset offsets would re-encrypt into already-burned
  /// keystream — callers must refuse instead. No file → false (fresh pair).
  static Future<bool> padMatchesSeed(String contactId, String seedHex) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/keystream_$contactId.pad');
    if (!await file.exists()) return false;

    final raf = await file.open();
    try {
      final head = await raf.read(32);
      final expected = keystreamRange(seedHex, 0, 32);
      for (int i = 0; i < 32; i++) {
        if (head[i] != expected[i]) return false;
      }
      return true;
    } finally {
      await raf.close();
    }
  }

  // Returns the contactId of every keystream pad currently on disk. 1-on-1 pads
  // are 'keystream_<id>.pad'; group pads are 'keystream_group_<groupId>.pad', so
  // those come back as 'group_<groupId>' — exactly the id form that
  // deleteKeystreamFile / xorWithKeystream expect (the same cache key used in
  // _openFiles), so the result can be fed straight back into delete calls.
  static Future<List<String>> listPadIds() async {
    final directory = await getApplicationDocumentsDirectory();
    final dir = Directory(directory.path);
    if (!await dir.exists()) return [];

    const prefix = 'keystream_';
    const suffix = '.pad';
    final ids = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.startsWith(prefix) && name.endsWith(suffix)) {
        ids.add(name.substring(prefix.length, name.length - suffix.length));
      }
    }
    return ids;
  }

  // Deletes every pad on disk whose id is not in [keepIds]. Used to reclaim disk
  // space from pads with no live contact — failed/incomplete pairings, peer nukes
  // that arrived while we were offline, and crashed recharges. Returns the ids
  // that were removed so the caller can clean up any associated metadata.
  static Future<List<String>> reconcilePads(Set<String> keepIds) async {
    final deleted = <String>[];
    for (final id in await listPadIds()) {
      if (keepIds.contains(id)) continue;
      try {
        await deleteKeystreamFile(id);
        deleted.add(id);
      } catch (e) {
        print('[Crypto Error] Failed to reconcile orphan pad $id: $e');
      }
    }
    return deleted;
  }

  static List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  // 64-bit big-endian counter for the future time-wilt keystream (unbounded
  // offsets). Same big-endian layout as _intToBytes, just 8 bytes wide.
  static List<int> _intToBytes64(int value) {
    return [
      (value >> 56) & 0xFF,
      (value >> 48) & 0xFF,
      (value >> 40) & 0xFF,
      (value >> 32) & 0xFF,
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}
