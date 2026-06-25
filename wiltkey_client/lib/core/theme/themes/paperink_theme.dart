import 'package:flutter/material.dart';
import '../wiltkey_tokens.dart';
import '../wiltkey_components.dart';
import '../components/paperink_components.dart';

const String _serif = 'ShipporiMincho';
const String _sans = 'ZenKakuGothicNew';
const String _mono = 'IBMPlexMono';

const Color _washi = Color(0xFFF7F4EB);
const Color _washi2 = Color(0xFFF0ECDF);
const Color _fiber = Color(0xFFE3DECC);
const Color _sumi = Color(0xFF1F2023);
const Color _wash = Color(0xFF585A57);
const Color _faint = Color(0xFF9C9D96);
const Color _shu = Color(0xFFC3402F);
const Color _wilted = Color(0xFFD8D3C0);
const Color _paperBright = Color(
  0xFFFCFAF3,
); // brighter-than-bg note (our bubble)

/// Tokens for the "Paper & Ink" look.
const WiltkeyTokens paperinkTokens = WiltkeyTokens(
  bg: _washi,
  bgRaised: _washi2,
  surface: _washi,
  surfacePressed: _fiber,
  border: _fiber,
  textPrimary: _sumi,
  textSecondary: _wash,
  textTertiary: _faint,
  action: _shu,
  onAction: _washi,
  identity: _sumi,
  positive: _sumi, // secured is black ink
  warning: _wash, // warning is washed ink
  danger: _faint, // danger is dry ink
  // Both bubbles are light paper notes with dark ink (a dark "me" bubble was
  // too jarring on the washi background). Ours is a brighter raised note; theirs
  // is the warmer recessed paper, so each still reads distinctly.
  bubbleMe: _paperBright,
  bubbleMeBorder: _fiber,
  bubbleMeText: _sumi,
  bubbleThem: _washi2,
  bubbleThemBorder: Color(0xFFCFC9B4),
  budgetFill: _sumi,
  budgetFillPeer: _wash,
  budgetLow: _faint,
  budgetEmpty: _fiber,
  budgetWilted: _wilted,
  screenTitle: TextStyle(
    fontFamily: _serif,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: _sumi,
  ),
  sectionLabel: TextStyle(
    fontFamily: _mono,
    fontSize: 11,
    letterSpacing: 2.0,
    color: _wash,
  ),
  body: TextStyle(fontFamily: _sans, fontSize: 14.5, color: _sumi),
  bodySecondary: TextStyle(fontFamily: _sans, fontSize: 12.5, color: _wash),
  dataMono: TextStyle(fontFamily: _mono, fontSize: 10, color: _faint),
  badgeLabel: TextStyle(
    fontFamily: _mono,
    fontSize: 9.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  ),
  radiusCard: 3.0,
  radiusControl: 3.0,
  radiusPill: 999.0,
  borderWidth: 1.0,
  motionShort: Duration(milliseconds: 150),
  motionMedium: Duration(milliseconds: 300),
  motionBudget: Duration(milliseconds: 800),
  uppercaseLabels: true,
  emptyChatsIcon: Icons.edit_note,
);

ThemeData buildPaperinkTheme() {
  return ThemeData(
    brightness: Brightness.light,
    fontFamily: _sans,
    scaffoldBackgroundColor: _washi,
    colorScheme: const ColorScheme.light(
      primary: _shu,
      onPrimary: _washi,
      secondary: _sumi,
      surface: _washi,
      onSurface: _sumi,
      error: _shu,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _washi,
      elevation: 0,
      iconTheme: IconThemeData(color: _sumi),
      titleTextStyle: TextStyle(
        fontFamily: _serif,
        color: _sumi,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: _washi,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: _fiber),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _washi,
      hintStyle: const TextStyle(color: _faint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: _fiber),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: _fiber),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: _sumi),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _shu,
        foregroundColor: _washi,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontFamily: _sans, color: _sumi, fontSize: 14.5),
      bodyMedium: TextStyle(fontFamily: _sans, color: _sumi, fontSize: 13.0),
      titleMedium: TextStyle(
        fontFamily: _sans,
        color: _sumi,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
    ),
    extensions: const [
      paperinkTokens,
      WiltkeyComponentsExt(PaperinkComponents()),
    ],
  );
}
