part of 'state.dart';

/// Consensual screenshots. `FLAG_SECURE` blocks the OS from ever capturing the
/// screen — so instead of poking a hole in it, the requester's app renders the
/// chat view to an image **itself** (a `RepaintBoundary`, which is a layer-tree
/// render, not an OS window-buffer read, so `FLAG_SECURE` doesn't stop it) —
/// but only AFTER the other side(s) consent.
///
/// Transport mirrors [AppStateReactions]: a control frame on the AES metadata
/// channel (1-on-1 = per-contact meta key; group = SHA256(groupSeed)), never the
/// OTP pad. Four content types: `screenshot_request` / `screenshot_response`
/// (1-on-1) and `group_screenshot_request` / `group_screenshot_response`.
///
/// Flow: requester A sends a request → peer(s) accept/decline → A tallies
/// (1-on-1 = the single peer; group = a majority of the other members) → on
/// approval A fires [screenshotCaptureSignal] and its own chat screen captures +
/// opens the saved image in the viewer. A decline/timeout fires
/// [screenshotDeniedSignal] for a toast. Best-effort: a lost frame just means the
/// capture never happens (nothing is ever captured without approval).

/// A peer's request for us to consent to a screenshot — surfaced to the UI (the
/// shell shows the Allow/Deny dialog).
class ScreenshotRequestEvent {
  final String contactId; // local Contact.id of the chat
  final String requesterId; // keyHash to send our response back to
  final String requesterName; // display name for the dialog
  final String requestId;
  final bool isGroup;
  const ScreenshotRequestEvent({
    required this.contactId,
    required this.requesterId,
    required this.requesterName,
    required this.requestId,
    required this.isGroup,
  });
}

/// The requester's in-flight tally for one outstanding request.
class ScreenshotSession {
  final String requestId;
  final String contactId;
  final bool isGroup;
  final int needed; // approvals required to proceed
  final Set<String> accepted = {}; // responder keyHashes that said yes
  final Set<String> responded = {}; // responder keyHashes that answered at all
  final int totalPeers; // how many peers we asked (group)
  Timer? timeout;
  ScreenshotSession({
    required this.requestId,
    required this.contactId,
    required this.isGroup,
    required this.needed,
    required this.totalPeers,
  });
}

/// How long a received screenshot-request card stays actionable before it wilts
/// into "request expired". A bit longer than the requester's 45s tally window so
/// a card that arrived late (offline queue) is still visible as a record.
const int kScreenshotRequestTtlSeconds = 120;

extension AppStateScreenshot on AppState {
  String _newScreenshotRequestId() {
    final u = userId.length >= 8 ? userId.substring(0, 8) : userId;
    return '${u}_${DateTime.now().microsecondsSinceEpoch}';
  }

  /// Kick off a consensual screenshot of [contact]'s chat. Sends the request to
  /// the peer (1-on-1) or every member (group) and starts a tally that fires
  /// [screenshotCaptureSignal] once enough approvals arrive.
  Future<void> requestScreenshot(Contact contact) async {
    final requestId = _newScreenshotRequestId();

    if (contact.isGroup) {
      final peers = contact.memberKeyHashes
          .where((h) => h != userId)
          .toList();
      // Solo group (no one else to ask) → capture immediately.
      if (peers.isEmpty) {
        screenshotCaptureSignal.value = contact.id;
        return;
      }
      // Majority of the OTHER members must approve.
      final needed = (peers.length ~/ 2) + 1;
      _startScreenshotSession(
        requestId: requestId,
        contactId: contact.id,
        isGroup: true,
        needed: needed,
        totalPeers: peers.length,
      );

      final seed = contact.groupSeed ?? '';
      if (seed.isEmpty) return;
      final keyHex = sha256.convert(utf8.encode(seed)).toString();
      final enc = WiltkeyPersistence().encryptString(
        jsonEncode({'req_id': requestId, 'v': 1}),
        keyHex,
      );
      final envelope = jsonEncode({
        'group_id': contact.keyHash,
        'sender_id': userId,
        'd': enc,
        't': 'group_screenshot_request',
      });
      await ensureWebSocketConnected();
      for (final memberHash in peers) {
        WebSocketClient().sendWSMessage({
          'type': 'SEND_MESSAGE',
          'recipient_id': memberHash,
          'envelope': envelope,
          'content_type': 'group_screenshot_request',
        });
      }
    } else {
      final metaKeyHex = await ChatMetaStore.keyFor(contact.keyHash);
      if (metaKeyHex == null) return; // contact predates the metadata channel
      _startScreenshotSession(
        requestId: requestId,
        contactId: contact.id,
        isGroup: false,
        needed: 1,
        totalPeers: 1,
      );
      await ensureWebSocketConnected();
      final enc = WiltkeyPersistence().encryptString(
        jsonEncode({'req_id': requestId, 'v': 1}),
        metaKeyHex,
      );
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': contact.keyHash,
        'envelope': jsonEncode({'d': enc}),
        'content_type': 'screenshot_request',
      });
    }
  }

  void _startScreenshotSession({
    required String requestId,
    required String contactId,
    required bool isGroup,
    required int needed,
    required int totalPeers,
  }) {
    final session = ScreenshotSession(
      requestId: requestId,
      contactId: contactId,
      isGroup: isGroup,
      needed: needed,
      totalPeers: totalPeers,
    );
    session.timeout = Timer(const Duration(seconds: 45), () {
      if (screenshotSessions.remove(requestId) != null) {
        screenshotDeniedSignal.value = contactId; // timed out → treat as denied
      }
    });
    screenshotSessions[requestId] = session;
  }

  /// Respond to a peer's screenshot request (from the shell's consent dialog).
  Future<void> respondToScreenshot(
    ScreenshotRequestEvent req,
    bool accept,
  ) async {
    final idx = contacts.indexWhere((c) => c.id == req.contactId);
    if (idx == -1) return;
    final contact = contacts[idx];
    await ensureWebSocketConnected();

    if (req.isGroup) {
      final seed = contact.groupSeed ?? '';
      if (seed.isEmpty) return;
      final keyHex = sha256.convert(utf8.encode(seed)).toString();
      final enc = WiltkeyPersistence().encryptString(
        jsonEncode({'req_id': req.requestId, 'accept': accept, 'v': 1}),
        keyHex,
      );
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': req.requesterId,
        'envelope': jsonEncode({
          'group_id': contact.keyHash,
          'sender_id': userId,
          'd': enc,
          't': 'group_screenshot_response',
        }),
        'content_type': 'group_screenshot_response',
      });
    } else {
      final metaKeyHex = await ChatMetaStore.keyFor(contact.keyHash);
      if (metaKeyHex == null) return;
      final enc = WiltkeyPersistence().encryptString(
        jsonEncode({'req_id': req.requestId, 'accept': accept, 'v': 1}),
        metaKeyHex,
      );
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': contact.keyHash,
        'envelope': jsonEncode({'d': enc}),
        'content_type': 'screenshot_response',
      });
    }

    // Reflect the choice on the in-history card (whichever way it was answered).
    await _resolveScreenshotCard(
      req.contactId,
      req.requestId,
      accept ? 'accepted' : 'declined',
    );
  }

  // --- Inbound: 1-on-1 ---

  Future<void> _handleScreenshotRequest(
    String senderId,
    String envelopeStr,
  ) async {
    final idx = contacts.indexWhere((c) => c.keyHash == senderId);
    if (idx == -1) return;
    final contact = contacts[idx];
    if (contact.isGroup) return;
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;
    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      final reqId = p['req_id'] as String?;
      if (reqId == null) return;
      final ev = ScreenshotRequestEvent(
        contactId: contact.id,
        requesterId: senderId,
        requesterName: contact.name,
        requestId: reqId,
        isGroup: false,
      );
      incomingScreenshotRequest.value = ev; // fast path: modal consent dialog
      await _insertScreenshotRequestCard(contact, ev); // persistent record
    } catch (e) {
      log('[Screenshot Error] request: $e');
    }
  }

  Future<void> _handleScreenshotResponse(
    String senderId,
    String envelopeStr,
  ) async {
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;
    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      _tallyScreenshotResponse(
        senderId,
        p['req_id'] as String?,
        p['accept'] == true,
      );
    } catch (e) {
      log('[Screenshot Error] response: $e');
    }
  }

  // --- Inbound: group ---

  Future<void> _handleGroupScreenshotRequest(
    Contact group,
    String senderId,
    Map<String, dynamic> envelopeJson,
  ) async {
    try {
      final seed = group.groupSeed ?? '';
      if (seed.isEmpty) return;
      final keyHex = sha256.convert(utf8.encode(seed)).toString();
      final dec = WiltkeyPersistence().decryptString(
        envelopeJson['d'] as String,
        keyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      final reqId = p['req_id'] as String?;
      if (reqId == null) return;
      final name =
          groupProfilesCache[group.keyHash]?[senderId]?['name'] ?? group.name;
      final ev = ScreenshotRequestEvent(
        contactId: group.id,
        requesterId: senderId,
        requesterName: name,
        requestId: reqId,
        isGroup: true,
      );
      incomingScreenshotRequest.value = ev;
      await _insertScreenshotRequestCard(group, ev);
    } catch (e) {
      log('[Screenshot Error] group request: $e');
    }
  }

  Future<void> _handleGroupScreenshotResponse(
    Contact group,
    String senderId,
    Map<String, dynamic> envelopeJson,
  ) async {
    try {
      final seed = group.groupSeed ?? '';
      if (seed.isEmpty) return;
      final keyHex = sha256.convert(utf8.encode(seed)).toString();
      final dec = WiltkeyPersistence().decryptString(
        envelopeJson['d'] as String,
        keyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      _tallyScreenshotResponse(
        senderId,
        p['req_id'] as String?,
        p['accept'] == true,
      );
    } catch (e) {
      log('[Screenshot Error] group response: $e');
    }
  }

  /// Fold one peer's answer into the outstanding session. On reaching [needed]
  /// approvals → fire the capture signal; if everyone has answered and it fell
  /// short → fire the denied signal. Idempotent per responder.
  void _tallyScreenshotResponse(String responderId, String? reqId, bool accept) {
    if (reqId == null) return;
    final session = screenshotSessions[reqId];
    if (session == null) return; // not ours / already resolved
    if (session.responded.contains(responderId)) return;
    session.responded.add(responderId);
    if (accept) session.accepted.add(responderId);

    if (session.accepted.length >= session.needed) {
      session.timeout?.cancel();
      screenshotSessions.remove(reqId);
      screenshotCaptureSignal.value = session.contactId;
    } else if (session.responded.length >= session.totalPeers) {
      // Everyone answered, not enough yeses → denied.
      session.timeout?.cancel();
      screenshotSessions.remove(reqId);
      screenshotDeniedSignal.value = session.contactId;
    }
  }

  // --- In-history request card (persistent record + expiry via the wilt engine) ---

  String _ssCardId(String requestId) => 'ssreq_$requestId';

  /// Persist an incoming screenshot request as a chat card the user can answer
  /// even if they missed the modal dialog (offline / backgrounded). It's attributed
  /// to the requester, expires after [kScreenshotRequestTtlSeconds] via the wilt
  /// engine (→ "request expired"), and nudges a content-free notification when the
  /// chat isn't already on screen.
  Future<void> _insertScreenshotRequestCard(
    Contact contact,
    ScreenshotRequestEvent ev,
  ) async {
    final msgId = _ssCardId(ev.requestId);
    // A redelivered request frame shouldn't spawn a second card.
    if (await WiltkeyDatabase.instance.messageExists(contact.id, id: msgId)) {
      return;
    }
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final expiresMs = nowMs + kScreenshotRequestTtlSeconds * 1000;
    final payload = jsonEncode({
      'req_id': ev.requestId,
      'requester_id': ev.requesterId,
      'requester_name': ev.requesterName,
      'is_group': ev.isGroup,
      'status': 'pending',
    });
    final msg = ChatMessage(
      id: msgId,
      senderId: ev.requesterId, // incoming, attributed to the requester
      text: payload, // control payload, stored plaintext (no OTP)
      contentType: 'screenshot_request',
      timestamp: now,
      isSentByMe: false,
      ephemeral: true, // expiry only — never emits a wilt confirmation
      ttlSeconds: kScreenshotRequestTtlSeconds,
      openedAt: nowMs, // armed on arrival (no reveal step)
      expiresAt: expiresMs,
    );
    await WiltkeyDatabase.instance.saveMessage(msg, contact.id);
    appendLoadedMessage(contact.id, msg);
    _armWiltTimer(contact.id, msgId, expiresMs);
    bumpUnread(contact, msg);
    notifyListeners();
    if (visibleChatId != contact.id) {
      WiltkeyNotifications.showMessageNotification(chatKey: contact.keyHash);
    }
  }

  /// Answer a request straight from its in-history card (Accept/Decline buttons).
  Future<void> respondToScreenshotCard(
    Contact contact,
    ChatMessage card,
    bool accept,
  ) async {
    final ev = _eventFromCard(contact, card);
    if (ev == null) return;
    if (incomingScreenshotRequest.value?.requestId == ev.requestId) {
      incomingScreenshotRequest.value = null; // dismiss the modal if it's up
    }
    await respondToScreenshot(ev, accept); // sends + resolves the card
  }

  ScreenshotRequestEvent? _eventFromCard(Contact contact, ChatMessage card) {
    try {
      final p = jsonDecode(card.text) as Map<String, dynamic>;
      return ScreenshotRequestEvent(
        contactId: contact.id,
        requesterId: p['requester_id'] as String,
        requesterName: p['requester_name'] as String? ?? contact.name,
        requestId: p['req_id'] as String,
        isGroup: p['is_group'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Flip a stored request card to 'accepted'/'declined': rewrite its payload,
  /// drop its expiry timer, and replace the in-memory copy with a non-ephemeral
  /// one so a later sweep can't turn the answered card into "expired".
  Future<void> _resolveScreenshotCard(
    String contactId,
    String requestId,
    String status,
  ) async {
    final msgId = _ssCardId(requestId);
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
          contentType: 'screenshot_request',
          timestamp: old.timestamp,
          isSentByMe: old.isSentByMe,
          ephemeral: false, // resolved — no longer expiring
        );
      }
    }
    notifyListeners();
  }
}
