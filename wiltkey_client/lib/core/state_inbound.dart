part of 'state.dart';

/// Inbound WS frame handling: the serialized live/replayed delivery queue,
/// the per-content-type routing in [_dispatchIncoming], group payload
/// decoding, delivery receipts, and chat/group resync (request + response).
extension AppStateInbound on AppState {
  /// Replay frames the Instant-mode background socket buffered while we were
  /// locked. Each was stored raw (undecryptable without the master key); now
  /// that we're unlocked we run them through the exact same inbound path as live
  /// frames — decrypt via OTP at the envelope offset, re-encrypt under the
  /// master key, store, dedupe by id, and fire any receipts. The OTP keystream
  /// isn't consumed until this read, so deferring decryption is lossless. We
  /// only [PendingInbox.clear] after processing completes, so a crash mid-replay
  /// can't drop messages.
  Future<void> processPendingInbox() async {
    // Both the unlock path and the foreground-resume path call this; the guard
    // stops them from draining the same buffer twice (which would re-dispatch
    // frames — e.g. answer a delivery_check or apply a response more than once).
    if (isDrainingPendingInbox) return;
    isDrainingPendingInbox = true;
    try {
      final frames = await PendingInbox.drainAll();
      if (frames.isEmpty) return;
      log(
        '[Notifications] Replaying ${frames.length} buffered inbound frame(s).',
      );
      for (final f in frames) {
        _deliverMessageToState(
          f['sender_id'] as String? ?? '',
          f['envelope'] as String? ?? '',
          f['content_type'] as String? ?? 'text',
        );
      }
      // Wait for the serialized inbound queue to fully drain before clearing.
      await _incomingLock;
      await PendingInbox.clear();
    } finally {
      isDrainingPendingInbox = false;
    }
  }

  /// Entry point for all inbound WS frames. Chains each delivery onto a single
  /// lock so the read-check-append inside [_dispatchIncoming] runs to completion
  /// before the next frame is processed — preventing duplicate appends when the
  /// offline queue and resync responses arrive at the same time.
  void _deliverMessageToState(
    String senderId,
    String envelope,
    String contentType,
  ) {
    final prev = _incomingLock;
    final completer = Completer<void>();
    _incomingLock = completer.future;
    prev.whenComplete(() async {
      try {
        await _dispatchIncoming(senderId, envelope, contentType);
      } catch (e) {
        log('[WebSocket Error] incoming dispatch failed: $e');
      } finally {
        completer.complete();
      }
    });
  }

  /// Extracts the issuance timestamp (epoch ms) from a `nuke` envelope, or null
  /// for the legacy literal `VAPORIZE` envelope (and any unparseable payload) —
  /// those are treated as "no timestamp", so the stale-nuke guard lets them
  /// through and the chat is wiped exactly as before.
  int? _parseNukeTimestamp(String envelope) {
    try {
      final decoded = jsonDecode(envelope);
      if (decoded is Map && decoded['ts'] is num) {
        return (decoded['ts'] as num).toInt();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _dispatchIncoming(
    String senderId,
    String envelope,
    String contentType,
  ) async {
    if (contentType == 'nuke') {
      // Stale-nuke guard: a `nuke` queued for us sits on the relay for up to 7
      // days. If the peer nuked a chat we no longer had (or never had) and we
      // then re-paired under the same keyHash, this ghost frame would land and
      // wipe the freshly-made contact on our side only. The envelope carries the
      // nuke's issuance time; if our current pairing for this peer is newer, the
      // nuke is from a prior session — ACK it to clear the relay queue, but keep
      // the contact. (Envelopes without a timestamp — old clients — wipe as before.)
      final int? nukeTs = _parseNukeTimestamp(envelope);
      if (nukeTs != null) {
        final int? pairedAt = await _persistence.getPairingTime(senderId);
        if (pairedAt != null && pairedAt > nukeTs) {
          log(
            '[WebSocket] Ignoring STALE nuke from $senderId — re-paired '
            '${pairedAt - nukeTs}ms after it was issued. ACKing to clear queue.',
          );
          WebSocketClient().sendWSMessage({'type': 'ACK_NUKE'});
          return;
        }
      }
      log(
        '[WebSocket] Received NUKE command from $senderId! Wiping keys and data for that contact...',
      );
      await nukeContact(senderId, receivedFromPeer: true);
      return;
    }

    if (contentType == 'group_nuke') {
      log(
        '[WebSocket] Received GROUP_NUKE command! Wiping keys and data for group...',
      );
      try {
        final envelopeJson = jsonDecode(envelope) as Map<String, dynamic>;
        final String? groupId = envelopeJson['group_id'] as String?;
        final String? originSender = envelopeJson['sender_id'] as String?;
        if (groupId != null) {
          // If we're the host, relay to every other member so spokes that only
          // know the host are reached too. Capture the roster BEFORE nuking.
          final idx = contacts.indexWhere(
            (c) => c.isGroup && c.keyHash == groupId,
          );
          if (idx != -1 && contacts[idx].isHost) {
            final g = contacts[idx];
            _fanOutGroupNuke(
              groupId,
              g.memberKeyHashes,
              g.hostKeyHash,
              exclude: {
                userId,
                senderId,
                if (originSender != null) originSender,
              },
            );
          }
          await nukeContact(groupId, receivedFromPeer: true);
        }
      } catch (e) {
        log('Error processing group nuke: $e');
      }
      return;
    }

    if (contentType == 'borrow_request') {
      await handleBorrowRequest(senderId, envelope);
      return;
    }

    if (contentType == 'borrow_grant') {
      await handleBorrowGrant(senderId, envelope);
      return;
    }

    if (contentType == 'chat_info_update') {
      await _handleChatInfoUpdate(senderId, envelope);
      return;
    }

    if (contentType == 'archive_signal') {
      await _handleArchiveSignal(senderId, envelope);
      return;
    }

    if (contentType == 'group_metadata_request') {
      log('[WebSocket] Received group_metadata_request from: $senderId');
      try {
        final envelopeJson = jsonDecode(envelope) as Map<String, dynamic>;
        final String? groupId = envelopeJson['group_id'] as String?;
        if (groupId != null) {
          // Any member can answer (host-first with member fallback). We respond
          // if we are the host, or the requester is someone we already know.
          final groupIndex = contacts.indexWhere(
            (c) => c.isGroup && c.keyHash == groupId,
          );
          if (groupIndex != -1) {
            final group = contacts[groupIndex];
            final knownProfile = await GroupDatabase.instance.getProfile(
              groupId,
              senderId,
            );
            final bool isKnownMember =
                group.isHost ||
                group.memberKeyHashes.contains(senderId) ||
                knownProfile != null;
            if (isKnownMember) {
              await sendGroupMetadataUpdateToSpoke(group, senderId);
            } else {
              log(
                '[Group Warning] $senderId requested metadata but is unknown in group $groupId',
              );
            }
          }
        }
      } catch (e) {
        log('[Group Error] Failed to process group metadata request: $e');
      }
      return;
    }

    if (contentType == 'delivery_receipt') {
      await _handleDeliveryReceipt(senderId, envelope);
      return;
    }

    if (contentType == 'chat_resync_request') {
      await _handleChatResyncRequest(senderId, envelope);
      return;
    }

    if (contentType == 'chat_resync_response') {
      await _handleChatResyncResponse(senderId, envelope);
      return;
    }

    if (contentType == 'delivery_check') {
      await _handleDeliveryCheck(senderId, envelope);
      return;
    }

    if (contentType == 'delivery_check_response') {
      await _handleDeliveryCheckResponse(senderId, envelope);
      return;
    }

    Map<String, dynamic>? envelopeJson;
    try {
      envelopeJson = jsonDecode(envelope) as Map<String, dynamic>;
    } catch (_) {}

    final String? groupId = envelopeJson?['group_id'] as String?;

    if (groupId != null) {
      final contactIndex = contacts.indexWhere(
        (c) => c.isGroup && c.keyHash == groupId,
      );
      if (contactIndex == -1) {
        log(
          '[WebSocket Error] Received group message for unknown group: $groupId',
        );
        return;
      }
      final contact = contacts[contactIndex];

      if (contentType == 'group_member_profile') {
        log('[WebSocket] Received group_member_profile from: $senderId');
        try {
          final seed = contact.groupSeed ?? '';
          if (seed.isEmpty) return;
          final keyHex = sha256.convert(utf8.encode(seed)).toString();
          final dec = WiltkeyPersistence().decryptString(
            envelopeJson!['d'] as String,
            keyHex,
          );
          final p = jsonDecode(dec) as Map<String, dynamic>;
          await upsertGroupProfileMerged(
            groupId: groupId,
            memberKeyHash: senderId,
            name: (p['name'] as String?)?.trim(),
            profileImage: (p['profile_image'] as String?)?.trim(),
          );
          // Refresh the in-memory cache the chat UI reads from (+ notify).
          updateGroupMembersMetadata(contact);
        } catch (e) {
          log('[Group Error] Failed to apply group_member_profile: $e');
        }
        return;
      }

      if (contentType == 'group_info_update') {
        log('[WebSocket] Received group_info_update from Host: $senderId');
        try {
          final rawContent = envelopeJson!['d'] as String;

          final groupSeed = contact.groupSeed ?? '';
          if (groupSeed.isEmpty) {
            throw Exception('Group seed is empty');
          }
          final keyHex = sha256.convert(utf8.encode(groupSeed)).toString();
          final decryptedStr = WiltkeyPersistence().decryptString(
            rawContent,
            keyHex,
          );
          final decryptedJson =
              jsonDecode(decryptedStr) as Map<String, dynamic>;

          final String resolvedHostKeyHash =
              (decryptedJson['host_key_hash'] as String?) ??
              contact.hostKeyHash ??
              senderId;

          await GroupDatabase.instance.upsertGroupInfo(
            groupId: groupId,
            groupName: decryptedJson['group_name'] as String,
            groupIcon: decryptedJson['group_icon'] as String,
            laneSize: decryptedJson['lane_size'] as int,
            maxMembers: decryptedJson['max_members'] as int,
            totalSize: decryptedJson['total_size'] as int,
            groupSeedEncrypted: contact.groupSeed ?? '',
            isHost: false,
            hostKeyHash: resolvedHostKeyHash,
          );

          final assignments =
              decryptedJson['lane_assignments'] as List<dynamic>;
          final infoLaneSize = AppState.infoLaneSize;
          final laneSize = decryptedJson['lane_size'] as int;
          for (final item in assignments) {
            final slotIndex = item['slot_index'] as int;
            final memberKeyHash = item['member_key_hash'] as String?;

            final startOffset = infoLaneSize + (slotIndex - 1) * laneSize;
            final maxOffset = infoLaneSize + slotIndex * laneSize;

            final existing = await GroupDatabase.instance.getLane(
              groupId,
              slotIndex,
            );
            final currentOffset =
                existing?['current_write_offset'] as int? ?? 0;
            final headerWritten = existing?['header_written'] as int? ?? 0;

            await GroupDatabase.instance.upsertLane(
              groupId: groupId,
              slotIndex: slotIndex,
              memberKeyHash: memberKeyHash,
              startOffset: startOffset,
              maxOffset: maxOffset,
              currentWriteOffset: currentOffset,
              headerWritten: headerWritten == 1,
            );
          }

          final profilesList =
              decryptedJson['members_profiles'] as List<dynamic>?;
          if (profilesList != null) {
            for (final item in profilesList) {
              final m = item as Map<String, dynamic>;
              final keyHash = m['key_hash'] as String?;
              if (keyHash != null) {
                await upsertGroupProfileMerged(
                  groupId: groupId,
                  memberKeyHash: keyHash,
                  name: m['name'] as String?,
                  profileImage: m['profile_image'] as String?,
                  arrivalOrder: m['arrival_order'] as int?,
                );
              }
            }
          }

          final List<String> memberHashes = [];
          void addHash(String? hash) {
            if (hash != null &&
                hash.isNotEmpty &&
                !memberHashes.contains(hash)) {
              memberHashes.add(hash);
            }
          }

          for (final item in assignments) {
            addHash(item['member_key_hash'] as String?);
          }
          // Members may be known only via a profile (e.g. learned from a peer's
          // lane header) without an explicit lane assignment yet.
          if (profilesList != null) {
            for (final item in profilesList) {
              addHash((item as Map<String, dynamic>)['key_hash'] as String?);
            }
          }
          addHash(resolvedHostKeyHash);
          addHash(userId);

          String resolvedHostName = contact.hostName ?? 'Host';
          if (profilesList != null) {
            for (final item in profilesList) {
              final m = item as Map<String, dynamic>;
              if (m['key_hash'] == resolvedHostKeyHash) {
                resolvedHostName = m['name'] as String? ?? resolvedHostName;
                break;
              }
            }
          }

          final updatedContact = Contact(
            id: contact.id,
            name: decryptedJson['group_name'] as String? ?? contact.name,
            keyHash: contact.keyHash,
            relayUrl: contact.relayUrl,
            isPrivateNode: contact.isPrivateNode,
            maxBufferBytes: contact.maxBufferBytes,
            remainingBufferBytes: contact.remainingBufferBytes,
            peerRemainingBufferBytes: contact.peerRemainingBufferBytes,
            lastActivity: contact.lastActivity,
            isWilted: contact.isWilted,
            isGroup: true,
            memberCount: memberHashes.length,
            hostName: resolvedHostName,
            isHost: contact.isHost,
            hostKeyHash: resolvedHostKeyHash,
            memberKeyHashes: memberHashes,
            groupIconHex:
                decryptedJson['group_icon'] as String? ?? contact.groupIconHex,
            maxMembers:
                decryptedJson['max_members'] as int? ?? contact.maxMembers,
            maxMessageSize:
                decryptedJson['max_message_size'] as int? ??
                contact.maxMessageSize,
            imagesAllowed:
                decryptedJson['images_allowed'] as bool? ??
                contact.imagesAllowed,
            joinedAt: contact.joinedAt,
            shortNick: contact.shortNick,
            profileImageB64:
                decryptedJson['group_icon'] as String? ??
                contact.profileImageB64,
            outgoingOffset: contact.outgoingOffset,
            outgoingMaxOffset: contact.outgoingMaxOffset,
            incomingOffset: contact.incomingOffset,
            incomingMaxOffset: contact.incomingMaxOffset,
            groupSeed: contact.groupSeed,
            laneSize: contact.laneSize,
            totalGroupSize: contact.totalGroupSize,
            slotIndex: contact.slotIndex,
            additionalSlots: contact.additionalSlots,
          );

          final idx = contacts.indexWhere((c) => c.keyHash == contact.keyHash);
          if (idx != -1) {
            contacts[idx] = updatedContact;
          }
          if (activeContact?.keyHash == contact.keyHash) {
            activeContact = updatedContact;
          }
          await WiltkeyDatabase.instance.upsertContact(updatedContact);

          // Metadata arrived — stop pinging fallback candidates.
          onGroupMetadataReceived(groupId);
          updateGroupMembersMetadata(updatedContact);

          log(
            '[Group Spoke] Updated group "${updatedContact.name}" metadata successfully. Member count: ${memberHashes.length}',
          );
          _persistence.saveState(this);
        } catch (e) {
          log(
            '[Group Spoke Error] Failed to process group metadata update: $e',
          );
        }
        return;
      }

      if (contentType == 'group_lane_refill_request') {
        log(
          '[WebSocket] Received group_lane_refill_request from Spoke: $senderId',
        );
        try {
          final profile = await GroupDatabase.instance.getProfile(
            groupId,
            senderId,
          );
          final senderName =
              profile?['name'] ?? 'Member ${senderId.substring(0, 6)}';

          final newMessage = ChatMessage(
            id: DateTime.now().toString(),
            senderId: senderId,
            text: '$senderName is requesting a lane refill.',
            contentType: 'refill_request',
            timestamp: DateTime.now(),
            isSentByMe: false,
            decryptedText: '$senderName is requesting a lane refill.',
          );

          appendLoadedMessage(contact.id, newMessage);
          notifyMessageReceived();
        } catch (e) {
          log('[Group Host Error] Failed to handle refill request: $e');
        }
        return;
      }

      if (contentType == 'group_lane_refill_granted') {
        log(
          '[WebSocket] Received group_lane_refill_granted from Host: $senderId',
        );
        try {
          final int? slotIndex = envelopeJson?['slot_index'] as int?;
          if (slotIndex != null) {
            final infoLaneSize = AppState.infoLaneSize;
            final laneSize = contact.laneSize ?? 0;
            if (laneSize > 0) {
              await GroupDatabase.instance.upsertLane(
                groupId: groupId,
                slotIndex: slotIndex,
                startOffset: infoLaneSize + (slotIndex - 1) * laneSize,
                maxOffset: infoLaneSize + slotIndex * laneSize,
                currentWriteOffset: 0,
                memberKeyHash: userId,
                headerWritten: false,
              );
            }

            await sendLaneHeader(groupId, slotIndex);

            final systemMsg = ChatMessage(
              id: DateTime.now().toString(),
              senderId: 'system',
              text: 'Lane refill granted by Host. Lane slot $slotIndex active.',
              timestamp: DateTime.now(),
              isSentByMe: false,
              decryptedText:
                  'Lane refill granted by Host. Lane slot $slotIndex active.',
            );
            appendLoadedMessage(contact.id, systemMsg);
            notifyMessageReceived();
          }
        } catch (e) {
          log('[Group Spoke Error] Failed to handle refill granted: $e');
        }
        return;
      }

      await _handleGroupPayload(contact, groupId, envelopeJson);
      return;
    }

    int contactIndex = contacts.indexWhere((c) => c.keyHash == senderId);
    if (contactIndex != -1) {
      final contact = contacts[contactIndex];
      String rawContent = envelope;
      String resolvedContentType = contentType;
      int offset = 0;
      String? decryptedPlaintext;
      String messageId = DateTime.now().toString();

      try {
        if (envelopeJson != null) {
          resolvedContentType = envelopeJson['t'] as String? ?? contentType;
          rawContent = envelopeJson['d'] as String? ?? envelope;
          offset = envelopeJson['offset'] as int? ?? 0;
          messageId = envelopeJson['id'] as String? ?? messageId;
        }

        final cipherBytes = base64Decode(rawContent);
        final plainBytes = await WiltkeyOtpService.xorWithKeystream(
          contact.keyHash,
          cipherBytes,
          offset,
        );
        decryptedPlaintext = utf8.decode(plainBytes);
      } catch (e) {
        log(
          '[WebSocket Error] Failed to parse or decrypt incoming message: $e',
        );
        rawContent = envelope;
      }

      final int payloadBytes = decryptedPlaintext != null
          ? utf8.encode(decryptedPlaintext).length
          : utf8.encode(rawContent).length;

      // Gap detection + incoming bookkeeping apply ONLY to the peer's primary
      // lane. A message that arrives in a disjoint range the peer borrowed from
      // us lands above incomingMaxOffset; it still decrypts by absolute offset,
      // but must not drive resync or corrupt the primary incoming pointer.
      if (offset <= contact.incomingMaxOffset) {
        final expectedOffset = contact.incomingOffset;
        if (offset > expectedOffset) {
          _requestChatResync(contact, expectedOffset, offset);
        }
        contact.incomingOffset = max(
          contact.incomingOffset,
          offset + payloadBytes,
        );
        contact.peerRemainingBufferBytes = max(
          0,
          contact.peerRemainingBufferBytes - (payloadBytes + 73),
        );
      }

      final newMessage = ChatMessage(
        id: messageId,
        senderId: contact.id,
        text: rawContent,
        contentType: resolvedContentType,
        timestamp: DateTime.now(),
        isSentByMe: false,
        offset: offset,
        decryptedText: decryptedPlaintext,
        decodedImageBytes:
            (resolvedContentType == 'image' && decryptedPlaintext != null)
            ? base64Decode(decryptedPlaintext)
            : null,
      );

      appendLoadedMessage(contact.id, newMessage);
      bumpUnread(
        contact,
        newMessage,
      ); // live arrival → unread badge if not open
      await WiltkeyDatabase.instance.saveMessage(
        newMessage,
        contact.id,
        masterKeyHex: masterKeyHex,
      );
      await WiltkeyDatabase.instance.upsertContact(contact);
      notifyMessageReceived();

      // Emoji control writes paint the shared pool. We still store the message
      // (so we can serve it on resync) but it's filtered from the chat stream.
      if ((resolvedContentType == 'emoji_def' ||
              resolvedContentType == 'emoji_delete') &&
          decryptedPlaintext != null) {
        await _pinEmojiPayload(
          contact.keyHash,
          decryptedPlaintext,
          ChatMetaStore.budgetFor(contact.maxBufferBytes),
        );
        notifyListeners();
      }

      // Send delivery receipt back if decrypted successfully
      if (decryptedPlaintext != null) {
        _sendDeliveryReceipt(senderId, null, messageId, offset, null);
      }
    } else {
      log('[WebSocket] Message from unknown sender: $senderId. Ignoring.');
    }
  }

  /// Handles an inbound group lane header or chat message. Decryption keys only
  /// off the absolute keystream offset carried in the envelope, so it never
  /// depends on a pre-existing local lane row (which is what made spoke<->spoke
  /// delivery silently drop before). Everything is wrapped so one bad frame
  /// can't abort the whole receive pipeline.
  Future<void> _handleGroupPayload(
    Contact contact,
    String groupId,
    Map<String, dynamic>? envelopeJson,
  ) async {
    try {
      final innerSenderId = envelopeJson?['sender_id'] as String?;
      final slotIndex = envelopeJson?['slot_index'] as int?;
      final offset = envelopeJson?['offset'] as int?;
      final dataB64 = envelopeJson?['d'] as String?;
      final innerType = envelopeJson?['t'] as String? ?? 'text';
      final messageId =
          envelopeJson?['id'] as String? ?? DateTime.now().toString();
      final tsMillis = envelopeJson?['ts'] as int?;
      final timestamp = tsMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(tsMillis)
          : DateTime.now();

      if (innerSenderId == null ||
          slotIndex == null ||
          offset == null ||
          dataB64 == null) {
        log('[Group State] Ignoring malformed group payload (missing fields).');
        return;
      }

      final laneSize = contact.laneSize;
      if (laneSize == null || laneSize <= 0) {
        log(
          '[Group State] Lane size unknown for $groupId; requesting metadata before processing.',
        );
        if (!contact.isHost) requestGroupMetadata(contact);
        return;
      }

      // Lane geometry is derived arithmetically — no DB row required to decrypt.
      final laneStart = laneStartFor(slotIndex, laneSize);
      final laneMax = laneStart + laneSize;

      final cipherBytes = base64Decode(dataB64);
      final plainBytes = await WiltkeyOtpService.xorWithGroupKeystream(
        groupId,
        cipherBytes,
        offset,
      );

      if (innerType == 'group_lane_header') {
        try {
          final header = parseLaneHeader(Uint8List.fromList(plainBytes));
          await upsertGroupProfileMerged(
            groupId: groupId,
            memberKeyHash: innerSenderId,
            name: header['name'] as String?,
            profileImage: header['profileImage'] as String?,
            arrivalOrder: header['arrivalOrder'] as int?,
          );
          final existing = await GroupDatabase.instance.getLane(
            groupId,
            slotIndex,
          );
          await GroupDatabase.instance.upsertLane(
            groupId: groupId,
            slotIndex: slotIndex,
            memberKeyHash: innerSenderId,
            startOffset: laneStart,
            maxOffset: laneMax,
            currentWriteOffset: max(
              AppState.laneHeaderSize,
              existing?['current_write_offset'] as int? ?? 0,
            ),
            headerWritten: true,
          );
          log(
            '[Group State] Processed lane header for $innerSenderId in slot $slotIndex',
          );
          updateGroupMembersMetadata(contact);
        } catch (e) {
          log('[Group State Error] Failed to parse lane header: $e');
        }
        return;
      }

      // --- regular chat message ---
      final decryptedText = utf8.decode(plainBytes);

      // Dedupe before any mutation so retries/resyncs don't double-advance lanes.
      // Checks the DB (not just the loaded window) so windowing can't reintroduce
      // a message we already stored.
      if (await WiltkeyDatabase.instance.messageExists(
        contact.id,
        id: messageId,
      )) {
        // Still acknowledge so the sender's tick resolves even on a resend.
        if (innerSenderId != userId) {
          _sendDeliveryReceipt(
            innerSenderId,
            groupId,
            messageId,
            offset,
            slotIndex,
          );
        }
        return;
      }

      // Ensure a lane row exists for this slot (create on the fly for peers we
      // haven't fully synced yet).
      final lane = await GroupDatabase.instance.getLane(groupId, slotIndex);
      final int cursor = lane?['current_write_offset'] as int? ?? 0;
      final int incomingRelative = offset - laneStart;

      // Gap detection: we received bytes beyond where we expected this lane to be.
      if (incomingRelative > cursor) {
        _requestChatResync(
          contact,
          laneStart + cursor,
          offset,
          slotIndex: slotIndex,
        );
      }

      final int newCursor = max(cursor, incomingRelative + plainBytes.length);
      await GroupDatabase.instance.upsertLane(
        groupId: groupId,
        slotIndex: slotIndex,
        memberKeyHash: innerSenderId,
        startOffset: laneStart,
        maxOffset: laneMax,
        currentWriteOffset: newCursor,
        headerWritten: (lane?['header_written'] as int? ?? 0) == 1,
      );

      // Make sure we at least have a placeholder profile so the UI can render.
      final profile = await GroupDatabase.instance.getProfile(
        groupId,
        innerSenderId,
      );
      if (profile == null) {
        await GroupDatabase.instance.upsertProfile(
          groupId: groupId,
          memberKeyHash: innerSenderId,
          name:
              'Member ${innerSenderId.substring(0, min(6, innerSenderId.length))}',
          profileImage: '',
          arrivalOrder: slotIndex,
        );
        // We don't have this member's real profile yet — pull metadata.
        if (!contact.isHost) requestGroupMetadata(contact);
      }

      final newMessage = ChatMessage(
        id: messageId,
        senderId: innerSenderId,
        text: dataB64,
        contentType: innerType,
        timestamp: timestamp,
        isSentByMe: innerSenderId == userId,
        offset: offset,
        decryptedText: decryptedText,
        decodedImageBytes: (innerType == 'image')
            ? base64Decode(decryptedText)
            : null,
      );

      if (loadedChats.contains(contact.id)) {
        final updatedList = <ChatMessage>[
          ...(messages[contact.id] ?? []),
          newMessage,
        ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        messages[contact.id] = updatedList;
      }
      bumpUnread(
        contact,
        newMessage,
      ); // live arrival → unread badge if not open
      await WiltkeyDatabase.instance.saveMessage(
        newMessage,
        contact.id,
        masterKeyHex: masterKeyHex,
      );
      notifyMessageReceived();
      updateGroupMembersMetadata(contact);

      // Emoji control writes paint the shared pool (group budget = 1 MB info lane).
      // The message stays stored for resync but is filtered from the chat stream.
      if (innerType == 'emoji_def' || innerType == 'emoji_delete') {
        await _pinEmojiPayload(groupId, decryptedText, AppState.infoLaneSize);
        notifyListeners();
      }

      // Acknowledge delivery so the sender's check turns to double-check.
      if (innerSenderId != userId) {
        _sendDeliveryReceipt(
          innerSenderId,
          groupId,
          messageId,
          offset,
          slotIndex,
        );
      }
    } catch (e, st) {
      log('[Group State Error] Failed to handle group payload: $e');
      log('[Group State Error] $st');
    }
  }

  void _sendDeliveryReceipt(
    String recipientId,
    String? groupId,
    String messageId,
    int offset,
    int? slotIndex,
  ) {
    log(
      '[Delivery Receipt] Sending receipt to $recipientId for message $messageId (offset: $offset)',
    );
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': recipientId,
      'envelope': jsonEncode({
        'group_id': groupId,
        'message_id': messageId,
        'offset': offset,
        'slot_index': slotIndex,
      }),
      'content_type': 'delivery_receipt',
    });
  }

  Future<void> _handleDeliveryReceipt(String senderId, String envelope) async {
    try {
      final data = jsonDecode(envelope) as Map<String, dynamic>;
      final String? groupId = data['group_id'];
      final String messageId = data['message_id'];
      final int offset = data['offset'] as int;

      final chatKey = groupId ?? senderId;
      final contactIndex = contacts.indexWhere((c) => c.keyHash == chatKey);
      if (contactIndex == -1) return;
      final contact = contacts[contactIndex];

      // Persist the delivered flag straight to the DB, independent of whether the
      // chat is currently windowed in memory. A receipt very often lands while the
      // target chat isn't loaded — right after the app reopens from a closed state
      // and replays buffered/queued frames — and the old in-memory-only update
      // dropped those, leaving the message stuck on a single check forever.
      await WiltkeyDatabase.instance.updateMessageDelivered(messageId, true);
      await WiltkeyDatabase.instance.markSentDeliveredByOffset(
        contact.id,
        offset,
      );

      // Reflect it on the live bubble too, if the chat happens to be open.
      final list = messages[contact.id] ?? [];
      final msgIndex = list.indexWhere(
        (m) => m.id == messageId || (m.isSentByMe && m.offset == offset),
      );
      final bool flippedInMemory = msgIndex != -1 && !list[msgIndex].isDelivered;
      if (flippedInMemory) list[msgIndex].isDelivered = true;

      log(
        '[Delivery Receipt] Marked message $messageId (offset $offset) delivered for ${contact.name}',
      );
      notifyListeners();
    } catch (e) {
      log('[Delivery Receipt Error] Failed to handle receipt: $e');
    }
  }

  /// 1-on-1 delivery reconciliation, peer side: the sender listed their
  /// outbound messages ({id, offset}) and wants to know which we actually hold.
  /// For each, we either confirm it (their single-check → double-check) or flag
  /// it missing so they resend it. Fixes deliveries whose one-shot receipt was
  /// lost (e.g. our app was closed past the receipt's queue TTL).
  Future<void> _handleDeliveryCheck(String senderId, String envelope) async {
    try {
      final data = jsonDecode(envelope) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? []);
      final contactIndex = contacts.indexWhere(
        (c) => c.keyHash == senderId && !c.isGroup,
      );
      if (contactIndex == -1) return;
      final contact = contacts[contactIndex];

      final confirmed = <int>[];
      final missing = <int>[];
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        final String id = item['id'] as String? ?? '';
        final int offset = item['offset'] as int? ?? -1;
        if (offset < 0) continue;
        final has = await WiltkeyDatabase.instance.messageExists(
          contact.id,
          id: id,
          offset: offset,
        );
        (has ? confirmed : missing).add(offset);
      }

      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': senderId,
        'envelope': jsonEncode({'confirmed': confirmed, 'missing': missing}),
        'content_type': 'delivery_check_response',
      });
      log(
        '[Delivery Sync] Answered delivery_check from $senderId: '
        '${confirmed.length} held, ${missing.length} missing',
      );
    } catch (e) {
      log('[Delivery Sync Error] handle delivery_check failed: $e');
    }
  }

  /// 1-on-1 delivery reconciliation, sender side: the peer answered our check.
  /// Mark every confirmed offset delivered, and resend the ones they're missing
  /// the normal way (which yields a fresh delivery receipt once they ingest it).
  Future<void> _handleDeliveryCheckResponse(
    String senderId,
    String envelope,
  ) async {
    try {
      final data = jsonDecode(envelope) as Map<String, dynamic>;
      final confirmed = (data['confirmed'] as List<dynamic>? ?? [])
          .map((e) => e as int)
          .toList();
      final missing = (data['missing'] as List<dynamic>? ?? [])
          .map((e) => e as int)
          .toList();
      final contactIndex = contacts.indexWhere(
        (c) => c.keyHash == senderId && !c.isGroup,
      );
      if (contactIndex == -1) return;
      final contact = contacts[contactIndex];

      if (confirmed.isNotEmpty) {
        final list = messages[contact.id] ?? [];
        for (final off in confirmed) {
          await WiltkeyDatabase.instance.markSentDeliveredByOffset(
            contact.id,
            off,
          );
          // Reflect it on any in-memory bubble immediately.
          for (final m in list) {
            if (m.isSentByMe && m.offset == off) m.isDelivered = true;
          }
        }
        notifyMessageReceived();
        _persistence.saveState(this);
      }

      if (missing.isNotEmpty && WebSocketClient().isConnected) {
        for (final off in missing) {
          final rows = await WiltkeyDatabase.instance.getMessagesInOffsetRange(
            contact.id,
            off,
            off + 1,
          );
          for (final msg in rows) {
            if (!msg.isSentByMe) continue;
            WebSocketClient().sendWSMessage({
              'type': 'SEND_MESSAGE',
              'recipient_id': contact.keyHash,
              'envelope': jsonEncode({
                't': msg.contentType,
                'd': msg.text,
                'offset': msg.offset,
                'id': msg.id,
              }),
              'content_type': msg.contentType,
            });
          }
        }
        log(
          '[Delivery Sync] Resent ${missing.length} message(s) the peer was missing',
        );
      }
    } catch (e) {
      log('[Delivery Sync Error] handle delivery_check_response failed: $e');
    }
  }

  Future<List<String>> _getSyncCandidates(Contact contact) async {
    final candidates = <String>[];
    if (contact.hostKeyHash != null && contact.hostKeyHash != userId) {
      candidates.add(contact.hostKeyHash!);
    }
    final profiles = await GroupDatabase.instance.getAllProfiles(
      contact.keyHash,
    );
    for (final p in profiles) {
      final keyHash = p['member_key_hash'] as String;
      if (keyHash != userId && !candidates.contains(keyHash)) {
        candidates.add(keyHash);
      }
    }
    return candidates;
  }

  void _sendResyncRequestFrame(
    String recipientId,
    String? groupId,
    int startOffset,
    int endOffset,
    int? slotIndex,
  ) {
    log(
      '[Resync] Sending resync request to $recipientId for range $startOffset-$endOffset (slot: $slotIndex)',
    );
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': recipientId,
      'envelope': jsonEncode({
        'group_id': groupId,
        'start_offset': startOffset,
        'end_offset': endOffset,
        'slot_index': slotIndex,
      }),
      'content_type': 'chat_resync_request',
    });
  }

  void _performSyncWithCandidates(
    Contact contact,
    int startOffset,
    int endOffset,
    int? slotIndex,
    List<String> candidates,
    int candidateIndex,
  ) async {
    if (candidateIndex >= candidates.length) {
      log('[Resync] All sync candidates exhausted for ${contact.name}');
      return;
    }

    // Check if the gap has already been filled before sending
    bool gapFilled = false;
    if (slotIndex != null) {
      final lane = await GroupDatabase.instance.getLane(
        contact.keyHash,
        slotIndex,
      );
      if (lane != null) {
        final currentWrite = lane['current_write_offset'] as int;
        final start = lane['start_offset'] as int;
        if (start + currentWrite >= endOffset) {
          gapFilled = true;
        }
      }
    } else {
      if (contact.incomingOffset >= endOffset) {
        gapFilled = true;
      }
    }

    if (gapFilled) {
      log(
        '[Resync] Gap $startOffset-$endOffset already filled. Aborting candidate sync.',
      );
      return;
    }

    final target = candidates[candidateIndex];
    log(
      '[Resync] Attempting sync from candidate $target (index $candidateIndex) for range $startOffset-$endOffset',
    );
    _sendResyncRequestFrame(
      target,
      contact.keyHash,
      startOffset,
      endOffset,
      slotIndex,
    );

    // Schedule fallback to next candidate after 6 seconds
    Timer(const Duration(seconds: 6), () {
      _performSyncWithCandidates(
        contact,
        startOffset,
        endOffset,
        slotIndex,
        candidates,
        candidateIndex + 1,
      );
    });
  }

  void _requestChatResync(
    Contact contact,
    int startOffset,
    int endOffset, {
    int? slotIndex,
  }) async {
    if (!contact.isGroup) {
      final recipientId = contact.keyHash;
      if (recipientId != userId) {
        _sendResyncRequestFrame(
          recipientId,
          null,
          startOffset,
          endOffset,
          slotIndex,
        );
      }
      return;
    }

    if (contact.isHost) {
      if (slotIndex != null) {
        final lane = await GroupDatabase.instance.getLane(
          contact.keyHash,
          slotIndex,
        );
        final recipientId = lane?['member_key_hash'] as String?;
        if (recipientId != null && recipientId != userId) {
          _sendResyncRequestFrame(
            recipientId,
            contact.keyHash,
            startOffset,
            endOffset,
            slotIndex,
          );
        }
      }
      return;
    }

    // Spoke path in group
    final candidates = await _getSyncCandidates(contact);
    if (candidates.isEmpty) return;

    _performSyncWithCandidates(
      contact,
      startOffset,
      endOffset,
      slotIndex,
      candidates,
      0,
    );
  }

  Future<void> _handleChatResyncRequest(
    String senderId,
    String envelope,
  ) async {
    try {
      final data = jsonDecode(envelope) as Map<String, dynamic>;
      final String? groupId = data['group_id'];
      final int startOffset = data['start_offset'] as int;
      final int endOffset = data['end_offset'] as int;

      final chatKey = groupId ?? senderId;
      final contactIndex = contacts.indexWhere((c) => c.keyHash == chatKey);
      if (contactIndex == -1) return;
      final contact = contacts[contactIndex];

      final List<Map<String, dynamic>> missingMessages = [];

      // 1. Standard messages in range — read from the DB so we can serve history
      // that isn't currently windowed in memory.
      final inRange = await WiltkeyDatabase.instance.getMessagesInOffsetRange(
        contact.id,
        startOffset,
        endOffset,
      );
      for (final msg in inRange) {
        if (msg.isSystem) continue;
        // msg.text is already the base64 ciphertext positioned at msg.offset
        // for both 1-on-1 and group chats — forward it as-is.
        missingMessages.add({
          'id': msg.id,
          // 'me' is a local placeholder for messages we authored — resolve it to
          // our real key hash so the recipient attributes it to us, not themselves.
          'senderId': msg.senderId == 'me' ? userId : msg.senderId,
          'text': msg.text,
          'contentType': msg.contentType,
          'timestamp': msg.timestamp.toIso8601String(),
          'isSentByMe': msg.isSentByMe,
          'offset': msg.offset,
        });
      }

      // 2. Check lane headers in groups
      final int infoLaneSize = AppState.infoLaneSize;
      if (contact.isGroup) {
        final laneSize = contact.laneSize;
        final maxMembers = contact.maxMembers;
        if (laneSize != null && maxMembers != null) {
          for (int slot = 1; slot <= maxMembers; slot++) {
            final laneStart = infoLaneSize + (slot - 1) * laneSize;
            if (startOffset <= laneStart && endOffset > laneStart) {
              final lane = await GroupDatabase.instance.getLane(
                contact.keyHash,
                slot,
              );
              if (lane != null && lane['member_key_hash'] != null) {
                final memberHash = lane['member_key_hash'] as String;
                final profile = await GroupDatabase.instance.getProfile(
                  contact.keyHash,
                  memberHash,
                );
                if (profile != null) {
                  final headerBytes = buildLaneHeader(
                    name: profile['name'] as String? ?? 'Member',
                    profileImage: profile['profile_image'] as String? ?? '',
                    arrivalOrder: slot,
                  );
                  final cipherHeader =
                      await WiltkeyOtpService.xorWithGroupKeystream(
                        contact.keyHash,
                        headerBytes,
                        laneStart,
                      );
                  missingMessages.add({
                    'id': 'header_$slot',
                    'senderId': memberHash,
                    'text': base64Encode(cipherHeader),
                    'contentType': 'group_lane_header',
                    'timestamp': DateTime.now().toIso8601String(),
                    'isSentByMe': memberHash == userId,
                    'offset': laneStart,
                  });
                }
              }
            }
          }
        }
      }

      log(
        '[Resync] Found ${missingMessages.length} messages to resync for ${contact.name} in range $startOffset-$endOffset',
      );

      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': senderId,
        'envelope': jsonEncode({
          'group_id': groupId,
          'messages': missingMessages,
        }),
        'content_type': 'chat_resync_response',
      });
    } catch (e) {
      log('[Resync Error] Failed to handle resync request: $e');
    }
  }

  Future<void> _handleChatResyncResponse(
    String senderId,
    String envelope,
  ) async {
    try {
      final data = jsonDecode(envelope) as Map<String, dynamic>;
      final String? groupId = data['group_id'];
      final List<dynamic> serializedMsgs = data['messages'] as List<dynamic>;

      final chatKey = groupId ?? senderId;
      final contactIndex = contacts.indexWhere((c) => c.keyHash == chatKey);
      if (contactIndex == -1) return;
      final contact = contacts[contactIndex];
      final recovered =
          <ChatMessage>[]; // chat messages newly persisted this pass

      bool updated = false;
      for (final item in serializedMsgs) {
        final m = item as Map<String, dynamic>;
        final String msgId = m['id'] as String;
        final int offset = m['offset'] as int;

        // Dedup against the DB (not just the loaded window) so windowing can't
        // reintroduce a message we already have.
        if (await WiltkeyDatabase.instance.messageExists(
          contact.id,
          id: msgId,
          offset: offset,
        )) {
          continue;
        }

        final String ciphertextB64 = m['text'] as String;
        final String contentType = m['contentType'] as String;
        final String innerSenderId = m['senderId'] as String;
        final DateTime timestamp = DateTime.parse(m['timestamp'] as String);
        final bool isSentByMe = m['isSentByMe'] as bool;

        if (contact.isGroup && contentType == 'group_lane_header') {
          try {
            final cipherBytes = base64Decode(ciphertextB64);
            final plainBytes = await WiltkeyOtpService.xorWithGroupKeystream(
              contact.keyHash,
              cipherBytes,
              offset,
            );
            final header = parseLaneHeader(Uint8List.fromList(plainBytes));

            final infoLaneSize = AppState.infoLaneSize;
            final laneSize = contact.laneSize ?? 0;
            if (laneSize > 0) {
              final slotIndex = ((offset - infoLaneSize) ~/ laneSize) + 1;

              await GroupDatabase.instance.upsertProfile(
                groupId: contact.keyHash,
                memberKeyHash: innerSenderId,
                name: header['name'] as String,
                profileImage: header['profileImage'] as String,
                arrivalOrder: header['arrivalOrder'] as int,
              );

              final existingLane = await GroupDatabase.instance.getLane(
                contact.keyHash,
                slotIndex,
              );
              await GroupDatabase.instance.upsertLane(
                groupId: contact.keyHash,
                slotIndex: slotIndex,
                memberKeyHash: innerSenderId,
                startOffset: offset,
                maxOffset: offset + laneSize,
                currentWriteOffset: max(
                  512,
                  existingLane?['current_write_offset'] as int? ?? 0,
                ),
                headerWritten: true,
              );
              log(
                '[Resync] Processed lane header for $innerSenderId in slot $slotIndex',
              );
              updated = true;
            }
          } catch (e) {
            log('[Resync Error] Failed to parse lane header: $e');
          }
        } else {
          final cipherBytes = base64Decode(ciphertextB64);
          String decryptedText;
          if (contact.isGroup) {
            final plainBytes = await WiltkeyOtpService.xorWithGroupKeystream(
              contact.keyHash,
              cipherBytes,
              offset,
            );
            decryptedText = utf8.decode(plainBytes);
          } else {
            final plainBytes = await WiltkeyOtpService.xorWithKeystream(
              contact.keyHash,
              cipherBytes,
              offset,
            );
            decryptedText = utf8.decode(plainBytes);
          }

          // For groups, attribution is decided by the real key hash, not the peer's
          // perspective flag (otherwise a peer's own messages arrive flagged "mine").
          final bool msgIsSentByMe = contact.isGroup
              ? (innerSenderId == userId)
              : !isSentByMe;
          final String msgSenderId = contact.isGroup
              ? (msgIsSentByMe ? 'me' : innerSenderId)
              : (msgIsSentByMe ? 'me' : contact.id);

          final newMessage = ChatMessage(
            id: msgId,
            senderId: msgSenderId,
            text: ciphertextB64,
            contentType: contentType,
            timestamp: timestamp,
            isSentByMe: msgIsSentByMe,
            offset: offset,
            decryptedText: decryptedText,
            decodedImageBytes: (contentType == 'image')
                ? base64Decode(decryptedText)
                : null,
            isDelivered: true,
          );

          recovered.add(newMessage);
          await WiltkeyDatabase.instance.saveMessage(
            newMessage,
            contact.id,
            masterKeyHex: masterKeyHex,
          );
          updated = true;

          // Replayed emoji control writes re-pin into the shared pool.
          if (contentType == 'emoji_def' || contentType == 'emoji_delete') {
            final budget = contact.isGroup
                ? AppState.infoLaneSize
                : ChatMetaStore.budgetFor(contact.maxBufferBytes);
            await _pinEmojiPayload(contact.keyHash, decryptedText, budget);
          }

          if (contact.isGroup) {
            final infoLaneSize = AppState.infoLaneSize;
            final laneSize = contact.laneSize ?? 0;
            if (laneSize > 0) {
              final slotIndex = ((offset - infoLaneSize) ~/ laneSize) + 1;
              final lane = await GroupDatabase.instance.getLane(
                contact.keyHash,
                slotIndex,
              );
              if (lane != null) {
                final startOffset = lane['start_offset'] as int;
                final relativeOffset =
                    (offset + cipherBytes.length) - startOffset;
                if (relativeOffset > (lane['current_write_offset'] as int)) {
                  await GroupDatabase.instance.updateLaneWriteOffset(
                    contact.keyHash,
                    slotIndex,
                    relativeOffset,
                  );
                }
              }
            }
          } else {
            if (offset + cipherBytes.length > contact.incomingOffset) {
              contact.incomingOffset = offset + cipherBytes.length;
            }
          }
        }
      }

      if (updated) {
        // Merge recovered messages into the window only if it's loaded; otherwise
        // they're in the DB and will appear when the chat is next opened.
        if (recovered.isNotEmpty && loadedChats.contains(contact.id)) {
          final merged = <ChatMessage>[
            ...(messages[contact.id] ?? []),
            ...recovered,
          ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          messages[contact.id] = merged;
        }
        // Recovered history can include unseen messages — refresh the unread badge
        // from the DB for a chat we're not currently viewing.
        if (recovered.isNotEmpty && activeContact?.id != contact.id) {
          final counts = await WiltkeyDatabase.instance.getUnreadCounts(
            lastReadMs,
            [contact.id],
          );
          final c = counts[contact.id] ?? 0;
          if (c > 0) {
            unreadCounts[contact.id] = c;
          } else {
            unreadCounts.remove(contact.id);
          }
        }
        await WiltkeyDatabase.instance.upsertContact(contact);
        notifyMessageReceived();
      }
    } catch (e) {
      log('[Resync Error] Failed to handle resync response: $e');
    }
  }
}
