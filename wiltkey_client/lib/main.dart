import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/onboarding/presentation/securing_connection_screen.dart';
import 'features/auth/presentation/pin_lock_screen.dart';
import 'core/state.dart';
import 'core/theme/theme_controller.dart';
import 'core/cosmetics/avatar_border_controller.dart';
import 'core/localization/locale_controller.dart';
import 'core/notifications/background_handler.dart';
import 'core/notifications/notification_service.dart';
import 'core/entitlements/entitlement_service.dart';
import 'core/update/update_service.dart';
import 'core/update/forced_update_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Notification system bootstrap (cheap; no network, no external services).
  // - The communication port lets the foreground-service isolate talk back.
  // - WorkManager is wired to the Low Power poll dispatcher.
  // - Local-notification channels are created up front.
  FlutterForegroundTask.initCommunicationPort();
  await Workmanager().initialize(callbackDispatcher);
  await WiltkeyNotifications.initLocalNotifications();

  // Read the persisted theme, locale and equipped avatar border before the
  // first frame.
  await ThemeController().load();
  await LocaleController().load();
  await AvatarBorderController().load();

  // Load cached entitlements (instant/offline) and, on the Play build only,
  // kick off a background Billing refresh. No-op / Google-free on FOSS.
  await EntitlementService().load();

  // Initialize version & build metadata and check for remote updates in the background.
  await UpdateService.instance.init();
  UpdateService.instance.checkForUpdates();

  runApp(const WiltkeyApp());
}

class WiltkeyApp extends StatefulWidget {
  const WiltkeyApp({super.key});

  @override
  State<WiltkeyApp> createState() => _WiltkeyAppState();
}

class _WiltkeyAppState extends State<WiltkeyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    AppState().addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    AppState().removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (AppState().isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild MaterialApp (and re-read theme/locale) whenever selections change.
    return ListenableBuilder(
      listenable: ThemeController(),
      builder: (context, _) {
        return ListenableBuilder(
          listenable: LocaleController(),
          builder: (context, _) {
            return MaterialApp(
              navigatorKey: _navigatorKey,
              title: 'Wiltkey',
              debugShowCheckedModeBanner: false,
              theme: ThemeController().themeData,
              locale: LocaleController().locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ListenableBuilder(
                listenable: UpdateService.instance,
                builder: (context, _) {
                  final updateService = UpdateService.instance;
                  if (updateService.isImmediateUpdate &&
                      updateService.cachedInfo != null) {
                    return ForcedUpdateScreen(info: updateService.cachedInfo!);
                  }

                  return ListenableBuilder(
                    listenable: AppState(),
                    builder: (context, _) {
                      final state = AppState();
                      if (!state.isLoaded) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (state.isOnboardingRequired) {
                        return const OnboardingScreen();
                      }
                      if (state.isLocked) {
                        return const PinLockScreen();
                      }
                      // First-ever device-token issuance (right after
                      // onboarding): a legible full-screen step instead of a
                      // silent shell while the proof-of-work runs.
                      if (state.showSecuringConnection) {
                        return const SecuringConnectionScreen();
                      }
                      return const AppShell();
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
