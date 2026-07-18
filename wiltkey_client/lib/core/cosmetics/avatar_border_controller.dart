import 'package:flutter/foundation.dart';
import '../persistence.dart';
import 'avatar_border_registry.dart';

/// Holds the local user's equipped avatar border and persists the choice.
///
/// A [ChangeNotifier] singleton matching the app's `ThemeController` idiom. The
/// user's *own* avatar reads [borderId] here; a *peer's* border comes from their
/// broadcast profile (contact row), not from this controller.
class AvatarBorderController extends ChangeNotifier {
  static final AvatarBorderController _instance =
      AvatarBorderController._internal();
  factory AvatarBorderController() => _instance;
  AvatarBorderController._internal();

  static AvatarBorderController get instance => _instance;

  final WiltkeyPersistence _persistence = WiltkeyPersistence();

  String _borderId = WkAvatarBorderRegistry.noneId;
  String get borderId => _borderId;

  WkAvatarBorder get border => WkAvatarBorderRegistry.byId(_borderId);

  /// Reads the persisted selection. Call once in `main()`.
  Future<void> load() async {
    final stored = await _persistence.loadAvatarBorderId();
    if (stored != null) {
      final resolved = WkAvatarBorderRegistry.byId(stored);
      // Drop a border that's no longer selectable (e.g. a lapsed entitlement or a
      // premium border on a build that can't equip it) back to none.
      _borderId = WkAvatarBorderRegistry.canEquip(resolved)
          ? resolved.id
          : WkAvatarBorderRegistry.noneId;
    }
  }

  /// Equips [id] and persists it. No-op if the border isn't selectable.
  Future<void> setBorder(String id) async {
    final resolved = WkAvatarBorderRegistry.byId(id);
    if (!WkAvatarBorderRegistry.canEquip(resolved)) return;
    if (resolved.id == _borderId) return;
    _borderId = resolved.id;
    notifyListeners();
    await _persistence.saveAvatarBorderId(resolved.id);
  }
}
