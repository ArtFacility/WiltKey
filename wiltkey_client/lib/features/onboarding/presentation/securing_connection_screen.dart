import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import 'widgets/pixel_puzzle_drag.dart';

/// Full-screen takeover shown during the FIRST-EVER device-token issuance
/// (right after onboarding, or after a wiped token at first unlock), and
/// whenever the relay demands the Phase-2 human-verification puzzle.
///
/// Explains what the relay's proof-of-work gate is doing while it runs —
/// silently waiting 1-10s felt like a hang; a legible one-time step doesn't.
class SecuringConnectionScreen extends StatelessWidget {
  const SecuringConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final appState = AppState();

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final puzzleActive = appState.wsPhase == WsPhase.humanVerification;
            final issuing = appState.wsPhase == WsPhase.issuing;
            final progress = appState.powProgress;

            if (puzzleActive &&
                appState.puzzleSeed != null &&
                appState.puzzleChallengeId != null) {
              return _PuzzlePanel(
                appState: appState,
                t: t,
                l10n: l10n,
              );
            }
            return _ProgressPanel(
              issuing: issuing,
              progress: progress,
              puzzleRejected: appState.puzzleRejected,
              t: t,
              l10n: l10n,
            );
          },
        ),
      ),
    );
  }
}

class _PuzzlePanel extends StatelessWidget {
  final AppState appState;
  final WiltkeyTokens t;
  final AppLocalizations l10n;

  const _PuzzlePanel({
    required this.appState,
    required this.t,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Icon(Icons.verified_user_outlined, size: 44, color: t.action),
          const SizedBox(height: 14),
          Text(
            t.uppercaseLabels
                ? l10n.securingTitle.toUpperCase()
                : l10n.securingTitle,
            textAlign: TextAlign.center,
            style: t.screenTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.puzzleInstruction,
            textAlign: TextAlign.center,
            style: t.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),
          PixelPuzzleDrag(
            key: ValueKey(appState.puzzleChallengeId),
            seed: appState.puzzleSeed!,
            strips: appState.puzzleStrips,
            onSubmit: appState.submitPuzzleAnswer,
          ),
          if (appState.puzzleRejected) ...[
            const SizedBox(height: 14),
            Text(
              l10n.puzzleFailedRetry,
              textAlign: TextAlign.center,
              style: t.bodySecondary.copyWith(color: t.warning, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final bool issuing;
  final double progress;
  final bool puzzleRejected;
  final WiltkeyTokens t;
  final AppLocalizations l10n;

  const _ProgressPanel({
    required this.issuing,
    required this.progress,
    required this.puzzleRejected,
    required this.t,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: t.action),
            const SizedBox(height: 24),
            Text(
              t.uppercaseLabels
                  ? l10n.securingTitle.toUpperCase()
                  : l10n.securingTitle,
              textAlign: TextAlign.center,
              style: t.screenTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.securingBody,
              textAlign: TextAlign.center,
              style: t.bodySecondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(
                value: issuing && progress > 0 ? progress : null,
                minHeight: 5,
                backgroundColor: t.surface,
                valueColor: AlwaysStoppedAnimation(t.action),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              puzzleRejected ? l10n.puzzleFailedRetry : l10n.securingWorking,
              style: t.dataMono.copyWith(
                color: puzzleRejected ? t.warning : t.textTertiary,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: t.positive.withValues(alpha: 0.08),
                border:
                    Border.all(color: t.positive.withValues(alpha: 0.2)),
                borderRadius:
                    BorderRadius.circular(t.radiusControl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_outlined,
                      size: 14, color: t.positive),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.securingOnceNote,
                      style: t.dataMono.copyWith(
                        color: t.positive,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
