import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wiltkey_client/core/theme/theme_registry.dart';
import 'package:wiltkey_client/core/theme/wk.dart';
import 'package:wiltkey_client/core/theme/wiltkey_tokens.dart';
import 'package:wiltkey_client/features/onboarding/presentation/widgets/pixel_puzzle_drag.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import 'package:wiltkey_client/core/network/puzzle.dart';

/// DEV-ONLY endless human-verification puzzle practice loop (PC or device).
///
/// Run with:
///   flutter run -t lib/dev/puzzle_main.dart -d windows
///
/// Generates puzzle after puzzle with fresh seeds; solve, get instant
/// pass/fail, auto-advance. Runs entirely offline: answers are checked
/// against the local mirror of the relay's derivation (puzzle.dart), so this
/// exercises the INTERACTION and the shared math, not the network path —
/// for the full end-to-end loop (real frames, strikes, deadlines) run
/// wiltkey_server/cmd/puzzleplay against the real app.
///
/// New puzzle kinds should plug in HERE (kind selector) and in
/// PixelPuzzleDrag, keeping the pass/fail/stats loop unchanged.
///
/// Not part of release builds: lib/main.dart never imports lib/dev/.
void main() {
  runApp(const PuzzleTesterApp());
}

class PuzzleTesterApp extends StatelessWidget {
  const PuzzleTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Theme(
        data: WiltkeyThemeRegistry.byId('paperink').build(),
        child: const PuzzleTesterScreen(),
      ),
    );
  }
}

class PuzzleTesterScreen extends StatefulWidget {
  const PuzzleTesterScreen({super.key});

  @override
  State<PuzzleTesterScreen> createState() => _PuzzleTesterScreenState();
}

enum _PuzzleOutcome { none, correct, wrong }

class _PuzzleTesterScreenState extends State<PuzzleTesterScreen> {
  final Random _rng = Random.secure();

  String _seed = '';
  int _round = 0;
  int _solved = 0;
  int _failed = 0;
  int _streak = 0;
  int _bestStreak = 0;
  Duration _totalTime = Duration.zero;
  _PuzzleOutcome _outcome = _PuzzleOutcome.none;
  DateTime _roundStart = DateTime.now();
  // Future kinds go here ('strip_slide' first); the UI offers a picker once
  // there is more than one.
  static const String _kind = 'strip_slide';

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  void _nextRound() {
    setState(() {
      _seed = _randomSeed();
      _round++;
      _outcome = _PuzzleOutcome.none;
      _roundStart = DateTime.now();
    });
  }

  String _randomSeed() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _onLocalCheck(bool correct) {
    final elapsed = DateTime.now().difference(_roundStart);
    setState(() {
      _outcome = correct ? _PuzzleOutcome.correct : _PuzzleOutcome.wrong;
      if (correct) {
        _solved++;
        _streak++;
        _bestStreak = max(_bestStreak, _streak);
        _totalTime += elapsed;
      } else {
        _failed++;
        _streak = 0;
      }
    });
    // Brief feedback beat, then the next puzzle. Wrong answers get a longer
    // pause (reading the fail state is part of spotting UX gaps).
    Future.delayed(Duration(milliseconds: correct ? 700 : 1600), () {
      if (mounted) _nextRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final avg = _solved > 0
        ? Duration(milliseconds: _totalTime.inMilliseconds ~/ _solved)
        : Duration.zero;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DEV · Puzzle endless tester ($_kind)',
                    style: t.screenTitle.copyWith(fontSize: 15),
                  ),
                  Text(
                    '#$_round',
                    style: t.dataMono.copyWith(color: t.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'seed ${_seed.substring(0, 16)}…',
                style: t.dataMono.copyWith(
                  fontSize: 9,
                  color: t.textTertiary,
                ),
              ),
              const SizedBox(height: 18),

              // Stats strip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(t, 'solved', '$_solved', t.positive),
                    _stat(t, 'failed', '$_failed', t.danger),
                    _stat(t, 'streak', '$_streak', t.action),
                    _stat(t, 'best', '$_bestStreak', t.textSecondary),
                    _stat(t, 'avg',
                        '${avg.inMilliseconds / 1000 >= 10 ? avg.inSeconds : (avg.inMilliseconds / 1000.0).toStringAsFixed(1)}s',
                        t.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Outcome banner
              SizedBox(
                height: 34,
                child: _outcome == _PuzzleOutcome.none
                    ? const SizedBox.shrink()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _outcome == _PuzzleOutcome.correct
                                ? Icons.check_circle
                                : Icons.cancel,
                            size: 20,
                            color: _outcome == _PuzzleOutcome.correct
                                ? t.positive
                                : t.danger,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _outcome == _PuzzleOutcome.correct
                                ? 'LOCKED IN — correct'
                                : 'WRONG — strikes would burn here',
                            style: t.dataMono.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _outcome == _PuzzleOutcome.correct
                                  ? t.positive
                                  : t.danger,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),

              PixelPuzzleDrag(
                key: ValueKey('$_round$_seed'),
                seed: _seed,
                strips: 5,
                localCheck: _onLocalCheck,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.puzzleInstruction,
                textAlign: TextAlign.center,
                style: t.bodySecondary.copyWith(fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _nextRound,
                child: Text('skip → next seed',
                    style: t.bodySecondary.copyWith(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(WiltkeyTokens t, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: t.dataMono.copyWith(fontSize: 14, color: color)),
        Text(label.toUpperCase(),
            style: t.dataMono.copyWith(fontSize: 8, color: t.textTertiary)),
      ],
    );
  }
}
