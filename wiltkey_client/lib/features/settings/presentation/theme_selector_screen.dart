import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/theme/wk.dart';
import 'widgets/theme_picker.dart';

/// Dedicated theme-selector page. Hosts the live-preview [ThemePicker] on its own
/// screen so the Profile tab only needs a compact "Theme" button instead of the
/// full stack of theme cards (which grows with every owned/premium theme).
///
/// All the real logic — live previews, premium lock badges, routing a locked card
/// to the Shop, persisting the choice — lives in [ThemePicker]; this is just the
/// scrollable scaffold around it.
class ThemeSelectorScreen extends StatelessWidget {
  const ThemeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.action),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t.uppercaseLabels
              ? l10n.settingsProfileSectionAppearance.toUpperCase()
              : l10n.settingsProfileSectionAppearance,
          style: t.screenTitle.copyWith(fontSize: 18),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(18),
        child: ThemePicker(),
      ),
    );
  }
}
