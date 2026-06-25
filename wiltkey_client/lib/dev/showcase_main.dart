import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import 'showcase_screen.dart';

/// DEV-ONLY entrypoint for previewing theme widgets and animations on desktop.
///
/// Run with:
///   flutter run -t lib/dev/showcase_main.dart
///
/// This deliberately bypasses onboarding, the database, websockets and BLE — it
/// just paints the theme's widgets with mock data, so it works on a laptop where
/// the real app can't reach its database.
///
/// It is NOT part of release builds: the shipped app builds `lib/main.dart`,
/// which never imports anything under `lib/dev/`. To strip everything for
/// release, delete the `lib/dev/` folder (then `grep -r "dev/" lib` is clean).
void main() {
  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShowcaseScreen(),
    );
  }
}
