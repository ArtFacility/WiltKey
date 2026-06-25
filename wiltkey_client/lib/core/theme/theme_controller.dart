import 'package:flutter/material.dart';
import '../persistence.dart';
import 'theme_registry.dart';

/// Holds the active theme selection and exposes its [ThemeData].
///
/// A plain [ChangeNotifier] singleton, matching the app's existing
/// `AppState` + `ListenableBuilder` idiom (no Provider/Riverpod). `main.dart`
/// listens to this and rebuilds `MaterialApp.theme` on change.
class ThemeController extends ChangeNotifier {
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;
  ThemeController._internal();

  final WiltkeyPersistence _persistence = WiltkeyPersistence();

  String _themeId = WiltkeyThemeRegistry.defaultId;
  String get themeId => _themeId;

  WiltkeyThemeDescriptor get descriptor => WiltkeyThemeRegistry.byId(_themeId);
  ThemeData get themeData => descriptor.build();

  /// Reads the persisted selection. Call once in `main()` before `runApp` so the
  /// first frame paints in the right theme (no flash).
  Future<void> load() async {
    final stored = await _persistence.loadThemeId();
    if (stored != null) {
      _themeId = WiltkeyThemeRegistry.byId(stored).id; // normalizes unknown ids
    }
  }

  /// Switches the active theme and persists the choice.
  Future<void> setTheme(String id) async {
    final resolved = WiltkeyThemeRegistry.byId(id).id;
    if (resolved == _themeId) return;
    _themeId = resolved;
    notifyListeners();
    await _persistence.saveThemeId(resolved);
  }
}
