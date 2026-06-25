import 'package:flutter/material.dart';
import '../wiltkey_tokens.dart';
import '../wiltkey_components.dart';
import '../components/cyberpunk_components.dart';

const String _mono = 'IBMPlexMono';

/// Tokens for the original "Neon Grid" look. Values match the pre-refactor
/// inline theme; the cohesion pass formalizes one mono family (IBM Plex Mono),
/// one radius scale and one glow recipe.
const WiltkeyTokens cyberpunkTokens = WiltkeyTokens(
  bg: Color(0xFF0B0C10),
  bgRaised: Color(0xFF11161D),
  surface: Color(0xFF1F2833),
  surfacePressed: Color(0xFF2A3340),
  border: Color(0xFF2C3A45),
  textPrimary: Colors.white,
  textSecondary: Colors.white70,
  textTertiary: Colors.white38,
  action: Color(0xFF66FCF1),
  onAction: Color(0xFF0B0C10),
  identity: Color(0xFFBD00FF),
  positive: Color(0xFF45A29E),
  warning: Color(0xFFFFB300),
  danger: Color(0xFFFF3366),
  bubbleMe: Color(0xFF222D38),
  bubbleMeBorder: Color(0x4D66FCF1),
  bubbleMeText: Colors.white,
  bubbleThem: Color(0xFF161D24),
  bubbleThemBorder: Color(0x2645A29E),
  budgetFill: Color(0xFF66FCF1),
  budgetFillPeer: Color(0xFFFFD54F),
  budgetLow: Color(0xFFFFB300),
  budgetEmpty: Color(0xFF1F2833),
  budgetWilted: Color(0xFFFF3366),
  screenTitle: TextStyle(
    fontFamily: _mono,
    fontSize: 15,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
    color: Colors.white,
  ),
  sectionLabel: TextStyle(
    fontFamily: _mono,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.8,
    color: Colors.white70,
  ),
  body: TextStyle(fontSize: 14, color: Colors.white),
  bodySecondary: TextStyle(fontSize: 13, color: Colors.white70),
  dataMono: TextStyle(fontFamily: _mono, fontSize: 11, color: Colors.white70),
  badgeLabel: TextStyle(
    fontFamily: _mono,
    fontSize: 8.5,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.8,
  ),
  radiusCard: 8,
  radiusControl: 4,
  radiusPill: 999,
  borderWidth: 1,
  motionShort: Duration(milliseconds: 200),
  motionMedium: Duration(milliseconds: 400),
  motionBudget: Duration(milliseconds: 600),
  uppercaseLabels: true,
  emptyChatsIcon: Icons.chat_bubble_outline,
);

ThemeData buildCyberpunkTheme() {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: cyberpunkTokens.bg,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF66FCF1),
      onPrimary: Color(0xFF0B0C10),
      secondary: Color(0xFFFF3366),
      surface: Color(0xFF1F2833),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B0C10),
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white, fontSize: 14),
      bodyMedium: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
      titleMedium: TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    ),
    extensions: const [
      cyberpunkTokens,
      WiltkeyComponentsExt(CyberpunkComponents()),
    ],
  );
}
