import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Deferred-decrypt holding store for inbound frames received while the app is
/// locked (no master key in RAM).
///
/// The background WebSocket isolate (Instant mode) cannot decrypt or store
/// messages normally — the master key only exists while unlocked. But the server
/// drains the offline queue on connect and never re-queues live `NEW_MESSAGE`
/// frames, so if we drop them they are lost forever. Instead we append the *raw*
/// envelopes here (an append-only JSON-lines file) and the main isolate replays
/// them through the normal inbound path (`AppState.processPendingInbox`) the next
/// time the user unlocks.
///
/// A plain file is used rather than the SQLite DB to avoid cross-isolate write
/// lock contention between the background isolate and the main app.
class PendingInbox {
  static const String _fileName = 'wiltkey_pending_inbox.jsonl';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Append one raw inbound frame. Mirrors the args of
  /// `AppState._deliverMessageToState(senderId, envelope, contentType)`.
  static Future<void> append({
    required String senderId,
    required String envelope,
    required String contentType,
  }) async {
    try {
      final file = await _file();
      final line = jsonEncode({
        'sender_id': senderId,
        'envelope': envelope,
        'content_type': contentType,
        'received_at': DateTime.now().toIso8601String(),
      });
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Best-effort: a failed append must never crash the background isolate.
    }
  }

  /// Read every buffered frame (does not delete — call [clear] after the main
  /// isolate has successfully processed them, so a crash mid-replay can't drop
  /// messages).
  static Future<List<Map<String, dynamic>>> drainAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final lines = await file.readAsLines();
      final out = <Map<String, dynamic>>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          out.add(jsonDecode(line) as Map<String, dynamic>);
        } catch (_) {
          // Skip a corrupt line rather than aborting the whole replay.
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<bool> hasPending() async {
    try {
      final file = await _file();
      return await file.exists() && await file.length() > 0;
    } catch (_) {
      return false;
    }
  }
}
