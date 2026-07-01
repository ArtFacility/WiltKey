library wiltkey_state;

import 'package:flutter/material.dart';
import 'dart:math' hide log;
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;
import 'dart:async';
import 'models.dart';
import 'persistence.dart';
import 'auth/biometric_auth.dart';
import 'crypto/otp_service.dart';
import 'network/websocket_client.dart';
import 'db/wiltkey_db.dart';
import 'chat_metadata.dart';
import 'custom_emoji.dart';
import 'notifications/notification_service.dart';
import 'notifications/pending_inbox.dart';

part 'state_auth.dart';
part 'state_chats.dart';
part 'state_chat_meta.dart';
part 'state_borrow.dart';
part 'state_emoji.dart';
part 'state_lifecycle.dart';
part 'state_inbound.dart';
part 'state_groups.dart';

enum AppStatus { normal, nuked }

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;

  static const int infoLaneSize = 1024 * 1024; // 1MB for group metadata/logs
  static const int laneHeaderSize =
      512; // Fixed per-lane metadata header (name, pic, order)

  AppState._internal() {
    _loadCleanState();
    _setupWebSocketCallbacks();
    WidgetsBinding.instance.addObserver(this);
    _initAndLoad();
  }

  bool isLocked = true;
  bool isOnboardingRequired = false;
  String? masterKeyHex;

  // Optional biometric unlock: whether the user opted in, and the epoch-ms of
  // the last successful unlock (PIN or biometric). Loaded before the lock screen
  // shows so it can decide whether to offer fingerprint. See state_auth.dart.
  bool biometricUnlockEnabled = false;
  int? lastUnlockMs;

  final WiltkeyPersistence _persistence = WiltkeyPersistence();
  bool isLoaded = false;
  bool isPickingMedia = false;

  // Reentrancy guard for [processPendingInbox]: both the unlock path and the
  // foreground-resume path drain the buffered background frames, and we must
  // never let the two overlap (a double-drain could re-dispatch frames).
  bool isDrainingPendingInbox = false;

  AppStatus status = AppStatus.normal;
  List<Contact> contacts = [];
  Map<String, List<ChatMessage>> messages = {};
  Contact? activeContact;

  // Debug Console Logs
  static final List<String> debugLogs = [];
  // Dedicated notifier for the debug console so logging doesn't rebuild the whole UI
  // (or fire notifyListeners during a build, which threw `setState() during build`).
  static final ValueNotifier<int> logRevision = ValueNotifier<int>(0);

  void log(String msg) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    debugLogs.add('[$timestamp] $msg');
    if (debugLogs.length > 500) {
      debugLogs.removeAt(0);
    }
    print('[WiltkeyLog] $msg');
    // Defer past the current frame so a log emitted during build can't trigger
    // setState-during-build, and so the main UI isn't rebuilt on every log line.
    scheduleMicrotask(() => logRevision.value++);
  }

  // Local device settings
  String deviceName = '';
  String shortNick = '';
  String profileImageB64 = '';

  String get effectiveShortNick {
    if (shortNick.isNotEmpty) return shortNick;
    if (deviceName.isNotEmpty) {
      final clean = deviceName.replaceAll(' ', '');
      return clean.substring(0, min(5, clean.length)).toUpperCase();
    }
    return userId.length >= 5
        ? userId.substring(0, 5).toUpperCase()
        : userId.toUpperCase();
  }

  String get effectiveDeviceName {
    if (deviceName.isNotEmpty) return deviceName;
    final suffix = userId.length >= 4
        ? userId.substring(0, 4).toUpperCase()
        : '';
    return 'Wiltkey Device ($suffix)';
  }

  // Background notification preference (off / lowPower / instant). Drives what,
  // if anything, runs while the app is backgrounded/locked. See notifications/.
  NotificationMode notificationMode = NotificationMode.off;

  // Local Dev settings for custom laptop relays. Off by default — the app uses
  // the production relay unless a tester explicitly enables dev mode in Settings.
  bool useLocalDevRelay = false;
  String localDevRelayUrl = 'http://192.168.1.234:8000';

  /// The always-reachable default relay; also the last-resort connection fallback.
  static const String productionRelayUrl = 'https://api.wiltkey.org';

  /// Public relays advertised by peers (via chat_info_update). Used purely as
  /// connection fallbacks when our own relay is unreachable — never auto-saved as
  /// the preference. LAN/loopback addresses are filtered out (useless to us).
  Set<String> knownPeerRelays = {};

  // When true, the terminal/debug-console button is shown on the chats list and
  // inside chats. Off by default to keep the everyday UI clean; toggled in
  // Settings → Network/Diagnostics.
  bool showDebugButtons = false;

  // Multiplier applied to chat message text (and inline emoji) sizes. 1.0 is the
  // default; clamped to a sane range. Set in Settings → Appearance.
  double chatTextScale = 1.0;

  // Per-chat "last read" wall-clock (ms since epoch), keyed by contact.id. Drives
  // the unread badge on the chats list: any inbound message newer than this is
  // unread. Bumped on open + on leaving a chat. Persisted across restarts.
  Map<String, int> lastReadMs = {};

  // --- Lazy message windowing ---
  // Messages are NOT all loaded on unlock (that doesn't scale). Instead a chat's
  // most-recent page loads when it's opened, older pages on scroll-back. These
  // track which chats currently have an in-memory window and whether more history
  // exists below it. Resync/archive/unread read the DB directly, so they don't
  // depend on what's loaded here. See state_chats loadInitialMessages/loadOlder.
  static const int messagePageSize = 30;
  final Set<String> loadedChats = {}; // contact.id with an in-memory window
  final Map<String, bool> hasMoreOlder = {}; // contact.id -> older page exists

  // DB-derived unread counts per contact.id (computed at unlock, kept live as
  // messages arrive / chats are read). Source for the chats-list badge.
  Map<String, int> unreadCounts = {};

  /// Appends a freshly-arrived/sent message to a chat's in-memory window — but
  /// only when that window is currently loaded. If the chat isn't open, the
  /// message is already persisted to the DB and will appear when it's next
  /// opened, so we skip the in-memory mutation (and avoid a misleading partial
  /// list that looks "loaded").
  void appendLoadedMessage(String chatId, ChatMessage msg) {
    if (!loadedChats.contains(chatId)) return;
    messages[chatId] = [...(messages[chatId] ?? []), msg];
  }

  String get activeRelayUrl =>
      useLocalDevRelay ? localDevRelayUrl : productionRelayUrl;

  /// Ordered connection fallbacks for the WebSocket client (excludes the active
  /// primary, which it tries first). Peer-advertised public relays, then the
  /// production default as the universal last resort.
  List<String> buildRelayFallbacks() {
    final out = <String>{};
    out.addAll(knownPeerRelays);
    out.add(productionRelayUrl); // always reachable
    out.remove(activeRelayUrl); // primary is handled separately
    return out.toList();
  }

  /// Records a public relay a peer advertised, so it can serve as a fallback if
  /// our configured relay goes bad. Ignores blanks, LAN/loopback hosts, and our
  /// own active relay. Returns true when the pool changed.
  bool addKnownPeerRelay(String? url) {
    if (url == null) return false;
    final u = url.trim();
    if (u.isEmpty || u == activeRelayUrl || _isLanRelay(u)) return false;
    if (!knownPeerRelays.add(u)) return false;
    _persistence.saveState(this);
    return true;
  }

  bool _isLanRelay(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return true;
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.') ||
        host.endsWith('.local');
  }

  // Identity Keys (Ed25519)
  late ed25519.KeyPair _identityKeyPair;
  late String publicKeyHex;
  late String privateKeyHex;
  late String userId; // SHA-256 hash of public key bytes

  // Track pairwise charge metrics for group members (UI topology panel)
  final Map<String, List<Map<String, dynamic>>> groupMembersMetadata = {};
  final Map<String, Map<String, int>> groupSlotsInfo = {};
  final Map<String, Map<String, Map<String, String>>> groupProfilesCache = {};

  // Per-group fallback timers for host-first metadata sync (groupId -> active timer)
  final Map<String, Timer> groupMetaSyncTimers = {};

  // Debounce for group auto-sync (groupId -> last sweep time)
  final Map<String, DateTime> lastGroupAutoSync = {};

  // Serializes inbound message processing so concurrent deliveries (offline queue
  // re-delivery + resync responses) can't interleave their read-check-append and
  // produce duplicate in-memory messages.
  Future<void> _incomingLock = Future.value();

  // Foreground watchdog that keeps the WebSocket alive while the app is open + unlocked.
  Timer? _connectionWatchdog;

  void _setupWebSocketCallbacks() {
    final ws = WebSocketClient();
    ws.onLog = log;
    ws.onSignChallenge = signMessage;
    ws.fallbackProvider = buildRelayFallbacks;
    ws.onMessageReceived = _deliverMessageToState;
    ws.onStatusChanged = (connected) {
      if (connected) {
        syncGroupLaneHeaders();
        // Catch up on anything we missed while offline, from every member.
        autoSyncAllGroups();
        // Push our current profile/permissions to 1-on-1 peers AND group members
        // (avatar/name resync after a reconnect).
        broadcastChatInfoToPeers();
        broadcastMyProfileToGroups();
        // Emoji defs/deletes are ordinary lane messages — autoSyncAllGroups (above)
        // and per-peer resync replay them; no separate emoji broadcast needed.
      }
      notifyListeners();
    };
  }

  Future<void> _initAndLoad() async {
    final data = await _persistence.loadState();

    notificationMode = NotificationMode.fromStorage(
      data['notificationMode'] as String?,
    );
    biometricUnlockEnabled = data['biometricEnabled'] as bool? ?? false;
    lastUnlockMs = data['lastUnlockMs'] as int?;

    final pinSalt = data['pinSalt'] as String?;
    final pinValidationHash = data['pinValidationHash'] as String?;

    if (pinSalt == null || pinValidationHash == null) {
      isOnboardingRequired = true;
      isLocked = false;
      isLoaded = true;
      notifyListeners();
      return;
    }

    isOnboardingRequired = false;
    isLocked = true;
    isLoaded = true;
    notifyListeners();
  }

  void _generateIdentityKeypair() {
    _identityKeyPair = ed25519.generateKey();

    // Convert keys to hex strings for presentation and wire protocols
    publicKeyHex = _bytesToHex(_identityKeyPair.publicKey.bytes);
    privateKeyHex = _bytesToHex(_identityKeyPair.privateKey.bytes);

    // User ID is SHA-256 of public key bytes (matches Go server dynamic ID)
    final sha256Digest = sha256.convert(_identityKeyPair.publicKey.bytes);
    userId = sha256Digest.toString();
  }

  void _loadCleanState() {
    // Start with a clean state, no placeholder contacts/messages
    contacts = [];
    messages = {};
    loadedChats.clear();
    hasMoreOlder.clear();
    unreadCounts.clear();
    activeContact = null;
    shortNick = '';
    profileImageB64 = '';
  }

  // Signs a message string using our private key and returns signature in hex
  String signMessage(String message) {
    final sigBytes = ed25519.sign(
      _identityKeyPair.privateKey,
      utf8.encode(message),
    );
    return _bytesToHex(sigBytes);
  }

  void updateDevRelaySettings({required bool use, required String url}) {
    useLocalDevRelay = use;
    localDevRelayUrl = url;
    notifyListeners();
    _persistence.saveState(this);
    WebSocketClient().connect(activeRelayUrl, publicKeyHex: publicKeyHex);
  }

  void setShowDebugButtons(bool value) {
    showDebugButtons = value;
    notifyListeners();
    _persistence.saveState(this);
  }

  void setChatTextScale(double value) {
    chatTextScale = value.clamp(0.8, 1.6);
    notifyListeners();
    _persistence.saveState(this);
  }

  void updateDeviceName(String name) {
    deviceName = name;
    notifyListeners();
    _persistence.saveState(this);
  }

  /// Saves the profile LOCALLY only. The network announce is intentionally
  /// separate (see [broadcastProfileUpdate]) so the settings screen can debounce
  /// it — otherwise every keystroke / drawn pixel would spam peers and groups.
  void updateProfile({
    required String name,
    required String nick,
    required String imageB64,
  }) {
    deviceName = name;
    shortNick = nick;
    profileImageB64 = imageB64;
    notifyListeners();
    _persistence.saveState(this);
  }

  /// Announce our current profile once: to every 1-on-1 peer AND every group
  /// member (full-mesh). Call this after profile edits have settled.
  Future<void> broadcastProfileUpdate() async {
    broadcastChatInfoToPeers();
    await broadcastMyProfileToGroups();
  }

  void notifyMessageReceived() {
    notifyListeners();
    _persistence.saveState(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused) {
      if (isPickingMedia) {
        log(
          '[State] App paused, but locking is bypassed because isPickingMedia is true.',
        );
        return;
      }
      lockApp();
      // Hand off to the selected background mechanism (foreground-service socket
      // for Instant, periodic poll for Low Power). No-op for Off. The main
      // socket has already been torn down by lockApp().
      WiltkeyNotifications.onAppBackgrounded(notificationMode);
    } else if (lifecycleState == AppLifecycleState.resumed) {
      // We own the socket again — stand down any background workers.
      WiltkeyNotifications.onAppForegrounded();
      // If we're back in the foreground and still unlocked, make sure the socket
      // is live again immediately (don't wait for the next watchdog tick).
      if (!isLocked && masterKeyHex != null) {
        _checkConnectionHealth();
        startConnectionWatchdog();
        // Apply anything the background socket buffered while minimized. The
        // unlock path already does this, but a foreground that doesn't pass
        // through the lock screen (biometric window / immediate-lock off) would
        // otherwise leave buffered control frames — delivery_check requests and
        // their responses — sitting unprocessed. Drain after the socket is back
        // so any replies/resends triggered by replay can actually go out.
        _drainPendingInboxOnResume();
      }
    }
  }

  /// Foreground-resume drain: wait for the socket to be live, then replay any
  /// frames the background socket buffered while we were minimized. Kept off the
  /// synchronous lifecycle callback so the await chain (reconnect → replay →
  /// outgoing replies/resends) can complete in the background.
  Future<void> _drainPendingInboxOnResume() async {
    try {
      await ensureWebSocketConnected();
      await processPendingInbox();
    } catch (e) {
      log('[Notifications] Resume drain failed: $e');
    }
  }

  /// Change the background notification mode. Persisted immediately; the actual
  /// background work is (re)configured the next time the app is backgrounded.
  /// Requesting the Instant mode prompts for the notification permission up front.
  Future<void> setNotificationMode(NotificationMode mode) async {
    notificationMode = mode;
    notifyListeners();
    await _persistence.saveState(this);
    if (mode == NotificationMode.off) {
      await WiltkeyNotifications.stopBackgroundWork();
    } else {
      await WiltkeyNotifications.requestPermission();
    }
  }

  /// Mirror the identity signing key + relay coordinates into background storage
  /// (keystore + prefs) so the locked-state background workers can authenticate.
  /// The PIN-derived master key is deliberately NOT shared — background code can
  /// prove identity but can never decrypt message content.
  Future<void> cacheBackgroundCredentials() async {
    try {
      await WiltkeyNotifications.cacheCredentials(
        relayUrl: activeRelayUrl,
        userId: userId,
        publicKeyHex: publicKeyHex,
        privateKeyHex: privateKeyHex,
      );
    } catch (e) {
      log('[Notifications] Failed to cache background credentials: $e');
    }
  }

  /// Reconnects the WebSocket if we're unlocked + open but the socket is down.
  /// Safe to call repeatedly: connect() de-dupes via its _isConnecting/generation guard.
  void _checkConnectionHealth() {
    if (isLocked || masterKeyHex == null) return;
    final ws = WebSocketClient();
    if (!ws.isConnected) {
      log('[WS Watchdog] Socket down while unlocked. Reconnecting...');
      ws.connect(activeRelayUrl, publicKeyHex: publicKeyHex);
    }
  }

  /// Starts the periodic foreground connection watchdog. Idempotent.
  void startConnectionWatchdog() {
    _connectionWatchdog?.cancel();
    _connectionWatchdog = Timer.periodic(const Duration(seconds: 12), (_) {
      _checkConnectionHealth();
    });
  }

  void stopConnectionWatchdog() {
    _connectionWatchdog?.cancel();
    _connectionWatchdog = null;
  }

  // Formats byte metrics dynamically into B, KB, or MB
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1048576) {
      return '${(bytes / 1024.0).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / 1048576.0).toStringAsFixed(1)} MB';
    }
  }

  bool _isUrlPrivate(String url) {
    return !url.contains('api.wiltkey.org');
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  Future<void> ensureWebSocketConnected() async {
    final ws = WebSocketClient();
    if (!ws.isConnected) {
      log('[WS Self-Heal] WebSocket is not connected. Triggering connect...');
      ws.connect(activeRelayUrl, publicKeyHex: publicKeyHex);

      int elapsed = 0;
      while (!ws.isConnected && elapsed < 2000) {
        await Future.delayed(const Duration(milliseconds: 100));
        elapsed += 100;
      }
      if (ws.isConnected) {
        log('[WS Self-Heal] WebSocket connected successfully.');
      } else {
        log(
          '[WS Self-Heal] WebSocket connection attempt timed out or still connecting.',
        );
      }
    }
  }
}
