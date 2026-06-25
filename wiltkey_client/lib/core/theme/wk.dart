import 'package:flutter/material.dart';
import 'wiltkey_tokens.dart';
import 'wiltkey_components.dart';

/// Ergonomic access to the active theme from any [BuildContext].
///
/// `context.wk`  → design tokens (colors, type, shape, motion).
/// `context.wkc` → the component factory (budget indicators, badges, …).
/// `context.reduceMotion` → honor the OS "reduce animations" setting.
extension WkContext on BuildContext {
  WiltkeyTokens get wk => Theme.of(this).extension<WiltkeyTokens>()!;

  WiltkeyComponents get wkc =>
      Theme.of(this).extension<WiltkeyComponentsExt>()!.components;

  bool get reduceMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? false;
}
