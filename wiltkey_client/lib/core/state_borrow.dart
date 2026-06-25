part of 'state.dart';

/// Byte borrowing (disjoint multi-range keystream).
///
/// When a 1-on-1 sender runs out of keystream in its own lane, it asks the peer
/// to donate the TOP HALF of the peer's still-UNUSED sending lane. Those bytes
/// are pristine (never XOR'd by anyone), so the requester uses them as a
/// disjoint extra send range with zero key reuse. This replaces the old
/// boundary-move "resplit", which could not help once both sides had sent (the
/// peer's unused bytes are its tail, not contiguous with the requester's lane).
///
/// A 1-on-1 contact's donated ranges live in `additionalSlots` as flattened
/// [start, ptr, end] triples (groups use that field for slot indices), so the
/// existing DB column persists them — no schema migration needed. The send-range
/// accounting helpers below are shared by [AppStateChats.sendMessage].
extension AppStateBorrow on AppState {
  /// Total send capacity = primary lane remainder + every borrowed range's
  /// remainder. (For groups this is just the primary remainder.)
  int _sendCapacity(Contact contact) {
    int cap = max(0, contact.outgoingMaxOffset - contact.outgoingOffset);
    if (!contact.isGroup) {
      final a = contact.additionalSlots;
      for (int i = 0; i + 2 < a.length; i += 3) {
        cap += max(0, a[i + 2] - a[i + 1]);
      }
    }
    return cap;
  }

  /// Absolute keystream offset to encrypt the next [payloadBytes] at: the
  /// primary lane if it has room, else the first borrowed range that fits,
  /// else null (caller should request a borrow).
  int? _pickSendOffset(Contact contact, int payloadBytes) {
    if (contact.outgoingOffset + payloadBytes <= contact.outgoingMaxOffset) {
      return contact.outgoingOffset;
    }
    if (!contact.isGroup) {
      final a = contact.additionalSlots;
      for (int i = 0; i + 2 < a.length; i += 3) {
        if (a[i + 1] + payloadBytes <= a[i + 2]) return a[i + 1];
      }
    }
    return null;
  }

  /// Advance whichever pointer produced [usedOffset] by [payloadBytes].
  void _advanceSendPointer(Contact contact, int usedOffset, int payloadBytes) {
    if (usedOffset == contact.outgoingOffset) {
      contact.outgoingOffset += payloadBytes;
      return;
    }
    final a = contact.additionalSlots;
    for (int i = 0; i + 2 < a.length; i += 3) {
      if (a[i + 1] == usedOffset) {
        a[i + 1] = usedOffset + payloadBytes;
        return;
      }
    }
  }

  /// Reverse of [_advanceSendPointer] — roll a reserved offset back when a send
  /// is abandoned before it consumed the keystream (e.g. encryption threw).
  void _rollbackSendPointer(Contact contact, int usedOffset, int payloadBytes) {
    if (contact.outgoingOffset == usedOffset + payloadBytes) {
      contact.outgoingOffset = usedOffset;
      return;
    }
    final a = contact.additionalSlots;
    for (int i = 0; i + 2 < a.length; i += 3) {
      if (a[i + 1] == usedOffset + payloadBytes) {
        a[i + 1] = usedOffset;
        return;
      }
    }
  }

  /// Ask the peer to lend us some of its unused keystream.
  void requestBorrow(Contact contact) {
    if (contact.isGroup) return;
    log('[Borrow] Requesting donated keystream from ${contact.name}');
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': contact.keyHash,
      'envelope': jsonEncode({'borrow': true}),
      'content_type': 'borrow_request',
    });
  }

  /// Peer asked to borrow: donate the top half of our own UNUSED primary lane
  /// (a pristine tail), lower our ceiling so we never write there, and reply
  /// with the exact donated range.
  Future<void> handleBorrowRequest(String senderId, String envelopeStr) async {
    final idx = contacts.indexWhere((c) => c.keyHash == senderId);
    if (idx == -1) return;
    final contact = contacts[idx];
    if (contact.isGroup) return;

    final int unused = max(
      0,
      contact.outgoingMaxOffset - contact.outgoingOffset,
    );
    final int grant = unused ~/ 2;
    if (grant < 74) {
      log('[Borrow] Nothing meaningful to donate (unused=$unused)');
      return;
    }
    final int oldMax = contact.outgoingMaxOffset;
    final int newMax = oldMax - grant; // we keep [outgoingOffset, newMax)
    contact.outgoingMaxOffset = newMax;
    contact.remainingBufferBytes = _sendCapacity(contact);
    contact.isWilted = contact.remainingBufferBytes < 74;
    await WiltkeyDatabase.instance.upsertContact(contact);
    notifyListeners();
    _persistence.saveState(this);

    log('[Borrow] Donating [$newMax,$oldMax) (${grant}B) to ${contact.name}');
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': contact.keyHash,
      'envelope': jsonEncode({'start': newMax, 'end': oldMax}),
      'content_type': 'borrow_grant',
    });

    // Telegraph the donation so the lender understands why their remaining space
    // just dropped (the borrow is automatic and would otherwise be invisible).
    await addSystemMessage(
      contact,
      'Lent ${AppState.formatBytes(grant)} of keystream to ${contact.name} so they can keep messaging — your remaining space dropped by that much.',
    );
  }

  /// Peer granted us a donated range: record it as a disjoint extra send range.
  Future<void> handleBorrowGrant(String senderId, String envelopeStr) async {
    final idx = contacts.indexWhere((c) => c.keyHash == senderId);
    if (idx == -1) return;
    final contact = contacts[idx];
    if (contact.isGroup) return;
    try {
      final env = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final int start = env['start'] as int;
      final int end = env['end'] as int;
      if (end <= start) return;
      contact.additionalSlots.addAll([
        start,
        start,
        end,
      ]); // [start, ptr=start, end]
      contact.remainingBufferBytes = _sendCapacity(contact);
      contact.isWilted = contact.remainingBufferBytes < 74;
      await WiltkeyDatabase.instance.upsertContact(contact);
      notifyListeners();
      _persistence.saveState(this);
      log(
        '[Borrow] Received donated range [$start,$end) from ${contact.name}; capacity now ${contact.remainingBufferBytes}',
      );

      // Telegraph the top-up so the borrower understands the sudden extra space.
      await addSystemMessage(
        contact,
        '${contact.name} lent you ${AppState.formatBytes(end - start)} of keystream so you can keep messaging.',
      );
    } catch (e) {
      log('[Borrow Error] $e');
    }
  }
}
