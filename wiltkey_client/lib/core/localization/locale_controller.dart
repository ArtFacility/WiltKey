import 'package:flutter/material.dart';
import '../persistence.dart';

/// Holds the active locale selection and exposes it as a [Locale?].
///
/// A [ChangeNotifier] singleton that aligns with the app's existing
/// ThemeController design. Setting to null or 'system' falls back to
/// the operating system default language.
class LocaleController extends ChangeNotifier {
  static final LocaleController _instance = LocaleController._internal();
  factory LocaleController() => _instance;
  LocaleController._internal();

  final WiltkeyPersistence _persistence = WiltkeyPersistence();

  Locale? _locale;
  Locale? get locale => _locale;

  bool _isLocaleSet = false;
  bool get isLocaleSet => _isLocaleSet;

  /// Loads the saved locale. If not set or 'system', uses system default.
  Future<void> load() async {
    final stored = await _persistence.loadLocale();
    _isLocaleSet = stored != null;
    if (stored != null && stored != 'system') {
      _locale = Locale(stored);
    } else {
      _locale = null;
    }
  }

  /// Updates the active locale and persists it.
  Future<void> setLocale(String? languageCode) async {
    _isLocaleSet = true;
    if (languageCode == null || languageCode == 'system') {
      _locale = null;
    } else {
      _locale = Locale(languageCode);
    }
    notifyListeners();
    await _persistence.saveLocale(languageCode ?? 'system');
  }
}
