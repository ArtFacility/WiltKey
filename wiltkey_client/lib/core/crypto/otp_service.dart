import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class WiltkeyOtpService {
  static final Map<String, RandomAccessFile> _openFiles = {};
  static final Map<String, Future<void>> _locks = {};

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

  // Generates a high-entropy keystream file of size 'bufferSize' from 'seedHex'
  static Future<File> generateKeystreamFile(
    String contactId,
    String seedHex,
    int bufferSize,
  ) async {
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
      }
    }

    await sink.flush();
    await sink.close();
    return file;
  }

  // Generates a deterministic group keystream file identical on all devices given the same seed
  static Future<File> generateGroupKeystream(
    String groupId,
    String groupSeedHex,
    int totalSize,
  ) async {
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
    return xorWithKeystream('group_$groupId', data, offset);
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
}
