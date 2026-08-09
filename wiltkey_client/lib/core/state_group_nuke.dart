part of 'state.dart';

/// Group "destroy for everyone" as a **majority vote**, not a unilateral wipe.
///
/// Any member can PROPOSE destroying the group; a majority of the OTHER members
/// must approve, and only then does it wipe on every device. This closes the
/// hole where a single member could vaporize everyone's history at will.
///
/// The vote is only a GATE — the actual destruction reuses the existing
/// [AppState.nukeGroup] fan-out (`group_nuke` → each device scoped-destroys), so
/// the destructive primitive is unchanged; we just require consensus first.
///
/// Transport mirrors [AppStateScreenshot]: control frames on the group's AES
/// metadata channel (SHA256(groupSeed)), never the keystream. Two content types:
/// `group_nuke_request` / `group_nuke_response`. Best-effort and fail-safe: a
/// lost frame or an offline proposer just means the group is NOT destroyed.

/// A peer's proposal to destroy the group — surfaced as an in-chat voting card.
class GroupNukeRequestEvent {
  final String contactId; // local Contact.id
  final String requesterId; // keyHash to send our vote back to
  final String requesterName; // display name for the card
  final String requestId;
  const GroupNukeRequestEvent({
    required this.contactId,
    required this.requesterId,
    required this.requesterName,
    required this.requestId,
  });
}

/// The proposer's in-flight tally for one outstanding proposal.
class GroupNukeSession {
  final String requestId;
  final String contactId;
  final String groupKeyHash;
  final int needed; // approvals required
  final int totalPeers; // how many we asked
  final Set<String> accepted = {};
  final Set<String> responded = {};
  Timer? timeout;
  GroupNukeSession({
    required this.requestId,
    required this.contactId,
    required this.groupKeyHash,
    required this.needed,
    required this.totalPeers,
  });
}

/// How long a received proposal card stays actionable before it wilts to
/// "expired". Longer than the proposer's tally window so a late (queued) card is
/// still visible as a record.
const int kGroupNukeRequestTtlSeconds = 180;

extension AppStateGroupNuke on AppState {
  String _newGroupNukeRequestId() {
    final u = userId.length >= 8 ? userId.substring(0, 8) : userId;
    return '${u}_${DateTime.now().microsecondsSinceEpoch}';
  }

  String? _groupMetaKeyHex(Contact group) {
    final seed = group.groupSeed ?? '';
    if (seed.isEmpty) return null;
    return sha256.convert(utf8.encode(seed)).toString();
  }

  /// Propose destroying [group] for everyone. A solo group (no other members)
  /// is destroyed immediately; otherwise a majority of the other members must
  /// approve before the wipe fans out.
  Future<void> proposeGroupNuke(Contact group) async {
    if (!group.isGroup) return;
    final peers = group.memberKeyHashes.where((h) => h != userId).toList();
    if (peers.isEmpty) {
      // No one else to ask — just destroy locally (+ fan-out is a no-op).
      await nukeGroup(group);
      return;
    }
    final keyHex = _groupMetaKeyHex(group);
    if (keyHex == null) return;

    final requestId = _newGroupNukeRequestId();
    final needed = (peers.length ~/ 2) + 1;
    final session = GroupNukeSession(
      requestId: requestId,
      contactId: group.id,
      groupKeyHash: group.keyHash,
      needed: needed,
      totalPeers: peers.length,
    );
    session.timeout = Timer(
      const Duration(seconds: kGroupNukeRequestTtlSeconds), () {
        if (groupNukeSessions.remove(requestId) != null) {
          _addGroupNukeSystemNote(group.id, _groupNukeFailedNote());
        }
      },
    );
    groupNukeSessions[requestId] = session;

    final enc = WiltkeyPersistence().encryptString(
      jsonEncode({'req_id': requestId, 'v': 1}),
      keyHex,
    );
    final envelope = jsonEncode({
      'group_id': group.keyHash,
      'sender_id': userId,
      'd': enc,
      't': 'group_nuke_request',
    });
    await ensureWebSocketConnected();
    for (final memberHash in peers) {
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': memberHash,
        'envelope': envelope,
        'content_type': 'group_nuke_request',
      });
    }
    _addGroupNukeSystemNote(group.id, _groupNukeSentNote());
  }

  /// Cast our vote on a peer's proposal (from the in-chat voting card).
  Future<void> respondToGroupNuke(
    GroupNukeRequestEvent ev,
    bool accept,
  ) async {
    final idx = contacts.indexWhere((c) => c.id == ev.contactId);
    if (idx == -1) return;
    final group = contacts[idx];
    final keyHex = _groupMetaKeyHex(group);
    if (keyHex == null) return;
    await ensureWebSocketConnected();
    final enc = WiltkeyPersistence().encryptString(
      jsonEncode({'req_id': ev.requestId, 'accept': accept, 'v': 1}),
      keyHex,
    );
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': ev.requesterId,
      'envelope': jsonEncode({
        'group_id': group.keyHash,
        'sender_id': userId,
        'd': enc,
        't': 'group_nuke_response',
      }),
      'content_type': 'group_nuke_response',
    });
    await _resolveGroupNukeCard(
      ev.contactId,
      ev.requestId,
      accept ? 'accepted' : 'declined',
    );
  }

  /// Answer straight from the in-history voting card.
  Future<void> respondToGroupNukeCard(
    Contact group,
    ChatMessage card,
    bool accept,
  ) async {
    final ev = _groupNukeEventFromCard(group, card);
    if (ev == null) return;
    await respondToGroupNuke(ev, accept);
  }

  // --- Inbound ---

  Future<void> _handleGroupNukeRequest(
    Contact group,
    String senderId,
    Map<String, dynamic> envelopeJson,
  ) async {
    final keyHex = _groupMetaKeyHex(group);
    if (keyHex == null) return;
    try {
      final dec = WiltkeyPersistence().decryptString(
        envelopeJson['d'] as String,
        keyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      final reqId = p['req_id'] as String?;
      if (reqId == null) return;
      final name =
          groupProfilesCache[group.keyHash]?[senderId]?['name'] ?? group.name;
      final ev = GroupNukeRequestEvent(
        contactId: group.id,
        requesterId: senderId,
        requesterName: name,
        requestId: reqId,
      );
      await _insertGroupNukeCard(group, ev);
    } catch (e) {
      log('[GroupNuke Error] request: $e');
    }
  }

  Future<void> _handleGroupNukeResponse(
    Contact group,
    String senderId,
    Map<String, dynamic> envelopeJson,
  ) async {
    final keyHex = _groupMetaKeyHex(group);
    if (keyHex == null) return;
    try {
      final dec = WiltkeyPersistence().decryptString(
        envelopeJson['d'] as String,
        keyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      await _tallyGroupNukeResponse(
        group,
        senderId,
        p['req_id'] as String?,
        p['accept'] == true,
      );
    } catch (e) {
      log('[GroupNuke Error] response: $e');
    }
  }

  /// Fold one vote into the outstanding proposal. On reaching [needed] approvals
  /// → destroy the group for everyone (reusing the existing fan-out). If everyone
  /// voted and it fell short → mark the proposal failed. Idempotent per voter.
  Future<void> _tallyGroupNukeResponse(
    Contact group,
    String responderId,
    String? reqId,
    bool accept,
  ) async {
    if (reqId == null) return;
    final session = groupNukeSessions[reqId];
    if (session == null) return; // not ours / already resolved
    if (session.responded.contains(responderId)) return;
    session.responded.add(responderId);
    if (accept) session.accepted.add(responderId);

    if (session.accepted.length >= session.needed) {
      session.timeout?.cancel();
      groupNukeSessions.remove(reqId);
      // Majority reached → wipe on every device (proposer included).
      await nukeGroup(group);
    } else if (session.responded.length >= session.totalPeers) {
      session.timeout?.cancel();
      groupNukeSessions.remove(reqId);
      _addGroupNukeSystemNote(group.id, _groupNukeFailedNote());
    }
  }

  // --- In-history voting card (persistent + expiry via the wilt engine) ---

  String _gnCardId(String requestId) => 'gnreq_$requestId';

  Future<void> _insertGroupNukeCard(
    Contact group,
    GroupNukeRequestEvent ev,
  ) async {
    final msgId = _gnCardId(ev.requestId);
    if (await WiltkeyDatabase.instance.messageExists(group.id, id: msgId)) {
      return;
    }
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final expiresMs = nowMs + kGroupNukeRequestTtlSeconds * 1000;
    final payload = jsonEncode({
      'req_id': ev.requestId,
      'requester_id': ev.requesterId,
      'requester_name': ev.requesterName,
      'status': 'pending',
    });
    final msg = ChatMessage(
      id: msgId,
      senderId: ev.requesterId,
      text: payload, // control payload, stored plaintext (no keystream)
      contentType: 'group_nuke_request',
      timestamp: now,
      isSentByMe: false,
      ephemeral: true, // expiry only — never emits a wilt confirmation
      ttlSeconds: kGroupNukeRequestTtlSeconds,
      openedAt: nowMs,
      expiresAt: expiresMs,
    );
    await WiltkeyDatabase.instance.saveMessage(msg, group.id);
    appendLoadedMessage(group.id, msg);
    _armWiltTimer(group.id, msgId, expiresMs);
    bumpUnread(group, msg);
    notifyListeners();
    if (visibleChatId != group.id) {
      WiltkeyNotifications.showMessageNotification(chatKey: group.keyHash);
    }
  }

  GroupNukeRequestEvent? _groupNukeEventFromCard(
    Contact group,
    ChatMessage card,
  ) {
    try {
      final p = jsonDecode(card.text) as Map<String, dynamic>;
      return GroupNukeRequestEvent(
        contactId: group.id,
        requesterId: p['requester_id'] as String,
        requesterName: p['requester_name'] as String? ?? group.name,
        requestId: p['req_id'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _resolveGroupNukeCard(
    String contactId,
    String requestId,
    String status,
  ) async {
    final msgId = _gnCardId(requestId);
    _cancelWiltTimer(msgId);

    final list = messages[contactId];
    Map<String, dynamic> payload = {};
    ChatMessage? old;
    if (list != null) {
      for (final m in list) {
        if (m.id == msgId) {
          old = m;
          break;
        }
      }
    }
    if (old != null) {
      try {
        payload = jsonDecode(old.text) as Map<String, dynamic>;
      } catch (_) {}
    }
    payload['status'] = status;
    final newText = jsonEncode(payload);
    await WiltkeyDatabase.instance.resolveControlMessageRow(msgId, newText);

    if (old != null && list != null) {
      final idx = list.indexOf(old);
      if (idx != -1) {
        list[idx] = ChatMessage(
          id: old.id,
          senderId: old.senderId,
          text: newText,
          contentType: 'group_nuke_request',
          timestamp: old.timestamp,
          isSentByMe: old.isSentByMe,
          ephemeral: false, // resolved — no longer expiring
        );
      }
    }
    notifyListeners();
  }

  // --- System notes ---

  String _groupNukeSentNote() => 'You proposed destroying this group for '
      'everyone. Waiting for members to vote.';
  String _groupNukeFailedNote() =>
      'The proposal to destroy the group did not pass.';

  void _addGroupNukeSystemNote(String contactId, String text) {
    final msg = ChatMessage(
      id: 'system_${DateTime.now().microsecondsSinceEpoch}',
      senderId: 'system',
      text: text,
      timestamp: DateTime.now(),
      isSentByMe: false,
      decryptedText: text,
    );
    appendLoadedMessage(contactId, msg);
    WiltkeyDatabase.instance.saveMessage(msg, contactId, masterKeyHex: masterKeyHex);
    notifyListeners();
  }
}
