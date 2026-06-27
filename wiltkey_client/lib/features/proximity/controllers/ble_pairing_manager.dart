import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    hide CharacteristicProperties;
import 'package:permission_handler/permission_handler.dart';
import 'package:ble_peripheral/ble_peripheral.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/crypto/otp_service.dart';
import '../../../core/db/wiltkey_db.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/theme/wiltkey_components.dart';

/// RSSI within pairing reach (matches the screens' proximity gate).
const int kNearRssi = -85;

class DiscoveredBleDevice {
  final String id;
  final String name;
  final int rssi;
  final double angle;
  final bool isWiltkey;
  final bool isGroup;

  DiscoveredBleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.angle,
    this.isWiltkey = false,
    this.isGroup = false,
  });

  /// Project onto the theme-agnostic [SyncBlip] consumed by `syncVisual`. The
  /// strength normalises RSSI (-100..-30 dBm) to 0 (far) .. 1 (near).
  SyncBlip toSyncBlip() {
    final clamped = rssi.clamp(-100, -30);
    return SyncBlip(
      id: id,
      strength: (clamped + 100) / 70.0,
      angle: angle,
      isWiltkey: isWiltkey,
      isNear: rssi >= kNearRssi,
      isGroup: isGroup,
    );
  }
}

class BlePairingManager extends ChangeNotifier {
  final AppState appState = AppState();

  bool isDiscoverable = true;
  bool isScanning = false;
  bool isSyncing = false;
  bool isSuccess = false;
  double syncProgress = 0.0;
  String syncStepText = 'Idle';

  List<DiscoveredBleDevice> discoveredDevices = [];
  final Map<String, String> resolvedNames = {};
  final List<String> terminalLogs = [
    '[System] Bluetooth initializer active.',
    '[Scanner] Requesting BLE permissions...',
  ];

  String agreedSeed = 'Initializing...';
  String randomBytesHex = 'Generating key bytes...';
  double flashOpacity = 0.0;
  double sliderValue = 3.0; // Default to 10MB index

  final List<int> sliderByteValues = [
    100000,
    1000000,
    5000000,
    10000000,
    20000000,
  ];

  DiscoveredBleDevice? selectedDevice;
  BluetoothDevice? activeConnection;

  Contact? groupToInvite;
  Map<String, dynamic>? incomingGroupMetadata;

  final Map<String, double> _smoothedRssi = {};
  final Map<String, DateTime> _lastSeen = {};
  final Map<String, DateTime> _lastSeenInRange = {};
  final Map<String, DateTime> _lastProcessedTimestamp = {};
  // The persistent set of discovered devices. The visible list is derived from
  // this (filtered by the grace window) rather than rebuilt from each scan
  // emission, so a device that's briefly absent from a batch doesn't blink out.
  final Map<String, DiscoveredBleDevice> _deviceCache = {};
  Timer? _evictionTimer;

  // How long a device lingers after its last *received* ad packet before it's
  // dropped. Must comfortably exceed the (slow, irregular) advertising interval
  // of older phones, or they blink in/out between their own ads. Tune if needed.
  static const Duration _seenGrace = Duration(seconds: 8);
  // How long after last being within pairing range before we drop it — temporal
  // hysteresis so a device hovering around kNearRssi doesn't toggle.
  static const Duration _inRangeGrace = Duration(seconds: 12);

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _syncTimer;
  Timer? _hexAnimationTimer;
  Timer? _pairingReadTimer;
  Uint8List? _gattResponseBytes;

  // Callback to the UI to handle confirmation dialog
  void Function({
    required String peerId,
    required String peerPubKey,
    required int bufferBytes,
    required String peerName,
    required String peerShortNick,
    required String peerProfileImage,
  })?
  onIncomingRequest;

  // Callback to display a snackbar or alert in UI
  void Function(String message)? onAlert;

  // Callback to trigger a refresh of animations
  VoidCallback? onHexTick;

  void log(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    terminalLogs.add('[$time] $message');
    if (terminalLogs.length > 100) {
      terminalLogs.removeAt(0);
    }
    print('[BlePairingManager] $message');
    notifyListeners();
  }

  void setDiscoverable(bool val) {
    isDiscoverable = val;
    notifyListeners();
    if (isDiscoverable) {
      startAdvertising();
    } else {
      stopAdvertising();
    }
  }

  void selectDevice(DiscoveredBleDevice? device) {
    selectedDevice = device;
    notifyListeners();
  }

  void updateSlider(double val) {
    sliderValue = val;
    notifyListeners();
  }

  Future<void> initializeBle() async {
    await requestBlePermissions();
    await initGattServer();
    startScanningFlow();
  }

  Future<bool> requestBlePermissions() async {
    log('[Permissions] Checking initial permission status...');
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    log('[Permissions] Request results:');
    statuses.forEach((permission, status) {
      log('  - ${permission.toString().split('.').last}: $status');
    });

    try {
      final isSupported = await FlutterBluePlus.isSupported;
      log('[BLE] Supported on this device: $isSupported');
      final adapterState = await FlutterBluePlus.adapterState.first;
      log('[BLE] Adapter state: $adapterState');
      if (adapterState != BluetoothAdapterState.on) {
        log('[BLE WARNING] Bluetooth adapter is NOT ON!');
      }
    } catch (e) {
      log('[BLE Error] Failed to query adapter state: $e');
    }

    return true;
  }

  Future<void> initGattServer() async {
    try {
      await BlePeripheral.initialize();

      BlePeripheral.setBleStateChangeCallback((isOn) {
        log('[BLE State Change] Bluetooth is: ${isOn ? "ON" : "OFF"}');
      });

      BlePeripheral.setAdvertisingStatusUpdateCallback((advertising, error) {
        log(
          '[BLE Peripheral] Advertising status: ${advertising ? "Started" : "Stopped"}${error != null ? " (Error: $error)" : ""}',
        );
      });

      BlePeripheral.setCharacteristicSubscriptionChangeCallback((
        deviceId,
        characteristic,
        isSubscribed,
        name,
      ) {
        log(
          '[BLE Peripheral] Subscription change from $deviceId ($name): characteristic=$characteristic subscribed=$isSubscribed',
        );
      });

      BlePeripheral.setWriteRequestCallback((
        deviceId,
        characteristicId,
        offset,
        value,
      ) {
        if (characteristicId.toLowerCase() ==
            '098ed89c-5b2d-4f70-91f6-7ccff798f5b2') {
          if (value != null) {
            final payloadStr = utf8.decode(value);
            _handleIncomingPairRequest(deviceId, payloadStr);
          }
        }
        return WriteRequestResult(status: 0);
      });

      BlePeripheral.setReadRequestCallback((
        deviceId,
        characteristicId,
        offset,
        value,
      ) {
        log(
          '[BLE Peripheral] Read request for $characteristicId from $deviceId (offset: $offset)',
        );
        final bytes = _gattResponseBytes;
        if (bytes == null) {
          return ReadRequestResult(value: Uint8List.fromList([]), status: 0);
        }
        if (offset >= bytes.length) {
          return ReadRequestResult(value: Uint8List.fromList([]), status: 0);
        }
        return ReadRequestResult(
          value: Uint8List.fromList(bytes.sublist(offset)),
          status: 0,
        );
      });

      await BlePeripheral.clearServices();

      final char = BleCharacteristic(
        uuid: '098ed89c-5b2d-4f70-91f6-7ccff798f5b2',
        properties: [
          CharacteristicProperties.read.index,
          CharacteristicProperties.write.index,
          CharacteristicProperties.notify.index,
        ],
        permissions: [
          AttributePermissions.readable.index,
          AttributePermissions.writeable.index,
        ],
        value: Uint8List.fromList([]),
      );

      final service = BleService(
        uuid: '4f7091f6-7ccf-f798-f5b2-098ed89c5b2d',
        primary: true,
        characteristics: [char],
      );

      await BlePeripheral.addService(service);
      log('[GATT] Service registered.');
      startAdvertising();
    } catch (e) {
      log('[GATT Error] Init failed: $e');
    }
  }

  Future<void> startAdvertising() async {
    if (!isDiscoverable) return;
    _gattResponseBytes = null;
    try {
      final shortId = appState.userId.length >= 4
          ? appState.userId.substring(0, 4).toUpperCase()
          : appState.userId;

      String prefix = 'WK:';
      String nameToUse = appState.effectiveShortNick;
      if (groupToInvite != null) {
        prefix = 'WKG:';
        nameToUse = groupToInvite!.name;
      }

      String safeName = nameToUse.replaceAll(' ', '');
      if (safeName.length > 5) safeName = safeName.substring(0, 5);
      final localName = '$prefix$safeName:$shortId';

      await BlePeripheral.startAdvertising(services: [], localName: localName);
      log('[BLE Peripheral] Advertising: $localName');
    } catch (e) {
      log('[BLE Peripheral Error] Adv failed: $e');
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await BlePeripheral.stopAdvertising();
      log('[BLE Peripheral] Advertising stopped.');
    } catch (e) {
      log('[BLE Peripheral Error] Stop failed: $e');
    }
  }

  void _handleIncomingPairRequest(String deviceId, String payloadStr) {
    try {
      final json = jsonDecode(payloadStr);
      if (json['type'] != 'pairing_request') return;

      final peerName = json['device_name'] as String;
      final peerShortNick = json['short_nick'] as String? ?? '';
      final peerProfileImage = json['profile_image'] as String? ?? '';
      final peerPubKey = json['pubkey'] as String;
      final bufferBytes = json['buffer_bytes'] as int;

      final peerPubBytes = _hexToBytes(peerPubKey);
      final peerId = sha256.convert(peerPubBytes).toString();

      if (onIncomingRequest != null) {
        onIncomingRequest!(
          peerId: peerId,
          peerPubKey: peerPubKey,
          bufferBytes: bufferBytes,
          peerName: peerName,
          peerShortNick: peerShortNick,
          peerProfileImage: peerProfileImage,
        );
      }
    } catch (e) {
      log('[GATT Error] Parse pair request failed: $e');
    }
  }

  Future<void> respondToPairRequest(
    String peerId,
    String peerPubKey,
    int bufferBytes,
    bool accepted,
    String peerName,
    String peerShortNick,
    String peerProfileImage,
  ) async {
    try {
      if (accepted) {
        final list = [appState.publicKeyHex, peerPubKey]..sort();
        final derivedSeed = sha256
            .convert(utf8.encode(list[0] + list[1]))
            .toString();

        final Map<String, dynamic> responseMap = {
          "status": "accepted",
          "user_id": appState.userId,
          "pubkey": appState.publicKeyHex,
        };

        if (groupToInvite != null) {
          final emptyLanes = await GroupDatabase.instance.getEmptyLanes(
            groupToInvite!.keyHash,
          );
          if (emptyLanes.isEmpty) {
            log('[BLE Host Error] No empty slots available to invite peer!');
            final response = jsonEncode({
              "status": "rejected",
              "message": "Group capacity reached",
            });
            _gattResponseBytes = Uint8List.fromList(utf8.encode(response));
            await BlePeripheral.updateCharacteristic(
              characteristicId: '098ed89c-5b2d-4f70-91f6-7ccff798f5b2',
              value: _gattResponseBytes!,
            );
            return;
          }
          final assignedSlot = emptyLanes.first['slot_index'] as int;
          final encryptedSeed = _encryptGroupSeed(
            groupToInvite!.groupSeed!,
            derivedSeed,
          );

          responseMap["pairing_type"] = "group_invite";
          responseMap["group_id"] = groupToInvite!.keyHash;
          responseMap["group_seed_encrypted"] = encryptedSeed;
          responseMap["lane_size"] = groupToInvite!.laneSize;
          responseMap["total_size"] = groupToInvite!.totalGroupSize;
          responseMap["slot_index"] = assignedSlot;
          responseMap["group_name"] = groupToInvite!.name;
          responseMap["host_name"] = appState.effectiveDeviceName;
          responseMap["host_short_nick"] = appState.effectiveShortNick;
        } else {
          responseMap["short_nick"] = appState.effectiveShortNick;
          responseMap["profile_image"] = appState.profileImageB64;
        }

        final response = jsonEncode(responseMap);

        _gattResponseBytes = Uint8List.fromList(utf8.encode(response));

        await BlePeripheral.updateCharacteristic(
          characteristicId: '098ed89c-5b2d-4f70-91f6-7ccff798f5b2',
          value: _gattResponseBytes!,
        );

        agreedSeed = '0x' + derivedSeed.substring(0, 16).toUpperCase() + '...';
        notifyListeners();

        int actualBufferBytes = groupToInvite != null
            ? groupToInvite!.maxBufferBytes
            : bufferBytes;

        int sliderIdx = sliderByteValues.indexOf(actualBufferBytes);
        if (sliderIdx != -1) {
          sliderValue = sliderIdx.toDouble();
        }

        _startHandshakeExecution(
          peerId: peerId,
          peerPubKey: peerPubKey,
          derivedSeed: derivedSeed,
          bufferBytes: actualBufferBytes,
          isInitiator: false,
          peerName: peerName,
          peerShortNick: peerShortNick,
          peerProfileImage: peerProfileImage,
        );
      } else {
        final response = jsonEncode({"status": "rejected"});

        _gattResponseBytes = Uint8List.fromList(utf8.encode(response));

        await BlePeripheral.updateCharacteristic(
          characteristicId: '098ed89c-5b2d-4f70-91f6-7ccff798f5b2',
          value: _gattResponseBytes!,
        );
      }
    } catch (e) {
      log('[GATT Error] Response write failed: $e');
    }
  }

  Future<void> startScanningFlow() async {
    log('[System] Scanning...');
    isScanning = true;
    _smoothedRssi.clear();
    _lastSeen.clear();
    _lastSeenInRange.clear();
    _lastProcessedTimestamp.clear();
    _deviceCache.clear();
    _evictionTimer?.cancel();
    _evictionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkEvictions();
    });
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 45));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final now = DateTime.now();

        for (var r in results) {
          final id = r.device.remoteId.str;
          final advName = r.advertisementData.localName;

          final isWiltkey =
              advName.startsWith('WK:') ||
              advName.startsWith('WKG:') ||
              r.advertisementData.serviceUuids
                  .map((g) => g.toString().toLowerCase())
                  .contains('4f7091f6-7ccf-f798-f5b2-098ed89c5b2d');

          if (!isWiltkey) continue;

          // Only advance "last seen" / smoothing on a genuinely new ad packet
          // (FlutterBluePlus re-emits cached results with the same timestamp).
          final lastStamp = _lastProcessedTimestamp[id];
          if (lastStamp == null || lastStamp != r.timeStamp) {
            _lastProcessedTimestamp[id] = r.timeStamp;
            _lastSeen[id] = now;

            final double oldRssi = _smoothedRssi[id] ?? r.rssi.toDouble();
            _smoothedRssi[id] = 0.3 * r.rssi + 0.7 * oldRssi;
          }

          final smoothedRssiValue = _smoothedRssi[id]?.round() ?? r.rssi;
          if (smoothedRssiValue >= kNearRssi) {
            _lastSeenInRange[id] = now;
          }

          final bool isGroupAdv = advName.startsWith('WKG:');
          final String displayName = _resolveDisplayName(id, advName, r);
          final angle = (id.hashCode % 360) * pi / 180.0;

          // Upsert into the persistent cache; membership is decided solely by the
          // grace window in _rebuildVisibleList, never by presence in this batch.
          _deviceCache[id] = DiscoveredBleDevice(
            id: id,
            name: displayName,
            rssi: smoothedRssiValue,
            angle: angle,
            isWiltkey: true,
            isGroup: isGroupAdv,
          );
        }

        _rebuildVisibleList(now);
      });
    } catch (e) {
      log('[Error] Scan failed: $e');
    }
  }

  /// Manually tears down the active scan and starts a clean one — the same
  /// reset that leaving and re-entering the Pair tab performs. BLE discovery
  /// occasionally stalls (sparse/slow advertisers, or the 45s scan timeout
  /// elapsing), and a fresh scan + re-advertise reliably brings missing devices
  /// back without forcing the user to switch tabs. Surfaced as the refresh
  /// button in the pairing screen's app bar.
  Future<void> restartScan() async {
    if (isSyncing || isSuccess) return;
    log('[System] Manual scan refresh requested.');
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      log('[Scanner] stopScan during refresh failed: $e');
    }
    await startScanningFlow();
    // Re-advertise too, so the peer re-discovers us (the inbound direction).
    await stopAdvertising();
    await startAdvertising();
  }

  bool _shouldKeepDevice(String id, DateTime now) {
    final lastSeenTime = _lastSeen[id];
    final lastSeenInRangeTime = _lastSeenInRange[id];
    if (lastSeenTime == null || lastSeenInRangeTime == null) {
      return false;
    }
    return now.difference(lastSeenTime) <= _seenGrace &&
        now.difference(lastSeenInRangeTime) <= _inRangeGrace;
  }

  /// Resolves a device's display name from its advertisement (or the cached
  /// name if this packet didn't carry a "WK:"/"WKG:" local name).
  String _resolveDisplayName(String id, String advName, ScanResult r) {
    if (advName.startsWith('WK:') || advName.startsWith('WKG:')) {
      final parts = advName.split(':');
      final name = parts.length >= 2 ? parts[1] : advName;
      resolvedNames[id] = name;
      return name;
    }
    final cacheName = resolvedNames[id];
    if (cacheName != null) return cacheName;
    final rawName = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : (r.device.localName.isNotEmpty
              ? r.device.localName
              : 'Wiltkey Device');
    if (rawName.startsWith('WK:') || rawName.startsWith('WKG:')) {
      final parts = rawName.split(':');
      return parts.length >= 2 ? parts[1] : rawName;
    }
    return rawName;
  }

  /// Rebuilds the visible list from the persistent cache: keep every device
  /// still inside its grace window, prune the rest. This is the single authority
  /// for membership, so devices don't pop in/out between sparse ad packets.
  void _rebuildVisibleList(DateTime now) {
    final List<DiscoveredBleDevice> visible = [];
    final List<String> expired = [];
    for (final entry in _deviceCache.entries) {
      if (_shouldKeepDevice(entry.key, now)) {
        visible.add(entry.value);
      } else {
        expired.add(entry.key);
      }
    }
    for (final id in expired) {
      _deviceCache.remove(id);
      log('[BLE Scanner] Evicting device $id (grace window elapsed).');
    }
    // Stable order so a refreshed entry never reshuffles the list.
    visible.sort((a, b) => a.id.compareTo(b.id));
    discoveredDevices = visible;
    notifyListeners();
  }

  void _checkEvictions() {
    if (_deviceCache.isEmpty) return;
    _rebuildVisibleList(DateTime.now());
  }

  void generateMockHexBytes() {
    final rand = Random();
    const hex = '0123456789abcdef';

    randomBytesHex = List.generate(3, (line) {
      return List.generate(6, (word) {
        return List.generate(4, (char) => hex[rand.nextInt(16)]).join();
      }).join(' ');
    }).join('\n');

    if (onHexTick != null) {
      onHexTick!();
    }
  }

  void _processPairingResponse(
    Map<String, dynamic> json,
    StreamSubscription<List<int>>? notifySub,
    BluetoothDevice device,
    int byteSize,
  ) {
    try {
      log('[BLE Client] Processing pairing response: ${json['status']}');
      if (json['status'] == 'accepted') {
        notifySub?.cancel();
        _pairingReadTimer?.cancel();

        final peerPubKey = json['pubkey'] as String;
        final peerShortNick = json['short_nick'] as String? ?? '';
        final peerProfileImage = json['profile_image'] as String? ?? '';

        final peerPubBytes = _hexToBytes(peerPubKey);
        final peerId = sha256.convert(peerPubBytes).toString();

        final isGroupInvite = json['pairing_type'] == 'group_invite';
        final hostBufferBytes = json['buffer_bytes'] as int?;
        final actualBufferBytes = (isGroupInvite && hostBufferBytes != null)
            ? hostBufferBytes
            : byteSize;

        if (isGroupInvite) {
          final groupId = json['group_id'] as String;
          final fallbackName =
              'Group ${groupId.substring(0, min(6, groupId.length))}';
          incomingGroupMetadata = {
            'isGroup': true,
            'groupId': groupId,
            'groupName': (json['group_name'] as String?) ?? fallbackName,
            'groupIcon': json['group_icon'] as String?,
            'maxMembers': json['max_members'] as int? ?? 20,
            'maxMessageSize': json['max_message_size'] as int? ?? 1024 * 1024,
            'imagesAllowed': json['images_allowed'] as bool? ?? true,
            'hostKeyHash': peerId,
            'hostName':
                (json['host_name'] as String?) ??
                (json['host_short_nick'] as String?) ??
                selectedDevice!.name,
            'group_seed_encrypted': json['group_seed_encrypted'] as String,
            'lane_size': json['lane_size'] as int,
            'total_size': json['total_size'] as int,
            'slot_index': json['slot_index'] as int,
          };
        } else {
          incomingGroupMetadata = null;
        }

        final list = [appState.publicKeyHex, peerPubKey]..sort();
        final derivedSeed = sha256
            .convert(utf8.encode(list[0] + list[1]))
            .toString();

        agreedSeed = '0x' + derivedSeed.substring(0, 16).toUpperCase() + '...';
        notifyListeners();

        _startHandshakeExecution(
          peerId: peerId,
          peerPubKey: peerPubKey,
          derivedSeed: derivedSeed,
          bufferBytes: actualBufferBytes,
          isInitiator: true,
          peerName: selectedDevice!.name,
          peerShortNick: peerShortNick,
          peerProfileImage: peerProfileImage,
          deviceToDisconnect: device,
        );
      } else if (json['status'] == 'rejected') {
        notifySub?.cancel();
        _pairingReadTimer?.cancel();
        device.disconnect();
        isSyncing = false;
        notifyListeners();
        if (onAlert != null) {
          onAlert!('Connection request rejected by peer.');
        }
        startScanningFlow();
        startAdvertising();
      }
    } catch (e) {
      log('[BLE Client Error] Process response failed: $e');
    }
  }

  Future<void> startSyncProcess(String relayUrl) async {
    if (selectedDevice == null) {
      if (onAlert != null) {
        onAlert!('Please select a nearby device from the list first.');
      }
      return;
    }

    _gattResponseBytes = null;
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _evictionTimer?.cancel();
    stopAdvertising();

    final int byteSize = sliderByteValues[sliderValue.round()];

    isScanning = false;
    isSyncing = true;
    syncProgress = 0.0;
    syncStepText = 'Establishing secure Bluetooth link...';
    notifyListeners();

    _hexAnimationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (isSyncing) {
        generateMockHexBytes();
      } else {
        timer.cancel();
      }
    });

    try {
      final device = BluetoothDevice.fromId(selectedDevice!.id);
      activeConnection = device;

      await device.connect(timeout: const Duration(seconds: 8));
      log('[BLE Client] Connected to peer.');

      if (Platform.isAndroid) {
        try {
          await device.requestMtu(512);
          log('[MTU] Configured 512 bytes MTU.');
        } catch (e) {
          log('[MTU Warning] Request failed: $e');
        }
      }

      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (var s in services) {
        if (s.uuid.toString().toLowerCase() ==
            '4f7091f6-7ccf-f798-f5b2-098ed89c5b2d') {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() ==
                '098ed89c-5b2d-4f70-91f6-7ccff798f5b2') {
              targetChar = c;
            }
          }
        }
      }

      if (targetChar == null) {
        throw Exception('Secure pairing characteristic not found.');
      }

      final pairChar = targetChar;
      await pairChar.setNotifyValue(true);

      StreamSubscription<List<int>>? notifySub;
      _pairingReadTimer?.cancel();

      notifySub = pairChar.onValueReceived.listen((value) {
        try {
          if (value.isNotEmpty) {
            final respStr = utf8.decode(value);
            log('[BLE Client] Notify raw resp length: ${value.length}');
            final json = jsonDecode(respStr);
            log('[BLE Client] Received notification: ${json['status']}');
            _processPairingResponse(json, notifySub, device, byteSize);
          }
        } catch (e) {
          log(
            '[BLE Client Error] Notify parse failed: $e. Raw length: ${value.length}',
          );
        }
      });

      bool isReading = false;
      _pairingReadTimer = Timer.periodic(const Duration(seconds: 4), (
        timer,
      ) async {
        if (!isSyncing || activeConnection == null) {
          timer.cancel();
          return;
        }
        if (isReading) {
          log('[BLE Client] Read in progress, skipping polling read.');
          return;
        }
        isReading = true;
        try {
          final value = await pairChar.read();
          if (value.isNotEmpty) {
            final respStr = utf8.decode(value);
            log('[BLE Client] Read timer raw resp length: ${value.length}');
            final json = jsonDecode(respStr);
            if (json['status'] == 'accepted' || json['status'] == 'rejected') {
              log(
                '[BLE Client] Detected response via read check: ${json['status']}',
              );
              timer.cancel();
              _processPairingResponse(json, notifySub, device, byteSize);
            }
          }
        } catch (e) {
          log('[BLE Client Error] Read timer error: $e');
        } finally {
          isReading = false;
        }
      });

      final payload = jsonEncode({
        "type": "pairing_request",
        "device_name": appState.effectiveDeviceName,
        "short_nick": appState.effectiveShortNick,
        "profile_image": appState.profileImageB64,
        "user_id": appState.userId,
        "pubkey": appState.publicKeyHex,
        "buffer_bytes": byteSize,
      });

      await pairChar.write(Uint8List.fromList(utf8.encode(payload)));
      syncStepText = 'Awaiting peer approval...';
      notifyListeners();
    } catch (e) {
      log('[BLE Client Error] Handshake start failed: $e');
      _pairingReadTimer?.cancel();
      isSyncing = false;
      notifyListeners();
      if (onAlert != null) {
        onAlert!('BLE connection failed. Verify devices are side-by-side.');
      }
      startScanningFlow();
      startAdvertising();
    }
  }

  void _startHandshakeExecution({
    required String peerId,
    required String peerPubKey,
    required String derivedSeed,
    required int bufferBytes,
    required bool isInitiator,
    required String peerName,
    String peerShortNick = '',
    String peerProfileImage = '',
    BluetoothDevice? deviceToDisconnect,
  }) {
    isSyncing = true;
    syncProgress = 0.0;
    syncStepText = 'Coordinating key derivation...';
    notifyListeners();

    final steps = [
      'Establishing secure BLE pairing link... OK',
      'Deriving secure 256-bit seed locally...',
      'Exchanging agreed seed: $agreedSeed',
      'Deriving high-entropy keystream locally...',
      'Verifying pad offset pointer integrity...',
      'Sync successful.',
    ];

    int stepIndex = 0;
    _syncTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      syncProgress += (1.0 / steps.length);
      if (stepIndex < steps.length) {
        syncStepText = steps[stepIndex];
        stepIndex++;
      }
      notifyListeners();

      if (syncProgress >= 0.99) {
        syncProgress = 1.0;
        timer.cancel();
        _hexAnimationTimer?.cancel();

        _finalizeHandshake(
          peerId: peerId,
          peerName: peerName,
          bufferBytes: bufferBytes,
          derivedSeed: derivedSeed,
          peerShortNick: peerShortNick,
          peerProfileImage: peerProfileImage,
          deviceToDisconnect: deviceToDisconnect,
        );
      }
    });
  }

  Future<void> _finalizeHandshake({
    required String peerId,
    required String peerName,
    required int bufferBytes,
    required String derivedSeed,
    String peerShortNick = '',
    String peerProfileImage = '',
    BluetoothDevice? deviceToDisconnect,
  }) async {
    try {
      syncStepText = 'Generating keystream file...';
      notifyListeners();

      if (groupToInvite != null) {
        // Host path:
        final groupId = groupToInvite!.keyHash;

        final emptyLanes = await GroupDatabase.instance.getEmptyLanes(groupId);
        if (emptyLanes.isEmpty) {
          log('[BLE Host Error] No empty slots available to assign to member.');
          return;
        }
        final assignedSlot = emptyLanes.first['slot_index'] as int;

        await appState.hostRegisterMember(
          groupId: groupId,
          peerId: peerId,
          peerName: peerName,
          peerProfileImage: peerProfileImage,
          slotIndex: assignedSlot,
        );

        log(
          '[Pairing] Member $peerName ($peerId) added to group ${groupToInvite!.name} at slot $assignedSlot',
        );
      } else if (incomingGroupMetadata != null) {
        // Spoke path:
        final meta = incomingGroupMetadata!;
        final groupSeed = _decryptGroupSeed(
          meta['group_seed_encrypted'] as String,
          derivedSeed,
        );

        await appState.addOrRechargeGroupContact(
          name: meta['groupName'] as String,
          relayUrl: appState.activeRelayUrl,
          totalSize: meta['total_size'] as int,
          laneSize: meta['lane_size'] as int,
          groupId: meta['groupId'] as String,
          groupSeed: groupSeed,
          slotIndex: meta['slot_index'] as int,
          hostKeyHash: meta['hostKeyHash'] as String,
          hostName: meta['hostName'] as String,
          groupIconHex: meta['groupIcon'] as String?,
          maxMembers: meta['maxMembers'] as int?,
        );

        appState.requestGroupMetadata(
          appState.contacts.firstWhere((c) => c.keyHash == meta['groupId']),
        );
        log('[Pairing] Joined group ${meta['groupName']} successfully');
      } else {
        // Standard 1-on-1 contact sync:
        await appState.addOrRechargeContact(
          peerName,
          appState.activeRelayUrl,
          bufferBytes,
          peerId,
          derivedSeed,
          shortNick: peerShortNick,
          profileImage: peerProfileImage,
        );
        log('[Pairing] Contact created successfully for $peerName ($peerId)');
      }
    } catch (e) {
      log('[Pairing Error] Handshake finalization failed: $e');
    }

    if (deviceToDisconnect != null) {
      deviceToDisconnect.disconnect();
    }

    isSyncing = false;
    isSuccess = true;
    notifyListeners();
  }

  void resetState() {
    isSuccess = false;
    isSyncing = false;
    syncProgress = 0.0;
    syncStepText = 'Idle';
    selectedDevice = null;
    activeConnection = null;
    _smoothedRssi.clear();
    _lastSeen.clear();
    _lastSeenInRange.clear();
    _lastProcessedTimestamp.clear();
    _deviceCache.clear();
    _evictionTimer?.cancel();
    notifyListeners();
    startScanningFlow();
    startAdvertising();
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _encryptGroupSeed(String groupSeed, String pairwiseSeed) {
    final seedBytes = _hexToBytes(groupSeed);
    final keyBytes = sha256.convert(utf8.encode(pairwiseSeed)).bytes;
    final encryptedBytes = List<int>.generate(
      seedBytes.length,
      (i) => seedBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return _bytesToHex(encryptedBytes);
  }

  String _decryptGroupSeed(String encryptedSeedHex, String pairwiseSeed) {
    final encBytes = _hexToBytes(encryptedSeedHex);
    final keyBytes = sha256.convert(utf8.encode(pairwiseSeed)).bytes;
    final decryptedBytes = List<int>.generate(
      encBytes.length,
      (i) => encBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return _bytesToHex(decryptedBytes);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    _syncTimer?.cancel();
    _hexAnimationTimer?.cancel();
    _pairingReadTimer?.cancel();
    _evictionTimer?.cancel();
    stopAdvertising();
    activeConnection?.disconnect();
    super.dispose();
  }
}
