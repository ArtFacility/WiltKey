import '../avatar_border_registry.dart';

/// Public STUB — returns no premium borders.
///
/// The real premium border descriptors (and their SVG assets under
/// `assets/borders/premium/`) live in a **private repo** (WiltKey-Premium),
/// overlaid over this path on the official build machine via its `overlay.sh`
/// (mirrors the premium-theme setup; see `MONETIZATION_PHASE_A.md`). This
/// committed stub keeps the public repo and any fork compiling with only the free
/// borders; forks never receive premium border art. The registry only calls this
/// when `kPlayStore` is true.
///
/// A premium border is just another [WkAvatarBorder] with `premium: true` and an
/// `assetPath` under `assets/borders/premium/`.
List<WkAvatarBorder> premiumBorders() => const [];
