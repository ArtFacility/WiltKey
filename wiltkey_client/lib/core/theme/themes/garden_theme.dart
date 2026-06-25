import 'package:flutter/material.dart';
import '../wiltkey_tokens.dart';
import '../wiltkey_components.dart';
import '../components/garden_components.dart';

const String _ui = 'Sora';
const String _serif = 'Spectral';
const String _mono = 'IBMPlexMono';

// Dusk garden palette (from garden-concept.html).
const _soil = Color(0xFF181D17);
const _soil2 = Color(0xFF20271E);
const _soil3 = Color(0xFF2A3326);
const _linen = Color(0xFFE8E3D5);
const _fern = Color(0xFF8FA67A);
const _marigold = Color(0xFFE0A458);
const _dusk = Color(0xFF9D8CB5);
const _ash = Color(0xFF6E7566);

/// Tokens for the "Dusk Garden" look.
const WiltkeyTokens gardenTokens = WiltkeyTokens(
  bg: _soil,
  bgRaised: Color(0xFF1C211A),
  surface: _soil2,
  surfacePressed: _soil3,
  border: _soil3,
  textPrimary: _linen,
  textSecondary: Color(0xFFB9B6A6),
  textTertiary: _ash,
  action: _marigold,
  onAction: Color(0xFF1D1607),
  identity: _dusk,
  positive: _fern,
  warning: Color(0xFFC9924E),
  danger: Color(0xFFC56B5E),
  bubbleMe: Color(0xFF36422C),
  bubbleMeBorder: Color(0xFF46543A),
  bubbleMeText: _linen,
  bubbleThem: _soil2,
  bubbleThemBorder: _soil3,
  budgetFill: _marigold,
  budgetFillPeer: _fern,
  budgetLow: Color(0xFFC9924E),
  budgetEmpty: _soil3,
  budgetWilted: _ash,
  screenTitle: TextStyle(
    fontFamily: _serif,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: _linen,
  ),
  sectionLabel: TextStyle(
    fontFamily: _mono,
    fontSize: 11,
    letterSpacing: 2.0,
    color: _fern,
  ),
  body: TextStyle(fontFamily: _ui, fontSize: 15, color: _linen),
  bodySecondary: TextStyle(fontFamily: _ui, fontSize: 12.5, color: _ash),
  dataMono: TextStyle(fontFamily: _mono, fontSize: 10, color: _ash),
  badgeLabel: TextStyle(
    fontFamily: _ui,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  ),
  radiusCard: 18,
  radiusControl: 14,
  radiusPill: 999,
  borderWidth: 1,
  motionShort: Duration(milliseconds: 200),
  motionMedium: Duration(milliseconds: 350),
  motionBudget: Duration(milliseconds: 900),
  uppercaseLabels: false,
  emptyChatsIcon: Icons.spa_outlined,
);

ThemeData buildGardenTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    fontFamily: _ui,
    scaffoldBackgroundColor: _soil,
    colorScheme: const ColorScheme.dark(
      primary: _marigold,
      onPrimary: Color(0xFF1D1607),
      secondary: _dusk,
      surface: _soil2,
      onSurface: _linen,
      error: Color(0xFFC56B5E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _soil,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: _serif,
        color: _linen,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: _soil2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _soil3),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _soil2,
      hintStyle: const TextStyle(color: _ash),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _soil3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _soil3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _marigold),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _marigold,
        foregroundColor: const Color(0xFF1D1607),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontFamily: _ui, color: _linen, fontSize: 15),
      bodyMedium: TextStyle(fontFamily: _ui, color: _linen, fontSize: 13.5),
      titleMedium: TextStyle(
        fontFamily: _ui,
        color: _linen,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
    extensions: const [gardenTokens, WiltkeyComponentsExt(GardenComponents())],
  );
}
