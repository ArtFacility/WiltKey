import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/core/network/puzzle.dart';
import 'package:wiltkey_client/core/pixel_art_avatar.dart';
import 'package:wiltkey_client/core/theme/wk.dart';
import 'package:wiltkey_client/core/theme/wiltkey_tokens.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

/// The Phase-2 human-verification puzzle: a strip-slide drag.
///
/// A seed-derived 10×10 pixel sprite is shown sliced into [strips] vertical
/// strips and rotated by k (derived from the seed, same function the relay
/// verifies). The user slides until the picture locks in, then presses the
/// explicit Lock-in button — which submits the user rotation u. The explicit
/// confirm matters: wrong answers burn relay-side strikes.
///
/// Two modes:
///  - [onSubmit] set → LIVE: submits through the websocket dance.
///  - [localCheck] set → TESTER: verifies locally against the mirror
///    function (the debug puzzle tester / endless PC practice loop).
class PixelPuzzleDrag extends StatefulWidget {
  final String seed;
  final int strips;
  final void Function(int answer)? onSubmit;
  final void Function(bool correct)? localCheck;

  const PixelPuzzleDrag({
    super.key,
    required this.seed,
    this.strips = 5,
    this.onSubmit,
    this.localCheck,
  }) : assert(onSubmit != null || localCheck != null);

  @override
  State<PixelPuzzleDrag> createState() => _PixelPuzzleDragState();
}

class _PixelPuzzleDragState extends State<PixelPuzzleDrag> {
  late int _strips;
  late int _displayRotation; // k — how the sprite arrives scrambled
  int _userOffset = 0; // u — what the user drags to, and what gets submitted
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant PixelPuzzleDrag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed || oldWidget.strips != widget.strips) {
      _setup();
    }
  }

  void _setup() {
    _strips = widget.strips < 1 ? 1 : widget.strips;
    _displayRotation = stripRotationFromSeed(widget.seed, _strips);
    _userOffset = 0;
    _touched = false;
  }

  String get _displayedSprite {
    final base = puzzleSpriteFromSeed(widget.seed);
    // Relay-side rendering: the base sprite rotated by k, further rotated by
    // the user's offset. Locked in when (k + u) ≡ 0 (mod strips).
    final total = (_displayRotation + _userOffset) % _strips;
    return rotateSpriteStrips(base, _strips, total);
  }

  bool get _solvedLocally =>
      expectedUserAnswer(widget.seed, _strips) ==
      _userOffset % _strips;

  void _submit() {
    HapticFeedback.mediumImpact();
    if (widget.localCheck != null) {
      widget.localCheck!(_solvedLocally);
      return;
    }
    widget.onSubmit?.call(_userOffset % _strips);
  }

  void _nudge(int delta) {
    setState(() {
      _userOffset = (_userOffset + delta) % _strips;
      if (_userOffset < 0) _userOffset += _strips;
      _touched = true;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final sprite = _displayedSprite;
    // Solved-state styling exists ONLY in the tester (localCheck) mode. In
    // live mode a pre-submit "this is correct" border would be a visual
    // oracle: a screenshot-loop bot could step the slider and watch for it
    // instead of ever having to judge symmetry.
    final solved =
        widget.localCheck != null && _touched && _solvedLocally;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sprite — rendered with the shared pixel-art palette.
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(
              color: solved ? t.positive : t.border,
              width: solved ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(t.radiusControl),
          ),
          child: PixelArtAvatar(hexString: sprite, size: 180),
        ),
        const SizedBox(height: 16),

        // Drag control: slider (divisions = strips) + fine steppers.
        Row(
          children: [
            _NudgeButton(t, icon: Icons.remove, onTap: () => _nudge(-1)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: t.action,
                  inactiveTrackColor: t.border,
                  thumbColor: t.action,
                  overlayColor: t.action.withValues(alpha: 0.15),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _userOffset.toDouble(),
                  min: 0,
                  max: (_strips - 1).toDouble(),
                  // One snap point per answer (divisions = max, not count).
                  divisions: _strips - 1,
                  onChanged: (v) => setState(() {
                    _userOffset = v.round();
                    _touched = true;
                  }),
                ),
              ),
            ),
            _NudgeButton(t, icon: Icons.add, onTap: () => _nudge(1)),
          ],
        ),
        const SizedBox(height: 14),

        // Explicit confirm — never auto-submit; wrong answers burn strikes.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _touched ? t.action : t.textTertiary.withValues(alpha: 0.2),
              foregroundColor: _touched ? t.onAction : t.textTertiary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _touched ? _submit : null,
            icon: const Icon(Icons.lock_outline, size: 16),
            label: Text(
              l10n.puzzleLockIn,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final WiltkeyTokens t;
  final IconData icon;
  final VoidCallback onTap;

  const _NudgeButton(this.t, {required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(t.radiusControl),
        ),
        child: Icon(icon, size: 18, color: t.textSecondary),
      ),
    );
  }
}
