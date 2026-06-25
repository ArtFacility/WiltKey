part of 'state.dart';

/// Pure budget math for a group's flower/readout (no AppState needed, so it's
/// directly unit-testable).
///
/// The shared pad is huge and mostly OTHER members' lanes, so
/// `remainingBufferBytes / maxBufferBytes` is misleadingly tiny (often a single
/// petal even when your own lane is full). Instead we report the user's USABLE
/// budget: their own remaining lane space PLUS the still-unassigned lanes they
/// could claim (extensions), ignoring lanes occupied by other members.
({double fraction, int usableRemaining, int usableCapacity})
computeGroupBudget({
  required bool isGroup,
  required int laneSize,
  required int remaining,
  required int additionalSlotCount,
  required int freeLanes,
  required int rawMaxBuffer,
  required double rawCharge,
}) {
  if (!isGroup || laneSize <= 0) {
    // Non-group / pre-metadata: fall back to the raw charge.
    return (
      fraction: rawCharge.clamp(0.0, 1.0),
      usableRemaining: remaining,
      usableCapacity: rawMaxBuffer,
    );
  }
  final myCapacity = laneSize * (1 + additionalSlotCount);
  final myRemaining = remaining.clamp(0, myCapacity);
  final freeCapacity = freeLanes.clamp(0, 1 << 30) * laneSize;

  final usableRemaining = myRemaining + freeCapacity;
  final usableCapacity = myCapacity + freeCapacity;
  final fraction = usableCapacity <= 0
      ? 0.0
      : (usableRemaining / usableCapacity).clamp(0.0, 1.0);
  return (
    fraction: fraction,
    usableRemaining: usableRemaining,
    usableCapacity: usableCapacity,
  );
}

extension AppStateGroups on AppState {
  /// Usable budget for a group, resolving free-lane count from live metadata
  /// (falling back to maxMembers − memberCount before metadata has synced).
  /// See [computeGroupBudget] for the math.
  ({double fraction, int usableRemaining, int usableCapacity}) groupBudget(
    Contact group,
  ) {
    int freeLanes = 0;
    final slots = groupSlotsInfo[group.id];
    if (slots != null) {
      freeLanes = ((slots['total'] ?? 0) - (slots['used'] ?? 0));
    } else if (group.maxMembers != null) {
      freeLanes = group.maxMembers! - (group.memberCount ?? 1);
    }
    return computeGroupBudget(
      isGroup: group.isGroup,
      laneSize: group.laneSize ?? 0,
      remaining: group.remainingBufferBytes,
      additionalSlotCount: group.additionalSlots.length,
      freeLanes: freeLanes < 0 ? 0 : freeLanes,
      rawMaxBuffer: group.maxBufferBytes,
      rawCharge: group.chargePercentage,
    );
  }

  Uint8List buildLaneHeader({
    required String name,
    required String profileImage,
    required int arrivalOrder,
    String permissions = '',
  }) {
    final header = Uint8List(512);
    final nameBytes = utf8.encode(name);
    for (int i = 0; i < min(64, nameBytes.length); i++) {
      header[i] = nameBytes[i];
    }
    final imgBytes = utf8.encode(profileImage);
    for (int i = 0; i < min(400, imgBytes.length); i++) {
      header[64 + i] = imgBytes[i];
    }
    header[464] = (arrivalOrder >> 24) & 0xFF;
    header[465] = (arrivalOrder >> 16) & 0xFF;
    header[466] = (arrivalOrder >> 8) & 0xFF;
    header[467] = arrivalOrder & 0xFF;
    final permBytes = utf8.encode(permissions);
    for (int i = 0; i < min(44, permBytes.length); i++) {
      header[468 + i] = permBytes[i];
    }
    return header;
  }

  Map<String, dynamic> parseLaneHeader(Uint8List bytes) {
    int nameLen = 0;
    while (nameLen < 64 && bytes[nameLen] != 0) {
      nameLen++;
    }
    final name = utf8.decode(bytes.sublist(0, nameLen));
    int imgLen = 0;
    while (imgLen < 400 && bytes[64 + imgLen] != 0) {
      imgLen++;
    }
    final profileImage = utf8.decode(bytes.sublist(64, 64 + imgLen));
    final arrivalOrder =
        (bytes[464] << 24) |
        (bytes[465] << 16) |
        (bytes[466] << 8) |
        bytes[467];
    int permLen = 0;
    while (permLen < 44 && bytes[468 + permLen] != 0) {
      permLen++;
    }
    final permissions = utf8.decode(bytes.sublist(468, 468 + permLen));
    return {
      'name': name,
      'profileImage': profileImage,
      'arrivalOrder': arrivalOrder,
      'permissions': permissions,
    };
  }

  Future<void> sendLaneHeader(String groupId, int slotIndex) async {
    try {
      final contactIndex = contacts.indexWhere(
        (c) => c.isGroup && c.keyHash == groupId,
      );
      if (contactIndex == -1) return;
      final contact = contacts[contactIndex];
      final lane = await GroupDatabase.instance.getLane(groupId, slotIndex);
      if (lane == null) return;
      final startOffset = lane['start_offset'] as int;
      final maxOffset = lane['max_offset'] as int;
      final currentWriteOffset = lane['current_write_offset'] as int;
      final headerWritten = (lane['header_written'] as int) == 1;

      if (headerWritten && currentWriteOffset >= 512) {
        log('[Group] Lane header already written for slot $slotIndex');
        return;
      }

      log('[Group] Writing lane header for slot $slotIndex');
      final headerBytes = buildLaneHeader(
        name: deviceName.isNotEmpty ? deviceName : 'Member',
        profileImage: profileImageB64,
        arrivalOrder: slotIndex,
      );
      final cipherHeader = await WiltkeyOtpService.xorWithGroupKeystream(
        groupId,
        headerBytes,
        startOffset,
      );

      final headerEnvelope = jsonEncode({
        'group_id': groupId,
        'sender_id': userId,
        'slot_index': slotIndex,
        'offset': startOffset,
        'd': base64Encode(cipherHeader),
        't': 'group_lane_header',
      });

      for (final memberHash in contact.memberKeyHashes) {
        if (memberHash == userId) continue;
        WebSocketClient().sendWSMessage({
          'type': 'SEND_MESSAGE',
          'recipient_id': memberHash,
          'envelope': headerEnvelope,
          'content_type': 'group_lane_header',
        });
      }

      await GroupDatabase.instance.upsertLane(
        groupId: groupId,
        slotIndex: slotIndex,
        memberKeyHash: userId,
        startOffset: startOffset,
        maxOffset: maxOffset,
        currentWriteOffset: max(512, currentWriteOffset),
        headerWritten: true,
      );
      log('[Group] Lane header sent for slot $slotIndex');
    } catch (e) {
      log('[Group Error] Failed to send lane header: $e');
    }
  }

  Future<void> syncGroupLaneHeaders() async {
    for (final contact in contacts) {
      if (contact.isGroup) {
        final lanes = await GroupDatabase.instance.getAllLanes(contact.keyHash);
        for (final lane in lanes) {
          if (lane['member_key_hash'] == userId &&
              lane['header_written'] == 0) {
            await sendLaneHeader(contact.keyHash, lane['slot_index'] as int);
          }
        }
      }
    }
  }

  /// Upserts a group member profile without clobbering already-known good values
  /// (e.g. a fallback responder with a blank avatar must not erase a real one).
  Future<void> upsertGroupProfileMerged({
    required String groupId,
    required String memberKeyHash,
    String? name,
    String? profileImage,
    int? arrivalOrder,
  }) async {
    final existing = await GroupDatabase.instance.getProfile(
      groupId,
      memberKeyHash,
    );
    final mergedName = (name != null && name.isNotEmpty)
        ? name
        : (existing?['name'] as String? ?? '');
    final mergedImage = (profileImage != null && profileImage.isNotEmpty)
        ? profileImage
        : (existing?['profile_image'] as String? ?? '');
    final mergedOrder = (arrivalOrder != null && arrivalOrder > 0)
        ? arrivalOrder
        : (existing?['arrival_order'] as int? ?? 0);
    await GroupDatabase.instance.upsertProfile(
      groupId: groupId,
      memberKeyHash: memberKeyHash,
      name: mergedName,
      profileImage: mergedImage,
      arrivalOrder: mergedOrder,
    );
  }

  Future<void> sendGroupMetadataUpdateToSpoke(
    Contact group,
    String spokeKeyHash,
  ) async {
    try {
      final groupId = group.keyHash;
      final info = await GroupDatabase.instance.getGroupInfo(groupId);
      if (info == null) return;
      final lanes = await GroupDatabase.instance.getAllLanes(groupId);
      final List<Map<String, dynamic>> slotAssignments = [];
      for (final lane in lanes) {
        slotAssignments.add({
          'slot_index': lane['slot_index'],
          'member_key_hash': lane['member_key_hash'],
        });
      }
      final profiles = await GroupDatabase.instance.getAllProfiles(groupId);
      final List<Map<String, dynamic>> membersProfiles = [];
      for (final p in profiles) {
        membersProfiles.add({
          'key_hash': p['member_key_hash'],
          'name': p['name'],
          'profile_image': p['profile_image'],
          'arrival_order': p['arrival_order'],
        });
      }

      final payload = jsonEncode({
        'group_name': info['group_name'],
        'group_icon': info['group_icon'],
        'lane_size': info['lane_size'],
        'max_members': info['max_members'],
        'total_size': info['total_size'],
        'host_key_hash': info['host_key_hash'],
        'lane_assignments': slotAssignments,
        'members_profiles': membersProfiles,
      });

      final groupSeed = group.groupSeed ?? '';
      if (groupSeed.isEmpty) {
        log(
          '[Group Host Error] Group seed is empty. Cannot encrypt group_info_update.',
        );
        return;
      }
      final keyHex = sha256.convert(utf8.encode(groupSeed)).toString();
      final encryptedPayload = WiltkeyPersistence().encryptString(
        payload,
        keyHex,
      );

      final envelope = jsonEncode({
        'group_id': groupId,
        'sender_id': userId,
        'slot_index': 0,
        'offset': 0,
        'd': encryptedPayload,
        't': 'group_info_update',
      });

      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': spokeKeyHash,
        'envelope': envelope,
        'content_type': 'group_info_update',
      });

      log(
        '[Group Host] Sent group metadata update to spoke $spokeKeyHash (offset: 0)',
      );
    } catch (e) {
      log('[Group Host Error] Failed to send group metadata update: $e');
    }
  }

  Future<void> broadcastGroupMetadataUpdate(Contact group) async {
    if (!group.isGroup || !group.isHost) return;
    log('[Group Host] Broadcasting metadata update to all members...');
    for (final spokeKeyHash in group.memberKeyHashes) {
      if (spokeKeyHash == userId) continue;
      await sendGroupMetadataUpdateToSpoke(group, spokeKeyHash);
    }
  }

  /// Announces OUR current name + avatar to every member of [group]. Unlike the
  /// host-only `group_info_update` (which only ever carries join-time data), any
  /// member can call this so a profile *change* actually propagates, full-mesh.
  /// Encrypted with `SHA256(groupSeed)`, like the other group metadata channels.
  Future<void> sendMyProfileToGroup(Contact group) async {
    if (!group.isGroup) return;
    final seed = group.groupSeed ?? '';
    if (seed.isEmpty) return;
    final keyHex = sha256.convert(utf8.encode(seed)).toString();
    final payload = jsonEncode({
      'name': effectiveDeviceName,
      'profile_image': profileImageB64,
      'v': 1,
    });
    final enc = WiltkeyPersistence().encryptString(payload, keyHex);
    final envelope = jsonEncode({
      'group_id': group.keyHash,
      'sender_id': userId,
      'd': enc,
      't': 'group_member_profile',
    });
    await ensureWebSocketConnected();
    for (final memberHash in group.memberKeyHashes) {
      if (memberHash == userId) continue;
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': memberHash,
        'envelope': envelope,
        'content_type': 'group_member_profile',
      });
    }
    log(
      '[Group] Announced my profile to ${group.memberKeyHashes.length - 1} member(s) of "${group.name}"',
    );
  }

  /// Push our profile to every group we're in (on profile edit / connect).
  Future<void> broadcastMyProfileToGroups() async {
    for (final c in contacts) {
      if (c.isGroup) await sendMyProfileToGroup(c);
    }
  }

  /// Returns the absolute keystream offset where a member lane begins.
  int laneStartFor(int slotIndex, int laneSize) =>
      AppState.infoLaneSize + (slotIndex - 1) * laneSize;

  /// Builds the ordered list of peers we can ask for metadata: host first,
  /// then the remaining members by arrival order. Excludes ourselves.
  Future<List<String>> buildMetadataCandidates(Contact group) async {
    final candidates = <String>[];
    if (group.hostKeyHash != null && group.hostKeyHash != userId) {
      candidates.add(group.hostKeyHash!);
    }
    final profiles = await GroupDatabase.instance.getAllProfiles(group.keyHash);
    for (final p in profiles) {
      final keyHash = p['member_key_hash'] as String;
      if (keyHash != userId && !candidates.contains(keyHash)) {
        candidates.add(keyHash);
      }
    }
    for (final keyHash in group.memberKeyHashes) {
      if (keyHash != userId && !candidates.contains(keyHash)) {
        candidates.add(keyHash);
      }
    }
    return candidates;
  }

  void _sendMetadataRequestFrame(String recipientId, String groupId) {
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': recipientId,
      'envelope': jsonEncode({'group_id': groupId}),
      'content_type': 'group_metadata_request',
    });
  }

  /// Spoke pulls the latest metadata. Tries the host first and automatically
  /// falls back to other members if no metadata arrives in time. Cancelled
  /// automatically once a `group_info_update` is processed (see [onGroupMetadataReceived]).
  Future<void> requestGroupMetadata(Contact group) async {
    if (!group.isGroup || group.isHost) return;
    // A sync cycle is already running for this group; let it finish.
    if (groupMetaSyncTimers.containsKey(group.keyHash)) return;
    await ensureWebSocketConnected();

    final candidates = await buildMetadataCandidates(group);
    if (candidates.isEmpty) {
      log('[Group Sync] No candidates available to request metadata from.');
      return;
    }

    _attemptMetadataFromCandidate(group, candidates, 0);
  }

  void _attemptMetadataFromCandidate(
    Contact group,
    List<String> candidates,
    int index,
  ) {
    final target = candidates[index % candidates.length];
    log('[Group Sync] Requesting metadata from $target (attempt ${index + 1})');
    _sendMetadataRequestFrame(target, group.keyHash);

    // Keep retrying (cycling candidates) until metadata arrives and
    // onGroupMetadataReceived() cancels us. The request is also queued server-side,
    // so a member that joined while the host was briefly offline still heals once the
    // host returns. Fast for the first cycle, then back off; bounded so a permanently
    // unreachable group doesn't poll forever (~10 min).
    const int maxAttempts = 40;
    if (index + 1 >= maxAttempts) {
      groupMetaSyncTimers.remove(group.keyHash);
      log(
        '[Group Sync] Metadata sync gave up after $maxAttempts attempts for "${group.name}". Use manual sync to retry.',
      );
      return;
    }
    final Duration delay = (index + 1 < candidates.length)
        ? const Duration(seconds: 5)
        : const Duration(seconds: 15);
    groupMetaSyncTimers.remove(group.keyHash)?.cancel();
    groupMetaSyncTimers[group.keyHash] = Timer(delay, () {
      _attemptMetadataFromCandidate(group, candidates, index + 1);
    });
  }

  /// Called from the receive path when a `group_info_update` is successfully applied,
  /// so we stop pinging fallback candidates.
  void onGroupMetadataReceived(String groupId) {
    groupMetaSyncTimers.remove(groupId)?.cancel();
  }

  /// Pulls any messages we missed by requesting a full resync from EVERY known
  /// member (deduped on receipt). The offline server queue only holds messages
  /// that were addressed to us while we were away, so peers who didn't yet know
  /// us as a member never queued anything — this sweep catches those. Debounced.
  Future<void> autoSyncGroup(Contact group) async {
    if (!group.isGroup) return;
    final now = DateTime.now();
    final last = lastGroupAutoSync[group.keyHash];
    if (last != null && now.difference(last) < const Duration(seconds: 8))
      return;
    lastGroupAutoSync[group.keyHash] = now;

    await ensureWebSocketConnected();

    // Announce our own current name/avatar to the group so members heal any
    // stale or missing profile for us (full-mesh; no host relay needed).
    await sendMyProfileToGroup(group);

    // Spokes also (re)pull metadata so they learn the full roster / icon.
    if (!group.isHost) requestGroupMetadata(group);

    final int end = group.totalGroupSize ?? (1024 * 1024 * 20);
    int count = 0;
    for (final memberHash in group.memberKeyHashes) {
      if (memberHash == userId) continue;
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': memberHash,
        'envelope': jsonEncode({
          'group_id': group.keyHash,
          'start_offset': 0,
          'end_offset': end,
        }),
        'content_type': 'chat_resync_request',
      });
      count++;
    }
    log(
      '[Group Sync] Auto-sync requested from $count member(s) for "${group.name}"',
    );
  }

  /// Sweeps every group (used on WebSocket reconnect).
  Future<void> autoSyncAllGroups() async {
    for (final c in contacts) {
      if (c.isGroup) await autoSyncGroup(c);
    }
  }

  /// Manual "sync" action against a specific member: pulls fresh metadata
  /// (profiles/icon/membership) AND requests any missing messages.
  Future<void> syncGroupFromMember(Contact group, String memberKeyHash) async {
    await ensureWebSocketConnected();
    log('[Group Sync] Manual sync from $memberKeyHash');
    _sendMetadataRequestFrame(memberKeyHash, group.keyHash);
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': memberKeyHash,
      'envelope': jsonEncode({
        'group_id': group.keyHash,
        'start_offset': 0,
        'end_offset': group.totalGroupSize ?? (1024 * 1024 * 20),
      }),
      'content_type': 'chat_resync_request',
    });
  }

  Future<String?> sendGroupMessage(
    String text, {
    String contentType = 'text',
  }) async {
    if (activeContact == null ||
        !activeContact!.isGroup ||
        status == AppStatus.nuked) {
      return 'Cannot send group message';
    }
    final contact = activeContact!;
    final groupId = contact.keyHash;

    // maxMessageSize is a TEXT policy; images and emoji defs are bounded by lane
    // space + the sender's own pre-send size checks, so don't reject them here.
    final bool isImage =
        contentType == 'image' || contentType == 'image_hidden';
    final bool isEmojiCtl =
        contentType == 'emoji_def' || contentType == 'emoji_delete';
    final payloadBytes = utf8.encode(text).length;
    if (!isImage &&
        !isEmojiCtl &&
        contact.maxMessageSize != null &&
        payloadBytes > contact.maxMessageSize!) {
      return 'Message exceeds max size (${contact.maxMessageSize} bytes)';
    }

    // Show the bubble immediately as a pending placeholder; finalize after the
    // slow lane/keystream work. Emoji control writes aren't visible bubbles, so
    // they skip the placeholder and are built fully at the end as before.
    final int sentTs = DateTime.now().millisecondsSinceEpoch;
    final messageId = DateTime.now().toString();
    ChatMessage? placeholder;
    if (!isEmojiCtl) {
      placeholder = ChatMessage(
        id: messageId,
        senderId: 'me',
        text: '',
        contentType: contentType,
        timestamp: DateTime.fromMillisecondsSinceEpoch(sentTs),
        isSentByMe: true,
        isPending: true,
        decodedImageBytes: isImage ? base64Decode(text) : null,
        decryptedText: text,
      );
      appendLoadedMessage(contact.id, placeholder);
      notifyListeners();
    }
    void abortPlaceholder() {
      if (placeholder != null) {
        messages[contact.id]?.removeWhere((m) => m.id == placeholder!.id);
        notifyListeners();
      }
    }

    await ensureWebSocketConnected();

    final lanes = await GroupDatabase.instance.getAllLanes(groupId);
    // Slot 0 is the shared 1MB info lane — never a writable message lane.
    final myLanes = lanes
        .where(
          (l) =>
              l['member_key_hash'] == userId && (l['slot_index'] as int) != 0,
        )
        .toList();
    if (myLanes.isEmpty) {
      abortPlaceholder();
      return 'No lane assigned to you in this group';
    }

    Map<String, dynamic>? activeLane;
    for (final lane in myLanes) {
      final start = lane['start_offset'] as int;
      final max = lane['max_offset'] as int;
      final current = lane['current_write_offset'] as int;
      final headerWritten = (lane['header_written'] as int) == 1;
      final neededSpace = headerWritten ? payloadBytes : (512 + payloadBytes);
      if (current + neededSpace <= (max - start)) {
        activeLane = lane;
        break;
      }
    }

    if (activeLane == null) {
      abortPlaceholder();
      return 'Lane depleted. Request refill from Host.';
    }

    final slotIndex = activeLane['slot_index'] as int;
    final startOffset = activeLane['start_offset'] as int;
    final maxOffset = activeLane['max_offset'] as int;
    int currentWriteOffset = activeLane['current_write_offset'] as int;
    bool headerWritten = (activeLane['header_written'] as int) == 1;

    if (!headerWritten) {
      log('[Group] Writing lane header for slot $slotIndex');
      final headerBytes = buildLaneHeader(
        name: deviceName.isNotEmpty ? deviceName : 'Member',
        profileImage: profileImageB64,
        arrivalOrder: slotIndex,
      );
      final cipherHeader = await WiltkeyOtpService.xorWithGroupKeystream(
        groupId,
        headerBytes,
        startOffset,
      );
      final headerEnvelope = jsonEncode({
        'group_id': groupId,
        'sender_id': userId,
        'slot_index': slotIndex,
        'offset': startOffset,
        'd': base64Encode(cipherHeader),
        't': 'group_lane_header',
      });
      for (final memberHash in contact.memberKeyHashes) {
        if (memberHash == userId) continue;
        WebSocketClient().sendWSMessage({
          'type': 'SEND_MESSAGE',
          'recipient_id': memberHash,
          'envelope': headerEnvelope,
          'content_type': 'group_lane_header',
        });
      }
      currentWriteOffset = 512;
      await GroupDatabase.instance.upsertLane(
        groupId: groupId,
        slotIndex: slotIndex,
        memberKeyHash: userId,
        startOffset: startOffset,
        maxOffset: maxOffset,
        currentWriteOffset: 512,
        headerWritten: true,
      );
    }

    final rawBytes = utf8.encode(text);
    final writeOffset = startOffset + currentWriteOffset;
    final cipherBytes = await WiltkeyOtpService.xorWithGroupKeystream(
      groupId,
      rawBytes,
      writeOffset,
    );

    final envelope = jsonEncode({
      'group_id': groupId,
      'sender_id': userId,
      'slot_index': slotIndex,
      'offset': writeOffset,
      'd': base64Encode(cipherBytes),
      't': contentType,
      'id': messageId,
      // Plaintext send-time (unix millis). Costs no OTP (not XOR'd) and travels
      // with the message through resync, so ordering is stable even when delivery
      // is out of order.
      'ts': sentTs,
    });

    final bool socketConnected = WebSocketClient().isConnected;
    for (final memberHash in contact.memberKeyHashes) {
      if (memberHash == userId) continue;
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': memberHash,
        'envelope': envelope,
        'content_type': 'group_message',
      });
    }

    final newWriteOffset = currentWriteOffset + rawBytes.length;
    await GroupDatabase.instance.updateLaneWriteOffset(
      groupId,
      slotIndex,
      newWriteOffset,
    );

    int remaining = 0;
    for (final lane in myLanes) {
      final start = lane['start_offset'] as int;
      final max = lane['max_offset'] as int;
      final current = (lane['slot_index'] == slotIndex)
          ? newWriteOffset
          : (lane['current_write_offset'] as int);
      remaining += (max - start) - current;
    }
    contact.remainingBufferBytes = remaining;
    contact.isWilted = remaining < 74;

    // Finalize the pending placeholder in place (or build the message fresh for
    // the non-visible emoji-control path).
    final ChatMessage newMessage =
        placeholder ??
        ChatMessage(
          id: messageId,
          senderId: 'me',
          text: '',
          contentType: contentType,
          timestamp: DateTime.fromMillisecondsSinceEpoch(sentTs),
          isSentByMe: true,
          decryptedText: text,
        );
    newMessage.text = base64Encode(cipherBytes);
    newMessage.offset = writeOffset;
    newMessage.isPending = false;
    newMessage.isFailed = !socketConnected;
    if (placeholder == null) {
      appendLoadedMessage(contact.id, newMessage);
    }
    await WiltkeyDatabase.instance.saveMessage(
      newMessage,
      contact.id,
      masterKeyHex: masterKeyHex,
    );
    await WiltkeyDatabase.instance.upsertContact(contact);
    notifyListeners();
    updateGroupMembersMetadata(contact);
    _persistence.saveState(this);
    return null;
  }

  void requestLaneRefill(Contact group) {
    if (group.isGroup && !group.isHost && group.hostKeyHash != null) {
      log(
        '[Group Spoke] Requesting lane refill from Host: ${group.hostKeyHash}',
      );
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': group.hostKeyHash!,
        'envelope': jsonEncode({'group_id': group.keyHash}),
        'content_type': 'group_lane_refill_request',
      });
    }
  }

  Future<void> grantLaneRefill(Contact group, String memberKeyHash) async {
    final groupId = group.keyHash;
    final emptyLanes = await GroupDatabase.instance.getEmptyLanes(groupId);
    if (emptyLanes.isEmpty) {
      log('[Group Host] No empty slots available to grant refill!');
      return;
    }
    final nextLane = emptyLanes.first;
    final slotIndex = nextLane['slot_index'] as int;

    await GroupDatabase.instance.assignLaneToMember(
      groupId,
      slotIndex,
      memberKeyHash,
    );
    await broadcastGroupMetadataUpdate(group);

    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': memberKeyHash,
      'envelope': jsonEncode({'group_id': groupId, 'slot_index': slotIndex}),
      'content_type': 'group_lane_refill_granted',
    });

    final systemMsg = ChatMessage(
      id: DateTime.now().toString(),
      senderId: 'system',
      text: 'Granted lane refill (Slot $slotIndex) to member.',
      timestamp: DateTime.now(),
      isSentByMe: true,
      decryptedText: 'Granted lane refill (Slot $slotIndex) to member.',
    );
    appendLoadedMessage(group.id, systemMsg);
    await WiltkeyDatabase.instance.saveMessage(
      systemMsg,
      group.id,
      masterKeyHex: masterKeyHex,
    );
    notifyListeners();
    _persistence.saveState(this);
  }

  void updateGroupMembersMetadata(Contact group) async {
    if (!group.isGroup) return;
    final groupId = group.keyHash;

    try {
      final info = await GroupDatabase.instance.getGroupInfo(groupId);
      if (info == null) return;
      final laneSize = info['lane_size'] as int;
      final totalSlots = info['max_members'] as int;

      final lanes = await GroupDatabase.instance.getAllLanes(groupId);
      final profiles = await GroupDatabase.instance.getAllProfiles(groupId);

      // Update contact in contacts list if group name/icon has updated
      final newName = info['group_name'] as String?;
      final newIcon = info['group_icon'] as String?;
      if (newName != null && newName.isNotEmpty) {
        final idx = contacts.indexWhere((c) => c.keyHash == groupId);
        if (idx != -1) {
          final existing = contacts[idx];
          if (existing.name != newName || existing.profileImageB64 != newIcon) {
            final updated = Contact(
              id: existing.id,
              name: newName,
              keyHash: existing.keyHash,
              relayUrl: existing.relayUrl,
              isPrivateNode: existing.isPrivateNode,
              maxBufferBytes: existing.maxBufferBytes,
              remainingBufferBytes: existing.remainingBufferBytes,
              peerRemainingBufferBytes: existing.peerRemainingBufferBytes,
              lastActivity: existing.lastActivity,
              isWilted: existing.isWilted,
              isGroup: true,
              memberCount: existing.memberCount,
              hostName: existing.hostName,
              isHost: existing.isHost,
              hostKeyHash: existing.hostKeyHash,
              memberKeyHashes: existing.memberKeyHashes,
              groupIconHex: newIcon ?? existing.groupIconHex,
              maxMembers: existing.maxMembers,
              maxMessageSize: existing.maxMessageSize,
              imagesAllowed: existing.imagesAllowed,
              joinedAt: existing.joinedAt,
              shortNick: existing.shortNick,
              profileImageB64: newIcon ?? existing.profileImageB64,
              outgoingOffset: existing.outgoingOffset,
              outgoingMaxOffset: existing.outgoingMaxOffset,
              incomingOffset: existing.incomingOffset,
              incomingMaxOffset: existing.incomingMaxOffset,
              groupSeed: existing.groupSeed,
              laneSize: existing.laneSize,
              totalGroupSize: existing.totalGroupSize,
              slotIndex: existing.slotIndex,
              additionalSlots: existing.additionalSlots,
            );
            contacts[idx] = updated;
            if (activeContact?.keyHash == groupId) {
              activeContact = updated;
            }
            await WiltkeyDatabase.instance.upsertContact(updated);
          }
        }
      }

      final List<Map<String, dynamic>> list = [];
      final Map<String, int> memberRemainingBytes = {};

      int assignedSlots = 0;
      for (final lane in lanes) {
        final memberHash = lane['member_key_hash'] as String?;
        if (memberHash != null) {
          final start = lane['start_offset'] as int;
          final max = lane['max_offset'] as int;
          final current = lane['current_write_offset'] as int;
          final remaining = (max - start) - current;
          memberRemainingBytes[memberHash] =
              (memberRemainingBytes[memberHash] ?? 0) + remaining;

          if ((lane['slot_index'] as int) > 0) {
            assignedSlots++;
          }
        }
      }

      groupSlotsInfo[group.id] = {'used': assignedSlots, 'total': totalSlots};

      final Map<String, Map<String, String>> cachedGroupProfiles = {};
      for (final p in profiles) {
        final memberHash = p['member_key_hash'] as String;
        cachedGroupProfiles[memberHash] = {
          'name': p['name'] as String? ?? '',
          'profile_image': p['profile_image'] as String? ?? '',
        };
      }
      // Keyed by the local contact id to match the UI read sites
      // (groupMembersMetadata / groupSlotsInfo are also keyed by contact id).
      groupProfilesCache[group.id] = cachedGroupProfiles;

      if (group.isHost) {
        list.add({
          'keyHash': userId,
          'name': '${deviceName.isNotEmpty ? deviceName : 'Host'} (Host/You)',
          'isSelf': true,
          'isHost': true,
          'remaining': memberRemainingBytes[userId] ?? 0,
          'max': laneSize,
        });
      } else {
        final hostNameStr = group.hostName ?? 'Host';
        list.add({
          'keyHash': group.hostKeyHash ?? '',
          'name': '$hostNameStr (Host)',
          'isSelf': false,
          'isHost': true,
          'remaining': memberRemainingBytes[group.hostKeyHash!] ?? 0,
          'max': laneSize,
        });

        list.add({
          'keyHash': userId,
          'name': 'You',
          'isSelf': true,
          'isHost': false,
          'remaining': memberRemainingBytes[userId] ?? 0,
          'max': laneSize,
        });
      }

      for (final p in profiles) {
        final memberHash = p['member_key_hash'] as String;
        if (memberHash == userId || memberHash == group.hostKeyHash) continue;

        final name = p['name'] as String;
        final remaining = memberRemainingBytes[memberHash] ?? 0;

        list.add({
          'keyHash': memberHash,
          'name': name,
          'isSelf': false,
          'isHost': false,
          'remaining': remaining,
          'max': laneSize,
        });
      }

      groupMembersMetadata[group.id] = list;
      notifyListeners();
    } catch (e) {
      log('[Group Error] Failed to update members metadata: $e');
    }
  }

  Future<void> addGroupChat({
    required String name,
    required String groupId,
    required String relayUrl,
    required int totalGroupSize,
    required int laneSize,
    required String groupIconHex,
    required int maxMembers,
    required String groupSeed,
  }) async {
    await WiltkeyOtpService.generateGroupKeystream(
      groupId,
      groupSeed,
      totalGroupSize,
    );

    await GroupDatabase.instance.init();
    await GroupDatabase.instance.upsertGroupInfo(
      groupId: groupId,
      groupName: name,
      groupIcon: groupIconHex,
      laneSize: laneSize,
      maxMembers: maxMembers,
      totalSize: totalGroupSize,
      groupSeedEncrypted: groupSeed,
      isHost: true,
      hostKeyHash: userId,
      infoLaneWriteOffset: 0,
    );

    final infoLaneSize = AppState.infoLaneSize;
    await GroupDatabase.instance.upsertLane(
      groupId: groupId,
      slotIndex: 0,
      startOffset: 0,
      maxOffset: infoLaneSize,
      currentWriteOffset: 0,
      memberKeyHash: userId,
    );

    await GroupDatabase.instance.upsertLane(
      groupId: groupId,
      slotIndex: 1,
      startOffset: infoLaneSize,
      maxOffset: infoLaneSize + laneSize,
      currentWriteOffset: 0,
      memberKeyHash: userId,
    );

    for (int i = 2; i <= maxMembers; i++) {
      await GroupDatabase.instance.upsertLane(
        groupId: groupId,
        slotIndex: i,
        startOffset: infoLaneSize + (i - 1) * laneSize,
        maxOffset: infoLaneSize + i * laneSize,
        memberKeyHash: null,
      );
    }

    await GroupDatabase.instance.upsertProfile(
      groupId: groupId,
      memberKeyHash: userId,
      name: deviceName.isNotEmpty ? deviceName : 'Host',
      profileImage: profileImageB64,
      arrivalOrder: 1,
    );

    final newGroup = Contact(
      id: 'g${contacts.length + 1}',
      name: name,
      keyHash: groupId,
      relayUrl: relayUrl,
      isPrivateNode: _isUrlPrivate(relayUrl),
      maxBufferBytes: totalGroupSize,
      remainingBufferBytes: laneSize,
      peerRemainingBufferBytes: 0,
      lastActivity: DateTime.now(),
      isWilted: false,
      isGroup: true,
      memberCount: 1,
      hostName: deviceName.isNotEmpty ? deviceName : 'You',
      isHost: true,
      hostKeyHash: userId,
      memberKeyHashes: [userId],
      groupIconHex: groupIconHex,
      maxMembers: maxMembers,
      joinedAt: DateTime.now(),
      groupSeed: groupSeed,
      laneSize: laneSize,
      totalGroupSize: totalGroupSize,
      slotIndex: 1,
    );

    contacts.add(newGroup);
    final systemMsg = ChatMessage(
      id: DateTime.now().toString(),
      senderId: 'system',
      text: 'Group chat "$name" created. Secure enclave active.',
      timestamp: DateTime.now(),
      isSentByMe: false,
      decryptedText: 'Group chat "$name" created. Secure enclave active.',
    );
    messages[newGroup.id] = [systemMsg];
    loadedChats.add(newGroup.id);
    hasMoreOlder[newGroup.id] = false;
    await WiltkeyDatabase.instance.upsertContact(newGroup);
    await WiltkeyDatabase.instance.saveMessage(
      systemMsg,
      newGroup.id,
      masterKeyHex: masterKeyHex,
    );

    notifyMessageReceived();
    log('[Group] Created new group with Shared Pad: $name ($groupId)');
  }

  Future<void> addOrRechargeGroupContact({
    required String name,
    required String relayUrl,
    required int totalSize,
    required int laneSize,
    required String groupId,
    required String groupSeed,
    required int slotIndex,
    required String hostKeyHash,
    required String hostName,
    String? groupIconHex,
    int? maxMembers,
  }) async {
    await WiltkeyOtpService.generateGroupKeystream(
      groupId,
      groupSeed,
      totalSize,
    );

    await GroupDatabase.instance.init();
    await GroupDatabase.instance.upsertGroupInfo(
      groupId: groupId,
      groupName: name,
      groupIcon: groupIconHex ?? '',
      laneSize: laneSize,
      maxMembers: maxMembers ?? 20,
      totalSize: totalSize,
      groupSeedEncrypted: groupSeed,
      isHost: false,
      hostKeyHash: hostKeyHash,
      infoLaneWriteOffset: 0,
    );

    final infoLaneSize = AppState.infoLaneSize;
    await GroupDatabase.instance.upsertLane(
      groupId: groupId,
      slotIndex: 0,
      startOffset: 0,
      maxOffset: infoLaneSize,
      memberKeyHash: hostKeyHash,
    );

    await GroupDatabase.instance.upsertLane(
      groupId: groupId,
      slotIndex: slotIndex,
      startOffset: infoLaneSize + (slotIndex - 1) * laneSize,
      maxOffset: infoLaneSize + slotIndex * laneSize,
      currentWriteOffset: 0,
      memberKeyHash: userId,
      headerWritten: false,
    );

    await GroupDatabase.instance.upsertProfile(
      groupId: groupId,
      memberKeyHash: hostKeyHash,
      name: hostName,
      profileImage: '',
      arrivalOrder: 1,
    );

    int existingIndex = contacts.indexWhere((c) => c.keyHash == groupId);
    if (existingIndex != -1) {
      final existing = contacts[existingIndex];
      final updatedContact = Contact(
        id: existing.id,
        name: name,
        keyHash: groupId,
        relayUrl: relayUrl,
        isPrivateNode: _isUrlPrivate(relayUrl),
        maxBufferBytes: totalSize,
        remainingBufferBytes: laneSize,
        peerRemainingBufferBytes: 0,
        lastActivity: DateTime.now(),
        isWilted: false,
        isGroup: true,
        memberCount: 2,
        hostName: hostName,
        isHost: false,
        hostKeyHash: hostKeyHash,
        memberKeyHashes: [hostKeyHash, userId],
        groupIconHex: groupIconHex,
        maxMembers: maxMembers,
        joinedAt: existing.joinedAt ?? DateTime.now(),
        groupSeed: groupSeed,
        laneSize: laneSize,
        totalGroupSize: totalSize,
        slotIndex: slotIndex,
      );
      contacts[existingIndex] = updatedContact;
      await WiltkeyDatabase.instance.upsertContact(updatedContact);
    } else {
      final newContact = Contact(
        id: 'g${contacts.length + 1}',
        name: name,
        keyHash: groupId,
        relayUrl: relayUrl,
        isPrivateNode: _isUrlPrivate(relayUrl),
        maxBufferBytes: totalSize,
        remainingBufferBytes: laneSize,
        peerRemainingBufferBytes: 0,
        lastActivity: DateTime.now(),
        isWilted: false,
        isGroup: true,
        memberCount: 2,
        hostName: hostName,
        isHost: false,
        hostKeyHash: hostKeyHash,
        memberKeyHashes: [hostKeyHash, userId],
        groupIconHex: groupIconHex,
        maxMembers: maxMembers,
        joinedAt: DateTime.now(),
        groupSeed: groupSeed,
        laneSize: laneSize,
        totalGroupSize: totalSize,
        slotIndex: slotIndex,
      );
      contacts.add(newContact);
      final systemMsg = ChatMessage(
        id: DateTime.now().toString(),
        senderId: 'system',
        text: 'Joined group "$name". Connections secure.',
        timestamp: DateTime.now(),
        isSentByMe: false,
        decryptedText: 'Joined group "$name". Connections secure.',
      );
      messages[newContact.id] = [systemMsg];
      loadedChats.add(newContact.id);
      hasMoreOlder[newContact.id] = false;
      await WiltkeyDatabase.instance.upsertContact(newContact);
      await WiltkeyDatabase.instance.saveMessage(
        systemMsg,
        newContact.id,
        masterKeyHex: masterKeyHex,
      );
    }

    notifyListeners();
    _persistence.saveState(this);
    log(
      '[Group Spoke] Initialized group contact for: $name ($groupId) in slot $slotIndex',
    );
  }

  /// Called on the Host after a new member completes the BLE handshake. Assigns
  /// the lane, stores the member's profile, rebuilds + persists the host contact
  /// (so the member list survives restarts) and broadcasts fresh metadata to
  /// everyone — including the newcomer.
  Future<void> hostRegisterMember({
    required String groupId,
    required String peerId,
    required String peerName,
    required String peerProfileImage,
    required int slotIndex,
  }) async {
    await GroupDatabase.instance.assignLaneToMember(groupId, slotIndex, peerId);
    await upsertGroupProfileMerged(
      groupId: groupId,
      memberKeyHash: peerId,
      name: peerName,
      profileImage: peerProfileImage,
      arrivalOrder: slotIndex,
    );

    final idx = contacts.indexWhere((c) => c.isGroup && c.keyHash == groupId);
    if (idx == -1) {
      log('[Group Host Error] hostRegisterMember: group $groupId not found.');
      return;
    }
    final existing = contacts[idx];
    final newHashes = List<String>.from(existing.memberKeyHashes);
    if (!newHashes.contains(userId)) newHashes.add(userId);
    if (!newHashes.contains(peerId)) newHashes.add(peerId);

    final updated = existing.copyWith(
      memberKeyHashes: newHashes,
      memberCount: newHashes.length,
      lastActivity: DateTime.now(),
    );
    contacts[idx] = updated;
    if (activeContact?.keyHash == groupId) activeContact = updated;
    await WiltkeyDatabase.instance.upsertContact(updated);

    final sysMsg = ChatMessage(
      id: DateTime.now().toString(),
      senderId: 'system',
      text: '$peerName joined the group.',
      timestamp: DateTime.now(),
      isSentByMe: false,
      decryptedText: '$peerName joined the group.',
    );
    appendLoadedMessage(updated.id, sysMsg);
    await WiltkeyDatabase.instance.saveMessage(
      sysMsg,
      updated.id,
      masterKeyHex: masterKeyHex,
    );

    updateGroupMembersMetadata(updated);
    notifyListeners();
    _persistence.saveState(this);

    log(
      '[Group Host] Registered member $peerName ($peerId) at slot $slotIndex. Members: ${newHashes.length}',
    );

    await ensureWebSocketConnected();
    await broadcastGroupMetadataUpdate(updated);
  }

  Future<void> requestManualGroupSync(
    Contact contact,
    String targetMemberKeyHash,
  ) async {
    await ensureWebSocketConnected();
    log('[Manual Sync] Requesting full group sync from $targetMemberKeyHash');
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': targetMemberKeyHash,
      'envelope': jsonEncode({
        'group_id': contact.keyHash,
        'start_offset': 0,
        'end_offset': contact.totalGroupSize ?? (1024 * 1024 * 20),
      }),
      'content_type': 'chat_resync_request',
    });
  }
}
