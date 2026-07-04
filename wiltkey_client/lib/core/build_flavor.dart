/// Compile-time distribution flavor flags.
///
/// Set once at build time via `--dart-define`, matching the Android product
/// flavor (see android/app/build.gradle.kts and documentation/Notif_Fragmenting.md):
///
///   • Play build:  flutter build appbundle --flavor play --dart-define=WK_FCM=true
///   • FOSS build:  flutter build apk        --flavor foss --dart-define=WK_FCM=false
///
/// [kFcmEnabled] gates every Firebase touchpoint on the Dart side (token
/// registration, the push MethodChannel, the notification-mode UX copy). When
/// false — the FOSS build, and the default when the define is omitted — the app
/// behaves exactly as the pre-FCM build: no Google code path is ever reached.
const bool kFcmEnabled = bool.fromEnvironment('WK_FCM', defaultValue: false);
