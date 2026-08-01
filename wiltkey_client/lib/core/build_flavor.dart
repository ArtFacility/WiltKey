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

/// True only for the official Google Play build. Set via `--dart-define=WK_PLAY=true`
/// alongside `WK_FCM=true`. Gates everything monetization-facing: premium themes in
/// the registry, the Play Billing backend, and the Shop's purchase UI. When false —
/// the FOSS build, and the default — no Play/billing code path is reached and premium
/// themes are never listed (their source isn't in the public repo anyway).
const bool kPlayStore = bool.fromEnvironment('WK_PLAY', defaultValue: false);

/// TEMPORARY — remove after Google Play production approval.
///
/// Master switch for the debug-only "remote pairing" test path (pair/join a
/// contact over the relay instead of in-person BLE), added so scattered closed
/// testers can actually chat and satisfy Play's "low user engagement" gate. It
/// is ALSO gated at runtime by `kPlayStore` (Play build only) AND the in-app
/// debug toggle (`AppState.showDebugButtons`), so it never surfaces in a normal
/// session. Remote pairing lets a hostile relay attempt an active key-swap MITM
/// during the handshake (the in-person model can't), which the "paste peer hash"
/// verification defends against — but it is still testing-only and NOT part of
/// the shipped security story. Flip this to `false` to excise the whole feature
/// in one line; then delete `remote_pairing_controller.dart`, `remote_pair_tab.dart`,
/// `BlePairingManager.beginRemoteHandshake`, and the `pairInit/Join/Poll` calls.
const bool kRemotePairingTesting = true;
