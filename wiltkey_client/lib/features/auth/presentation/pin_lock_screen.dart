import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';

class PinLockScreen extends StatefulWidget {
  /// Verifies the entered PIN. Defaults to [AppState.unlockApp]; overridable so
  /// the dev showcase / tests can drive the screen without the database.
  final Future<bool> Function(String pin)? onVerify;

  /// The destructive identity reset. Defaults to [AppState.resetApp]; overridable
  /// for the same reason.
  final VoidCallback? onReset;

  const PinLockScreen({super.key, this.onVerify, this.onReset});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with TickerProviderStateMixin {
  final AppState _appState = AppState();
  String _pin = '';
  bool _isVerifying = false;
  String _errorMessage = '';
  int _remainingAttempts = 5;

  // Shake animation controllers for incorrect pin entry
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController =
        AnimationController(
          duration: const Duration(milliseconds: 400),
          vsync: this,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _shakeController.reverse();
          }
        });
  }

  bool _warmedUnlock = false;
  bool _biometricAttempted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Warm up the active theme's unlock animation while the user is still
    // entering their PIN, so its first play is smooth (no-op for most themes).
    if (!_warmedUnlock) {
      _warmedUnlock = true;
      context.wkc.precacheUnlock(context);
    }
    // Offer fingerprint immediately when allowed (opted in + within the 4h idle
    // window). The OS prompt pops on open; cancelling just falls back to the PIN.
    if (!_biometricAttempted &&
        widget.onVerify == null &&
        _appState.biometricAllowedNow()) {
      _biometricAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryBiometric();
      });
    }
  }

  /// Captures the overlay/theme synchronously and returns a closure that starts
  /// the theme's unlock animation (used by both the PIN and biometric paths).
  /// The root overlay persists across the PinLockScreen→AppShell swap so the
  /// animation can cross-fade over the freshly-mounted shell.
  VoidCallback _buildUnlockAnimStarter() {
    final overlay = Overlay.of(context, rootOverlay: true);
    final wkc = context.wkc;
    final themeData = Theme.of(context);
    late OverlayEntry entry;
    return () {
      entry = OverlayEntry(
        builder: (_) => Positioned.fill(
          child: Theme(
            data: themeData,
            child: wkc.unlockTransition(onDone: () => entry.remove()),
          ),
        ),
      );
      overlay.insert(entry);
    };
  }

  Future<void> _tryBiometric() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);
    final startUnlockAnim = _buildUnlockAnimStarter();
    final ok = await _appState.unlockWithBiometrics(
      onValidated: startUnlockAnim,
    );
    if (ok) return; // the screen is being torn down; the overlay owns teardown
    if (mounted) setState(() => _isVerifying = false);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    if (_isVerifying) return;
    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
        _errorMessage = '';
      });

      if (_pin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_isVerifying) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = '';
      });
    }
  }

  void _onClear() {
    if (_isVerifying) return;
    setState(() {
      _pin = '';
      _errorMessage = '';
    });
  }

  Future<void> _verifyPin() async {
    final l10n = AppLocalizations.of(context)!;
    if (_pin.length < 4) {
      setState(() {
        _errorMessage = l10n.pinMinLengthError;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    // The unlock animation starts opaque, so launching it the moment the PIN is
    // validated turns it into the loading cover over the (slower) data decrypt AND
    // the PinLockScreen→AppShell swap — no flash of the previously-open screen.
    final startUnlockAnim = _buildUnlockAnimStarter();

    // Real unlock fires the animation at validation time (before the heavy load).
    // An injected verifier (dev showcase) has no such hook, so animate on success.
    final verify = widget.onVerify;
    final bool success = verify != null
        ? await verify(_pin)
        : await _appState.unlockApp(_pin, onValidated: startUnlockAnim);

    if (success) {
      if (verify != null) startUnlockAnim();
      return; // the screen is being torn down; the overlay owns teardown
    }

    if (mounted) {
      setState(() {
        _isVerifying = false;
      });
      _shakeController.forward(from: 0.0);
      _remainingAttempts--;
      if (_remainingAttempts <= 0) {
        final t = context.wk;
        (widget.onReset ?? _appState.resetApp)();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: t.surface,
            content: Text(
              l10n.pinMaxAttemptsExceeded,
              style: t.dataMono.copyWith(
                color: t.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else {
        setState(() {
          _pin = '';
          _errorMessage = l10n.pinAccessDenied(_remainingAttempts);
        });
      }
    }
  }

  void _confirmSelfDestruct() {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusCard),
            side: BorderSide(color: t.danger, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: t.danger, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.uppercaseLabels
                      ? l10n.pinPurgeConfirmTitle.toUpperCase()
                      : l10n.pinPurgeConfirmTitle,
                  style: t.screenTitle.copyWith(color: t.danger, fontSize: 15),
                ),
              ),
            ],
          ),
          content: Text(
            l10n.pinPurgeConfirmBody,
            style: t.bodySecondary.copyWith(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.commonCancel,
                style: TextStyle(color: t.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                (widget.onReset ??
                    _appState.resetApp)(); // Reset identity → Onboarding
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
              child: Text(l10n.pinPurgeConfirmButton),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final double shakeOffset =
        _shakeController.value * sin(_shakeController.value * 10 * pi);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            Icon(Icons.lock_outline, color: t.danger, size: 36),
            const SizedBox(height: 16),
            Text(
              t.uppercaseLabels
                  ? l10n.pinLockedTitle.toUpperCase()
                  : l10n.pinLockedTitle,
              style: t.screenTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              t.uppercaseLabels
                  ? l10n.pinLockedSubtitle.toUpperCase()
                  : l10n.pinLockedSubtitle,
              style: t.bodySecondary,
            ),

            const Spacer(flex: 1),

            // PIN progress (theme-specific: cyberpunk dots / garden entry flower).
            Transform.translate(
              offset: Offset(shakeOffset, 0),
              child: Column(
                children: [
                  context.wkc.pinProgress(
                    context,
                    entered: _pin.length,
                    length: 6,
                    error: _errorMessage.isNotEmpty,
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: t.dataMono.copyWith(
                        color: t.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKey(t, '1'),
                      _buildKey(t, '2'),
                      _buildKey(t, '3'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKey(t, '4'),
                      _buildKey(t, '5'),
                      _buildKey(t, '6'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKey(t, '7'),
                      _buildKey(t, '8'),
                      _buildKey(t, '9'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionKey(
                        t,
                        icon: Icons.clear,
                        onPressed: _onClear,
                        tooltip: 'Clear',
                      ),
                      _buildKey(t, '0'),
                      _buildActionKey(
                        t,
                        icon: Icons.backspace_outlined,
                        onPressed: _onBackspace,
                        tooltip: 'Backspace',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Fingerprint affordance: lets the user re-trigger the biometric
            // prompt if they dismissed the auto-prompt. Only shown when allowed.
            if (widget.onVerify == null && _appState.biometricAllowedNow())
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: TextButton.icon(
                  onPressed: _isVerifying ? null : _tryBiometric,
                  icon: Icon(Icons.fingerprint, size: 18, color: t.action),
                  label: Text(
                    t.uppercaseLabels
                        ? l10n.pinUseFingerprintButton.toUpperCase()
                        : l10n.pinUseFingerprintButton,
                    style: t.dataMono.copyWith(
                      color: t.action,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            Visibility(
              visible: _pin.length >= 4 && !_isVerifying,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextButton.icon(
                  onPressed: _verifyPin,
                  icon: Icon(Icons.vpn_key, size: 14, color: t.action),
                  label: Text(
                    t.uppercaseLabels
                        ? l10n.pinUnlockButton.toUpperCase()
                        : l10n.pinUnlockButton,
                    style: t.dataMono.copyWith(
                      color: t.action,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: TextButton(
                onPressed: _confirmSelfDestruct,
                style: TextButton.styleFrom(foregroundColor: t.danger),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_forever, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      t.uppercaseLabels
                          ? l10n.pinForgotButton.toUpperCase()
                          : l10n.pinForgotButton,
                      style: t.dataMono.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(WiltkeyTokens t, String digit) {
    return _PinKeypadKey(t: t, digit: digit, onTap: () => _onKeyPress(digit));
  }

  Widget _buildActionKey(
    WiltkeyTokens t, {
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return _PinKeypadActionKey(
      t: t,
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

class _PinKeypadKey extends StatefulWidget {
  final WiltkeyTokens t;
  final String digit;
  final VoidCallback onTap;

  const _PinKeypadKey({
    required this.t,
    required this.digit,
    required this.onTap,
  });

  @override
  State<_PinKeypadKey> createState() => _PinKeypadKeyState();
}

class _PinKeypadKeyState extends State<_PinKeypadKey>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _rotation = 0.0;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() {
      _rotation = (_random.nextDouble() * 4.0 - 2.0) * pi / 180.0;
    });
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final isPaperink =
        context.wkc.runtimeType.toString() == 'PaperinkComponents';

    if (!isPaperink) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: t.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: t.positive.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            splashColor: t.positive.withValues(alpha: 0.22),
            highlightColor: t.positive.withValues(alpha: 0.10),
            onTap: widget.onTap,
            child: Center(
              child: Text(
                widget.digit,
                style: t.dataMono.copyWith(
                  color: t.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final val = _controller.value;
          final scale = 1.0 - 0.08 * val;
          final rot = _rotation * val;

          return Transform.translate(
            offset: Offset(0, 1.0 * val),
            child: Transform.rotate(
              angle: rot,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(0, 0, scale)
                  ..setEntry(1, 1, scale),
                child: child,
              ),
            ),
          );
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: t.bgRaised,
            shape: BoxShape.circle,
            border: Border.all(
              color: t.action.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Opacity(
                    opacity: _controller.value * 0.12,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.action,
                      ),
                    ),
                  );
                },
              ),
              Center(
                child: Text(
                  widget.digit,
                  style: t.screenTitle.copyWith(
                    color: t.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinKeypadActionKey extends StatefulWidget {
  final WiltkeyTokens t;
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _PinKeypadActionKey({
    required this.t,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  State<_PinKeypadActionKey> createState() => _PinKeypadActionKeyState();
}

class _PinKeypadActionKeyState extends State<_PinKeypadActionKey>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _rotation = 0.0;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() {
      _rotation = (_random.nextDouble() * 4.0 - 2.0) * pi / 180.0;
    });
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onPressed();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final isPaperink =
        context.wkc.runtimeType.toString() == 'PaperinkComponents';

    if (!isPaperink) {
      return SizedBox(
        width: 60,
        height: 60,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: widget.onPressed,
            child: Tooltip(
              message: widget.tooltip,
              child: Center(
                child: Icon(widget.icon, color: t.textSecondary, size: 20),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final val = _controller.value;
          final scale = 1.0 - 0.08 * val;
          final rot = _rotation * val;

          return Transform.translate(
            offset: Offset(0, 1.0 * val),
            child: Transform.rotate(
              angle: rot,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(0, 0, scale)
                  ..setEntry(1, 1, scale),
                child: child,
              ),
            ),
          );
        },
        child: Container(
          width: 60,
          height: 60,
          color: Colors.transparent,
          child: Tooltip(
            message: widget.tooltip,
            child: Center(
              child: Icon(widget.icon, color: t.textSecondary, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
