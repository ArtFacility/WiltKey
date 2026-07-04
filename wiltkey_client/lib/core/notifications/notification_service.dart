import 'dart:ui' show Locale;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../l10n/app_localizations.dart';
import '../build_flavor.dart';
import 'background_handler.dart';
import 'push_channel.dart';

/// How the app checks for incoming messages while it is backgrounded/locked.
/// Persisted under [kPrefNotificationMode]; also read by the background isolates
/// directly from SharedPreferences.
enum NotificationMode {
  /// Nothing runs in the background (legacy behavior).
  off,

  /// An adaptive background poll of `GET /api/v1/queue/status`: tight right after
  /// the app is backgrounded (~30 s) so a quick reply still feels near-instant,
  /// backing off toward ~10 min while it stays quiet and snapping back when a
  /// message lands. No persistent socket; light on battery.
  lowPower,

  /// An Android foreground service keeps a WebSocket open in a background
  /// isolate and fires a notification the instant a frame arrives.
  instant;

  String get storageValue => name;

  static NotificationMode fromStorage(String? v) {
    switch (v) {
      case 'lowPower':
        return NotificationMode.lowPower;
      case 'instant':
        return NotificationMode.instant;
      default:
        return NotificationMode.off;
    }
  }
}

// --- Shared keys/ids (also referenced from the background isolates) ----------
const String kPrefNotificationMode = 'wk_notification_mode';
const String kPrefBgRelayUrl = 'wk_bg_relay_url';
const String kPrefBgUserId = 'wk_bg_user_id';
const String kPrefBgPubKey = 'wk_bg_pubkey';
const String kSecureSigningKey = 'wk_bg_signing_key';

const String kLowPowerTaskName = 'wk_low_power_poll';
const String kLowPowerTaskUnique = 'wk_low_power_poll_unique';

/// Adaptive backoff ladder for the background poll. After the app is backgrounded
/// the poll starts at the fast end so a reply that lands seconds later still feels
/// near-real-time; each empty poll steps one rung sparser to save battery, and a
/// poll that finds a message snaps back to the fast rung. Android's Doze/App
/// Standby will stretch the short rungs once the device is idle (WorkManager can't
/// guarantee sub-15-min wakeups) — so these are a best-effort target: tight right
/// after the app closes, sparse when the device is truly idle.
const List<Duration> kLowPowerBackoff = <Duration>[
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
  Duration(minutes: 10),
];

/// Persisted current rung index into [kLowPowerBackoff].
const String kPrefLowPowerBackoffIndex = 'wk_low_power_backoff_index';

/// True while the app is backgrounded in a mode that wants the poll cycling.
/// Gates the self-reschedule so the loop stops cleanly on foreground / mode off.
const String kPrefBgPollActive = 'wk_bg_poll_active';

/// Heartbeat (epoch ms) written by the Instant foreground service on start and on
/// every watchdog tick. While it's fresh the backstop poll stays silent (the
/// socket is delivering); when it goes stale — the Android 15 6-hour dataSync
/// timeout or an OEM battery-killer stopping the service — the poll takes over.
const String kPrefFgHeartbeatMs = 'wk_fg_heartbeat_ms';
const int kFgHeartbeatFreshMs = 90 * 1000;

/// Next poll delay for a given backoff rung (clamped to the ladder).
Duration lowPowerDelayForIndex(int index) {
  if (index <= 0) return kLowPowerBackoff.first;
  if (index >= kLowPowerBackoff.length) return kLowPowerBackoff.last;
  return kLowPowerBackoff[index];
}

const String kFgChannelId = 'wk_secure_link';
const String kFgChannelName = 'Secure link';
const String kMsgChannelId = 'wk_messages';
const String kMsgChannelName = 'Messages';
const int kFgServiceId = 4711;

/// Single collapsed id for the "you got a message" alert — every new-message
/// notification reuses it (so they don't stack), and it's the id we cancel once
/// the app is foregrounded / the chat is opened.
const int kMsgNotificationId = 1;

/// Orchestrates the notification system on the **main** isolate: local
/// notification setup, permission, caching the credentials the background
/// isolates need, and starting/stopping the active background mechanism.
class WiltkeyNotifications {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static bool _localInited = false;

  /// Initialize the local-notifications plugin and channels. Safe to call
  /// repeatedly. Used from both the main isolate and the background isolates.
  // Prefs key holding the chat keyHash a tapped notification wants to open. The
  // main isolate consumes it after unlock (see [takePendingChat]).
  static const String _kPendingChat = 'wk_pending_chat';

  static Future<void> initLocalNotifications() async {
    if (_localInited) return;
    // Monochrome, transparent-background status-bar icon. The launcher icon
    // would render as a solid white box (Android only uses the alpha mask).
    const androidInit = AndroidInitializationSettings(
      '@drawable/ic_stat_notif',
    );
    const initSettings = InitializationSettings(android: androidInit);
    await plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTap,
    );

    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        kMsgChannelId,
        kMsgChannelName,
        description: 'New secure message alerts',
        importance: Importance.high,
      ),
    );
    _localInited = true;
  }

  /// Ask for the Android 13+ POST_NOTIFICATIONS runtime permission.
  static Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Resolve localized strings without a BuildContext (works in background
  /// isolates too). Reads the persisted locale; falls back to English for an
  /// unset/"system"/unsupported value.
  static Future<AppLocalizations> _strings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(
        'wk_locale',
      ); // mirrors WiltkeyPersistence._keyLocale
      if (code != null && code.isNotEmpty && code != 'system') {
        return lookupAppLocalizations(Locale(code));
      }
    } catch (_) {}
    return lookupAppLocalizations(const Locale('en'));
  }

  /// Show the content-free "you got a message" alert. We never decrypt in the
  /// background, so the body is deliberately generic. [chatKey] (the sender's
  /// keyHash, when known) rides as the payload so a tap can deep-link to that
  /// chat after unlock.
  static Future<void> showMessageNotification({String? chatKey}) async {
    await initLocalNotifications();
    final l10n = await _strings();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        kMsgChannelId,
        kMsgChannelName,
        channelDescription: 'New secure message alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notif',
        // No content preview — content stays encrypted until the device unlocks.
      ),
    );
    await plugin.show(
      kMsgNotificationId,
      'Wiltkey',
      l10n.notificationNewMessageBody,
      details,
      payload: chatKey,
    );
  }

  /// Dismiss the "you got a message" alert(s). Called when the app returns to the
  /// foreground and when a chat is opened, so a message the user has now seen
  /// doesn't linger in the tray. Safe to call when nothing is showing.
  static Future<void> cancelMessageNotifications() async {
    try {
      await plugin.cancel(kMsgNotificationId);
    } catch (_) {}
  }

  /// Notification-tap handler (foreground + background isolates). We can't
  /// navigate from here (no app context, possibly locked), so we stash the
  /// target chat for the main isolate to open after unlock.
  @pragma('vm:entry-point')
  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _stashPendingChat(payload);
  }

  static Future<void> _stashPendingChat(String payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingChat, payload);
    } catch (_) {}
  }

  /// Returns (and clears) the chat keyHash a tapped notification wants opened —
  /// from a cold launch (app-launch details) or a warm tap (stashed in prefs).
  /// Null when the app wasn't opened from a message notification.
  static Future<String?> takePendingChat() async {
    String? key;
    try {
      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final p = launch!.notificationResponse?.payload;
        if (p != null && p.isNotEmpty) key = p;
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    key ??= prefs.getString(_kPendingChat);
    await prefs.remove(_kPendingChat);
    // Play flavor: an FCM push posts its notification natively, so the tap target
    // rides a separate native channel instead of flutter_local_notifications.
    key ??= await PushChannel.takePendingChat();
    return (key != null && key.isNotEmpty) ? key : null;
  }

  /// Persist the small set of credentials the background isolates need:
  /// relay URL / user id / public key in plain prefs (non-sensitive) and the
  /// Ed25519 signing key in the OS keystore so background workers can
  /// authenticate while the app is locked. The PIN-derived master key is never
  /// stored here, so background code can prove identity but cannot decrypt
  /// message content.
  static Future<void> cacheCredentials({
    required String relayUrl,
    required String userId,
    required String publicKeyHex,
    required String privateKeyHex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefBgRelayUrl, relayUrl);
    await prefs.setString(kPrefBgUserId, userId);
    await prefs.setString(kPrefBgPubKey, publicKeyHex);
    await _secure.write(key: kSecureSigningKey, value: privateKeyHex);
  }

  /// Wipe everything the background system stored. Called on nuke/reset.
  static Future<void> clearCredentials() async {
    await stopBackgroundWork();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPrefBgRelayUrl);
    await prefs.remove(kPrefBgUserId);
    await prefs.remove(kPrefBgPubKey);
    await prefs.remove(kPrefNotificationMode);
    try {
      await _secure.delete(key: kSecureSigningKey);
    } catch (_) {}
  }

  // --- Background mechanism control ----------------------------------------

  /// Called when the app goes to the background. Starts whatever the selected
  /// mode requires.
  static Future<void> onAppBackgrounded(NotificationMode mode) async {
    switch (mode) {
      case NotificationMode.off:
        await stopBackgroundWork();
        break;
      case NotificationMode.lowPower:
        await _stopForegroundService();
        await _scheduleAdaptivePoll();
        break;
      case NotificationMode.instant:
        if (kFcmEnabled) {
          // Play flavor: FCM is the sole wake-up trigger — NO persistent foreground
          // service (no persistent notification, no Android 15 6-hour dataSync cap,
          // lighter battery) and NO backstop poll (it would double-notify alongside
          // FCM, since there's no foreground-service heartbeat to gate it). A rare
          // missed push just leaves the message queued, encrypted, on the relay; it
          // arrives the next time the app is opened. Users who can't rely on Play
          // Services can pick Low Power instead.
          await stopBackgroundWork();
        } else {
          // FOSS flavor: a foreground-service socket delivers instantly.
          await _startForegroundService();
          // Backstop poll: silent and idle at the sparse rung while the service is
          // healthy (heartbeat fresh), it seamlessly takes over delivery if the
          // service is killed — including the Android 15 6-hour dataSync timeout
          // and OEM battery-killers — instead of Instant going silent.
          await _scheduleAdaptivePoll();
        }
        break;
    }
  }

  /// Called when the app returns to the foreground — the main isolate takes
  /// back ownership of the socket, so background work stands down.
  static Future<void> onAppForegrounded() async {
    await stopBackgroundWork();
    // The user is back in the app — clear any pending "new message" tray alert so
    // it doesn't linger after they've seen (or are about to see) the message.
    await cancelMessageNotifications();
  }

  static Future<void> stopBackgroundWork() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefBgPollActive, false);
    } catch (_) {}
    await _stopForegroundService();
    await _cancelLowPowerPoll();
  }

  // Instant mode: foreground service hosting the background WebSocket.
  static Future<void> _startForegroundService() async {
    try {
      await requestPermission();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: kFgChannelId,
          channelName: kFgChannelName,
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          // A periodic watchdog tick to re-open the socket if it dropped.
          eventAction: ForegroundTaskEventAction.repeat(30000),
          autoRunOnBoot: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      if (await FlutterForegroundTask.isRunningService) return;
      final l10n = await _strings();
      await FlutterForegroundTask.startService(
        serviceId: kFgServiceId,
        notificationTitle: 'Wiltkey',
        notificationText: l10n.notificationSecureLinkActive,
        callback: startCallback,
      );
    } catch (_) {
      // No platform binding (e.g. unit tests / unsupported OS) — ignore.
    }
  }

  static Future<void> _stopForegroundService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  // A self-rescheduling one-off poll on the adaptive backoff ladder. WorkManager's
  // periodic floor is 15 min, so we re-enqueue a one-off each run (see the
  // background isolate's reschedule) instead of a periodic task. Starts at the
  // fast rung; the background handler steps it. Used for Low Power mode and as the
  // Instant-mode backstop.
  static Future<void> _scheduleAdaptivePoll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefBgPollActive, true);
      await prefs.setInt(kPrefLowPowerBackoffIndex, 0); // start fast
      await Workmanager().registerOneOffTask(
        kLowPowerTaskUnique,
        kLowPowerTaskName,
        initialDelay: lowPowerDelayForIndex(0),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {}
  }

  static Future<void> _cancelLowPowerPoll() async {
    try {
      await Workmanager().cancelByUniqueName(kLowPowerTaskUnique);
    } catch (_) {}
  }
}
