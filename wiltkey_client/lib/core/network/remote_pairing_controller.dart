// TEMPORARY — remove after Google Play production approval (see kRemotePairingTesting).
//
// Debug-only remote pairing: instead of the in-person BLE handshake, two testers
// agree a pad over the relay by exchanging their ed25519 public keys keyed by a
// 6-digit PIN. Each side derives the SAME seed = sha256(sorted(pubA+pubB)) — the
// exact derivation the BLE path uses — so the resulting contact is byte-identical
// to a proximity pair. The joiner additionally pastes the host's identity hash;
// verifying sha256(hostPub) == that hash is the only defense against a relay that
// swaps keys mid-handshake, so it is mandatory.
//
// The whole feature is a thin wrapper around the existing, public
// [AppState.addOrRechargeContact]; there is intentionally no BLE-manager coupling.
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../state.dart';
import '../models.dart';
import '../db/wiltkey_db.dart';
import 'pairing_service.dart';

/// Every remote pad is a fixed 20 MB in this test path — no tier picker.
const int kDebugRemotePadBytes = 20 * 1024 * 1024;

enum RemotePairPhase { idle, hosting, joining, generating, success, error }

class RemotePairingController extends ChangeNotifier {
  final AppState appState = AppState();

  RemotePairPhase phase = RemotePairPhase.idle;

  /// The PIN we (the host) are advertising, or null when not hosting.
  String? pin;

  /// A human status line for the current phase.
  String status = '';

  /// Populated when [phase] is error.
  String? error;

  /// 0..1 keystream-generation progress (only meaningful while generating).
  double padProgress = 0;

  /// The contact created on success (for a "go to chat" affordance).
  Contact? result;

  Timer? _pollTimer;
  bool _disposed = false;

  /// Non-null puts the host side into GROUP-invite mode: instead of building a
  /// 1-on-1 contact when a joiner arrives, we assign them a group lane and hand
  /// over the (pairwise-encrypted) group seed via the invite endpoint.
  Contact? groupToInvite;

  /// Our own identity hash — the string the host reads out alongside the PIN.
  String get myHash => appState.userId;

  bool get busy =>
      phase == RemotePairPhase.hosting ||
      phase == RemotePairPhase.joining ||
      phase == RemotePairPhase.generating;

  String get _relay => appState.activeRelayUrl;

  // ---- Host side -----------------------------------------------------------

  /// Host a GROUP invite: same PIN/poll dance as [startHosting], but when a
  /// joiner arrives we assign them a lane in [group] and send the group seed.
  Future<void> startHostingGroup(Contact group) async {
    groupToInvite = group;
    await startHosting();
  }

  /// Register our pubkey under a fresh PIN and start polling for a joiner.
  Future<void> startHosting() async {
    if (busy) return;
    _clearError();
    phase = RemotePairPhase.hosting;
    status = 'Requesting PIN…';
    pin = null;
    notifyListeners();

    try {
      final init = await PairingService.pairInit(
        _relay,
        initiatorId: appState.userId,
        pubkey: appState.publicKeyHex,
        bufferBytes: kDebugRemotePadBytes,
      );
      if (_disposed) return;
      pin = init.pin;
      status = 'Share your hash + PIN, then keep this screen open…';
      notifyListeners();
      _startPolling();
    } catch (e) {
      _fail('Could not start hosting: $e');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_disposed || phase != RemotePairPhase.hosting || pin == null) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final poll = await PairingService.pairPoll(
          _relay,
          pin: pin!,
          initiatorId: appState.userId,
        );
        if (_disposed || phase != RemotePairPhase.hosting) return;
        if (poll.status == 'joined' &&
            poll.receiverPub != null &&
            poll.receiverId != null) {
          _pollTimer?.cancel();
          // Integrity: the relay-reported id must be the hash of the pubkey it
          // handed us, or addressing would silently break.
          if (_hashOfPub(poll.receiverPub!) != poll.receiverId) {
            _fail('Peer identity mismatch — aborted.');
            return;
          }
          if (groupToInvite != null) {
            await _finalizeHostGroup(poll.receiverId!, poll.receiverPub!);
          } else {
            await _pairWith(
              peerId: poll.receiverId!,
              peerPub: poll.receiverPub!,
              bufferBytes: kDebugRemotePadBytes,
            );
          }
        } else if (poll.status == 'expired') {
          _pollTimer?.cancel();
          _fail('PIN expired before anyone joined. Try again.');
        }
      } catch (e) {
        // A transient network blip shouldn't kill the session — keep polling.
        debugPrint('[RemotePair] poll error (will retry): $e');
      }
    });
  }

  // ---- Joiner side ---------------------------------------------------------

  /// Submit against [enteredPin], verify the host's identity against
  /// [expectedHostHash] (pasted by the user), then build the contact.
  Future<void> join(String enteredPin, String expectedHostHash) async {
    if (busy) return;
    final p = enteredPin.trim();
    final h = expectedHostHash.trim().toLowerCase();
    if (p.length != 6 || int.tryParse(p) == null) {
      _fail('PIN must be 6 digits.');
      return;
    }
    if (h.length != 64) {
      _fail('Peer hash must be the full 64-character identity hash.');
      return;
    }
    _clearError();
    phase = RemotePairPhase.joining;
    status = 'Contacting host…';
    notifyListeners();

    try {
      final joinRes = await PairingService.pairJoin(
        _relay,
        pin: p,
        receiverId: appState.userId,
        pubkey: appState.publicKeyHex,
      );
      if (_disposed) return;
      // The MITM check: the pubkey the relay handed back MUST hash to the hash
      // the user pasted out-of-band. If not, a relay swapped keys — abort.
      if (_hashOfPub(joinRes.initiatorPub) != h) {
        _fail(
          'Host identity did not match the pasted hash — pairing aborted '
          '(possible relay tampering).',
        );
        return;
      }
      final bufferBytes = joinRes.bufferBytes > 0
          ? joinRes.bufferBytes
          : kDebugRemotePadBytes;
      await _pairWith(
        peerId: joinRes.initiatorId,
        peerPub: joinRes.initiatorPub,
        bufferBytes: bufferBytes,
      );
    } catch (e) {
      _fail('Join failed: $e');
    }
  }

  // ---- Shared finalize -----------------------------------------------------

  Future<void> _pairWith({
    required String peerId,
    required String peerPub,
    required int bufferBytes,
  }) async {
    phase = RemotePairPhase.generating;
    padProgress = 0;
    status = 'Generating ${AppState.formatBytes(bufferBytes)} pad…';
    notifyListeners();

    // Same seed derivation as the BLE handshake (sorted concat of both pubkeys).
    final pair = [appState.publicKeyHex, peerPub]..sort();
    final derivedSeed = sha256
        .convert(utf8.encode(pair[0] + pair[1]))
        .toString();

    // Placeholder name until the peer's real profile lands over the encrypted
    // meta channel (fired below); the contact is never blank, just terse.
    final placeholder = 'Contact ${peerId.substring(0, 6)}';

    try {
      await appState.addOrRechargeContact(
        placeholder,
        _relay,
        bufferBytes,
        peerId,
        derivedSeed,
        onPadProgress: (written, total) {
          if (_disposed || total <= 0) return;
          padProgress = written / total;
          notifyListeners();
        },
      );
      if (_disposed) return;

      final contact = appState.contacts.firstWhere(
        (c) => c.keyHash == peerId,
        orElse: () => throw Exception('Contact vanished after pairing.'),
      );

      // Push OUR profile (name/nick/avatar) to the peer over the encrypted meta
      // channel; theirs arrives symmetrically and backfills the placeholder.
      await appState.sendChatInfoUpdate(contact);

      result = contact;
      phase = RemotePairPhase.success;
      status = 'Paired. You can now chat.';
      pin = null;
      notifyListeners();
    } catch (e) {
      _fail('Pad generation failed: $e');
    }
  }

  // ---- Group invite: host finalize ----------------------------------------

  /// A joiner arrived for a group invite. Assign them a lane, encrypt the group
  /// seed with the pairwise seed, and hand the whole invite to them via the
  /// relay's invite endpoint. Registers the member locally ONLY after the upload
  /// succeeds — a phantom lane the joiner never receives would corrupt the group.
  Future<void> _finalizeHostGroup(String joinerId, String joinerPub) async {
    final group = groupToInvite!;
    // Guard the seed BEFORE we advertise anything: encrypting an empty/null seed
    // would hand the joiner a garbage keystream — a silently broken group. Fail
    // cleanly instead (the host never posts, the joiner times out on its poll).
    final groupSeed = group.groupSeed ?? '';
    if (groupSeed.isEmpty) {
      _fail('Group seed unavailable — reopen the group and try again.');
      return;
    }
    phase = RemotePairPhase.generating;
    status = 'Adding member…';
    notifyListeners();

    final pairwise = _pairwiseSeed(joinerPub);

    try {
      // Re-meet reuses the joiner's existing slot (Time Wilt time-refresh), so a
      // full group only blocks brand-new joiners.
      final existingLane = await GroupDatabase.instance.getLaneByMember(
        group.keyHash,
        joinerId,
      );
      int? slot = existingLane?['slot_index'] as int?;
      if (slot == null) {
        final emptyLanes = await GroupDatabase.instance.getEmptyLanes(
          group.keyHash,
        );
        if (emptyLanes.isEmpty) {
          // Tell the joiner rather than leaving them polling: post an error blob.
          await PairingService.pairInviteUpload(
            _relay,
            pin: pin!,
            initiatorId: appState.userId,
            blob: jsonEncode({'error': 'group_full'}),
          );
          _fail('Group is full — no free slots.');
          return;
        }
        slot = emptyLanes.first['slot_index'] as int;
      }

      final blob = jsonEncode({
        'group_id': group.keyHash,
        'group_name': group.name,
        // Only the SEED is encrypted (pairwise) — the rest is plain metadata,
        // exactly as the BLE group-invite GATT payload carries it.
        'group_seed_encrypted': _encryptGroupSeed(group.groupSeed ?? '', pairwise),
        'lane_size': group.laneSize,
        'total_size': group.totalGroupSize,
        'slot_index': slot,
        'host_name': appState.effectiveDeviceName,
        'host_short_nick': appState.effectiveShortNick,
        'group_icon': group.groupIconHex,
        'max_members': group.maxMembers,
        // Group Time Wilt lifetime (seconds); null for byte-budget groups.
        'group_wilt_lifetime': group.groupWiltLifetimeSecs,
      });

      await PairingService.pairInviteUpload(
        _relay,
        pin: pin!,
        initiatorId: appState.userId,
        blob: blob,
      );

      // Upload succeeded — now it's safe to claim the lane locally.
      await appState.hostRegisterMember(
        groupId: group.keyHash,
        peerId: joinerId,
        peerName: 'Member ${joinerId.substring(0, 6)}',
        peerProfileImage: '',
        slotIndex: slot,
      );

      result = group;
      phase = RemotePairPhase.success;
      status = 'Member added to ${group.name}.';
      pin = null;
      notifyListeners();
    } catch (e) {
      _fail('Failed to send group invite: $e');
    }
  }

  // ---- Group invite: joiner ------------------------------------------------

  /// Join a remote group: exchange pubkeys with the host (verifying its identity
  /// against the pasted hash), then poll the invite endpoint for the encrypted
  /// group seed and build the group contact.
  Future<void> joinGroup(String enteredPin, String expectedHostHash) async {
    if (busy) return;
    final p = enteredPin.trim();
    final h = expectedHostHash.trim().toLowerCase();
    if (p.length != 6 || int.tryParse(p) == null) {
      _fail('PIN must be 6 digits.');
      return;
    }
    if (h.length != 64) {
      _fail('Host hash must be the full 64-character identity hash.');
      return;
    }
    _clearError();
    phase = RemotePairPhase.joining;
    status = 'Contacting host…';
    notifyListeners();

    try {
      final joinRes = await PairingService.pairJoin(
        _relay,
        pin: p,
        receiverId: appState.userId,
        pubkey: appState.publicKeyHex,
      );
      if (_disposed) return;
      if (_hashOfPub(joinRes.initiatorPub) != h) {
        _fail(
          'Host identity did not match the pasted hash — aborted (possible '
          'relay tampering).',
        );
        return;
      }
      final pairwise = _pairwiseSeed(joinRes.initiatorPub);

      status = 'Waiting for the host to send the invite…';
      notifyListeners();
      final blob = await _pollForInvite(p);
      if (blob == null) return; // _pollForInvite already set the error/phase

      final meta = jsonDecode(blob) as Map<String, dynamic>;
      if (meta['error'] == 'group_full') {
        _fail('The group is full.');
        return;
      }

      phase = RemotePairPhase.generating;
      status = 'Joining group…';
      notifyListeners();

      final groupSeed = _decryptGroupSeed(
        meta['group_seed_encrypted'] as String,
        pairwise,
      );

      await appState.addOrRechargeGroupContact(
        name: meta['group_name'] as String,
        relayUrl: _relay,
        totalSize: (meta['total_size'] as num).toInt(),
        laneSize: (meta['lane_size'] as num).toInt(),
        groupId: meta['group_id'] as String,
        groupSeed: groupSeed,
        slotIndex: (meta['slot_index'] as num).toInt(),
        // Use the VERIFIED host hash, never a value from the blob — otherwise a
        // tampered blob could point group routing at the wrong host.
        hostKeyHash: h,
        hostName: (meta['host_name'] as String?) ?? 'Host',
        groupIconHex: meta['group_icon'] as String?,
        maxMembers: (meta['max_members'] as num?)?.toInt(),
        wiltLifetimeSecs: (meta['group_wilt_lifetime'] as num?)?.toInt(),
      );
      if (_disposed) return;

      final contact = appState.contacts.firstWhere(
        (c) => c.keyHash == meta['group_id'],
        orElse: () => throw Exception('Group vanished after joining.'),
      );
      appState.requestGroupMetadata(contact);

      result = contact;
      phase = RemotePairPhase.success;
      status = 'Joined ${contact.name}.';
      notifyListeners();
    } catch (e) {
      _fail('Join failed: $e');
    }
  }

  /// Poll the invite endpoint until the host posts the blob, it expires, or we
  /// give up. Returns the blob, or null after setting an error phase.
  Future<String?> _pollForInvite(String p) async {
    // Host TTL after posting is 5 min; poll well within that.
    const maxAttempts = 90; // ~3 min at 2s
    for (int i = 0; i < maxAttempts; i++) {
      if (_disposed || phase != RemotePairPhase.joining) return null;
      final res = await PairingService.pairInviteFetch(
        _relay,
        pin: p,
        receiverId: appState.userId,
      );
      if (res.status == 'ready' && (res.blob?.isNotEmpty ?? false)) {
        return res.blob;
      }
      if (res.status == 'expired') {
        _fail('The invite expired before it arrived. Ask the host to retry.');
        return null;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    _fail('Timed out waiting for the host to send the invite.');
    return null;
  }

  String _pairwiseSeed(String peerPub) {
    final pair = [appState.publicKeyHex, peerPub]..sort();
    return sha256.convert(utf8.encode(pair[0] + pair[1])).toString();
  }

  // XOR the group seed with SHA256(pairwiseSeed) — byte-for-byte the same scheme
  // as BlePairingManager, so a remote-invited member is identical to a BLE one.
  String _encryptGroupSeed(String groupSeedHex, String pairwiseSeed) {
    final seed = _hexToBytes(groupSeedHex);
    final key = sha256.convert(utf8.encode(pairwiseSeed)).bytes;
    final out = List<int>.generate(
      seed.length,
      (i) => seed[i] ^ key[i % key.length],
    );
    return _bytesToHex(out);
  }

  String _decryptGroupSeed(String encHex, String pairwiseSeed) =>
      _encryptGroupSeed(encHex, pairwiseSeed); // XOR is symmetric

  String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  // ---- Lifecycle -----------------------------------------------------------

  void reset() {
    _pollTimer?.cancel();
    groupToInvite = null;
    phase = RemotePairPhase.idle;
    pin = null;
    status = '';
    error = null;
    padProgress = 0;
    result = null;
    notifyListeners();
  }

  void _clearError() {
    error = null;
  }

  void _fail(String message) {
    if (_disposed) return;
    _pollTimer?.cancel();
    error = message;
    status = message;
    phase = RemotePairPhase.error;
    notifyListeners();
  }

  String _hashOfPub(String pubHex) =>
      sha256.convert(_hexToBytes(pubHex)).toString();

  List<int> _hexToBytes(String hex) {
    final out = <int>[];
    for (int i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}
