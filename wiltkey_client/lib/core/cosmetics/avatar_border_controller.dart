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
      // Honour whatever was equipped, independent of live entitlement. Borders
      // are ONE-TIME purchases, and entitlement (Play Billing) resolves
      // asynchronously AFTER this runs at cold start — gating on canEquip here
      // dropped a legitimately-owned premium border back to none on every launch.
      // byId() already resolves to none for an id this build can't render (e.g. a
      // fork without the premium overlay), which is the only reset we actually
      // want. Equipping a NEW border is still ownership-gated in [setBorder].
      _borderId = WkAvatarBorderRegistry.byId(stored).id;
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
