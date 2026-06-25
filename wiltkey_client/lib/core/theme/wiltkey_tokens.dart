import 'package:flutter/material.dart';

/// Semantic design tokens for a Wiltkey theme.
///
/// This is the single source of truth for colors, typography, shape and motion.
/// It rides on [ThemeData] as a [ThemeExtension] so every widget can reach it
/// through `Theme.of(context)` (see the `context.wk` helper in `wk.dart`), and so
/// that switching themes cross-fades smoothly via [AnimatedTheme]/[lerp].
///
/// Fields are named by MEANING, never by color. `action` is "the one accent the
/// user taps", not "cyan" or "marigold". This is what lets a new theme drop in
/// without touching call sites.
@immutable
class WiltkeyTokens extends ThemeExtension<WiltkeyTokens> {
  // ---- Colors: surfaces ----
  /// App background (the deepest layer).
  final Color bg;

  /// A slightly raised background used behind grouped content.
  final Color bgRaised;

  /// Card / control fill sitting on [bg].
  final Color surface;

  /// Pressed / active variant of [surface].
  final Color surfacePressed;

  /// Hairline borders and dividers.
  final Color border;

  // ---- Colors: text ----
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // ---- Colors: accents ----
  /// The single "tap me" accent (buttons, active tab, send).
  final Color action;

  /// Foreground drawn on top of [action] (e.g. text/icon inside a filled button).
  final Color onAction;

  /// Identity-only accent — usernames, identicon highlights. Never chrome.
  final Color identity;

  final Color positive;
  final Color warning;
  final Color danger;

  // ---- Colors: chat bubbles ----
  /// Our outgoing message bubble fill + border.
  final Color bubbleMe;
  final Color bubbleMeBorder;

  /// Text/foreground on our (filled) outgoing bubble. Separate from
  /// [textPrimary] because [bubbleMe] is dark even in light themes, so the body
  /// text on it must stay light/legible.
  final Color bubbleMeText;

  /// Incoming message bubble fill + border.
  final Color bubbleThem;
  final Color bubbleThemBorder;

  // ---- Colors: budget indicator ----
  /// Our remaining budget.
  final Color budgetFill;

  /// The peer's remaining budget.
  final Color budgetFillPeer;

  /// Low-budget warning fill.
  final Color budgetLow;

  /// Empty / consumed track.
  final Color budgetEmpty;

  /// Wilted (locked) state.
  final Color budgetWilted;

  // ---- Typography ----
  /// Large screen titles (Spectral in garden, mono-caps in cyberpunk).
  final TextStyle screenTitle;

  /// Small tracked section labels / eyebrows.
  final TextStyle sectionLabel;

  final TextStyle body;
  final TextStyle bodySecondary;

  /// Monospace, for byte counts, key hashes and crypto status ONLY.
  final TextStyle dataMono;

  /// Status-badge label.
  final TextStyle badgeLabel;

  // ---- Shape & space ----
  final double radiusCard;
  final double radiusControl;
  final double radiusPill;
  final double borderWidth;

  // ---- Motion / behaviour ----
  final Duration motionShort;
  final Duration motionMedium;

  /// Duration of a budget-change animation (petal fall / bar fill).
  final Duration motionBudget;

  /// Whether badge/section labels are UPPERCASED (cyberpunk) or sentence case (garden).
  final bool uppercaseLabels;

  /// Icon used for the "no chats yet" empty state (a flower for garden, a comms
  /// glyph for cyberpunk) so the placeholder matches the theme's vocabulary.
  final IconData emptyChatsIcon;

  const WiltkeyTokens({
    required this.emptyChatsIcon,
    required this.bg,
    required this.bgRaised,
    required this.surface,
    required this.surfacePressed,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.action,
    required this.onAction,
    required this.identity,
    required this.positive,
    required this.warning,
    required this.danger,
    required this.bubbleMe,
    required this.bubbleMeBorder,
    required this.bubbleMeText,
    required this.bubbleThem,
    required this.bubbleThemBorder,
    required this.budgetFill,
    required this.budgetFillPeer,
    required this.budgetLow,
    required this.budgetEmpty,
    required this.budgetWilted,
    required this.screenTitle,
    required this.sectionLabel,
    required this.body,
    required this.bodySecondary,
    required this.dataMono,
    required this.badgeLabel,
    required this.radiusCard,
    required this.radiusControl,
    required this.radiusPill,
    required this.borderWidth,
    required this.motionShort,
    required this.motionMedium,
    required this.motionBudget,
    required this.uppercaseLabels,
  });

  /// Soft drop/glow used behind filled elements. Garden returns `const []`
  /// ("no glow" is a token decision, not a per-widget `if`).
  List<BoxShadow> glow(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.4),
        blurRadius: 4,
        spreadRadius: 0.5,
      ),
    ];
  }

  @override
  WiltkeyTokens copyWith({
    Color? bg,
    Color? bgRaised,
    Color? surface,
    Color? surfacePressed,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? action,
    Color? onAction,
    Color? identity,
    Color? positive,
    Color? warning,
    Color? danger,
    Color? bubbleMe,
    Color? bubbleMeBorder,
    Color? bubbleMeText,
    Color? bubbleThem,
    Color? bubbleThemBorder,
    Color? budgetFill,
    Color? budgetFillPeer,
    Color? budgetLow,
    Color? budgetEmpty,
    Color? budgetWilted,
    TextStyle? screenTitle,
    TextStyle? sectionLabel,
    TextStyle? body,
    TextStyle? bodySecondary,
    TextStyle? dataMono,
    TextStyle? badgeLabel,
    double? radiusCard,
    double? radiusControl,
    double? radiusPill,
    double? borderWidth,
    Duration? motionShort,
    Duration? motionMedium,
    Duration? motionBudget,
    bool? uppercaseLabels,
    IconData? emptyChatsIcon,
  }) {
    return WiltkeyTokens(
      emptyChatsIcon: emptyChatsIcon ?? this.emptyChatsIcon,
      bg: bg ?? this.bg,
      bgRaised: bgRaised ?? this.bgRaised,
      surface: surface ?? this.surface,
      surfacePressed: surfacePressed ?? this.surfacePressed,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      action: action ?? this.action,
      onAction: onAction ?? this.onAction,
      identity: identity ?? this.identity,
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      bubbleMe: bubbleMe ?? this.bubbleMe,
      bubbleMeBorder: bubbleMeBorder ?? this.bubbleMeBorder,
      bubbleMeText: bubbleMeText ?? this.bubbleMeText,
      bubbleThem: bubbleThem ?? this.bubbleThem,
      bubbleThemBorder: bubbleThemBorder ?? this.bubbleThemBorder,
      budgetFill: budgetFill ?? this.budgetFill,
      budgetFillPeer: budgetFillPeer ?? this.budgetFillPeer,
      budgetLow: budgetLow ?? this.budgetLow,
      budgetEmpty: budgetEmpty ?? this.budgetEmpty,
      budgetWilted: budgetWilted ?? this.budgetWilted,
      screenTitle: screenTitle ?? this.screenTitle,
      sectionLabel: sectionLabel ?? this.sectionLabel,
      body: body ?? this.body,
      bodySecondary: bodySecondary ?? this.bodySecondary,
      dataMono: dataMono ?? this.dataMono,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusControl: radiusControl ?? this.radiusControl,
      radiusPill: radiusPill ?? this.radiusPill,
      borderWidth: borderWidth ?? this.borderWidth,
      motionShort: motionShort ?? this.motionShort,
      motionMedium: motionMedium ?? this.motionMedium,
      motionBudget: motionBudget ?? this.motionBudget,
      uppercaseLabels: uppercaseLabels ?? this.uppercaseLabels,
    );
  }

  @override
  WiltkeyTokens lerp(ThemeExtension<WiltkeyTokens>? other, double t) {
    if (other is! WiltkeyTokens) return this;
    return WiltkeyTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      bgRaised: Color.lerp(bgRaised, other.bgRaised, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfacePressed: Color.lerp(surfacePressed, other.surfacePressed, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      action: Color.lerp(action, other.action, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      identity: Color.lerp(identity, other.identity, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      bubbleMe: Color.lerp(bubbleMe, other.bubbleMe, t)!,
      bubbleMeBorder: Color.lerp(bubbleMeBorder, other.bubbleMeBorder, t)!,
      bubbleMeText: Color.lerp(bubbleMeText, other.bubbleMeText, t)!,
      bubbleThem: Color.lerp(bubbleThem, other.bubbleThem, t)!,
      bubbleThemBorder: Color.lerp(
        bubbleThemBorder,
        other.bubbleThemBorder,
        t,
      )!,
      budgetFill: Color.lerp(budgetFill, other.budgetFill, t)!,
      budgetFillPeer: Color.lerp(budgetFillPeer, other.budgetFillPeer, t)!,
      budgetLow: Color.lerp(budgetLow, other.budgetLow, t)!,
      budgetEmpty: Color.lerp(budgetEmpty, other.budgetEmpty, t)!,
      budgetWilted: Color.lerp(budgetWilted, other.budgetWilted, t)!,
      screenTitle: TextStyle.lerp(screenTitle, other.screenTitle, t)!,
      sectionLabel: TextStyle.lerp(sectionLabel, other.sectionLabel, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySecondary: TextStyle.lerp(bodySecondary, other.bodySecondary, t)!,
      dataMono: TextStyle.lerp(dataMono, other.dataMono, t)!,
      badgeLabel: TextStyle.lerp(badgeLabel, other.badgeLabel, t)!,
      // Numeric/shape tokens lerp; behavioural flags snap at the midpoint.
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t),
      radiusControl: lerpDouble(radiusControl, other.radiusControl, t),
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t),
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t),
      motionShort: t < 0.5 ? motionShort : other.motionShort,
      motionMedium: t < 0.5 ? motionMedium : other.motionMedium,
      motionBudget: t < 0.5 ? motionBudget : other.motionBudget,
      uppercaseLabels: t < 0.5 ? uppercaseLabels : other.uppercaseLabels,
      emptyChatsIcon: t < 0.5 ? emptyChatsIcon : other.emptyChatsIcon,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
