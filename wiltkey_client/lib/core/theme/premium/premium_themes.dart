import '../theme_registry.dart';

/// Public STUB — returns no premium themes.
///
/// The real premium themes live in a **private repo** (WiltKey-Premium) overlaid
/// over this path on the official build machine (see its `overlay.sh` /
/// `MONETIZATION_PHASE_A.md`). This committed stub keeps the public repo (and any
/// fork) compiling with only the free base themes; forks never receive the
/// premium theme source. The registry only calls this when `kPlayStore` is true,
/// so the FOSS build never lists premium themes either.
///
/// A premium theme is just another [WiltkeyThemeDescriptor] whose `build` returns
/// `ThemeData` with premium token values (ideally reusing the existing component
/// factories in `wiltkey_components.dart`).
List<WiltkeyThemeDescriptor> premiumThemes() => const [];
