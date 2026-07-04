import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/state.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Two-step PIN change: verify the current PIN on its own screen, then set the
/// new one. Replaces the old cramped 3-field dialog whose confirm field could
/// overlap the submit button on small screens. The submit button lives in a
/// bottom bar (SafeArea) and the body scrolls, so it can never be occluded.
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final AppState _appState = AppState();

  // 0 = verify current PIN, 1 = set new PIN.
  int _step = 0;
  bool _busy = false;
  String _error = '';

  final TextEditingController _currentCtrl = TextEditingController();
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  final FocusNode _currentFocus = FocusNode();
  final FocusNode _newFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _currentFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _onPrimary(AppLocalizations l10n) async {
    if (_busy) return;
    if (_step == 0) {
      final pin = _currentCtrl.text;
      if (pin.length < 4) {
        setState(() => _error = l10n.settingsChangePinLengthError);
        return;
      }
      setState(() => _busy = true);
      final ok = await _appState.verifyPin(pin);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) {
        setState(() => _error = l10n.settingsChangePinIncorrectError);
        return;
      }
      setState(() {
        _error = '';
        _step = 1;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _newFocus.requestFocus(),
      );
      return;
    }

    // Step 1: set the new PIN.
    final newPin = _newCtrl.text;
    final confirm = _confirmCtrl.text;
    if (newPin.length < 4 || newPin.length > 6) {
      setState(() => _error = l10n.settingsChangePinLengthError);
      return;
    }
    if (newPin != confirm) {
      setState(() => _error = l10n.settingsChangePinMatchError);
      return;
    }
    setState(() => _busy = true);
    final success = await _appState.changePin(_currentCtrl.text, newPin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!success) {
      // The current PIN was already verified in step 0; a failure here means it
      // changed underneath us — send the user back to re-verify.
      setState(() {
        _error = l10n.settingsChangePinIncorrectError;
        _step = 0;
        _newCtrl.clear();
        _confirmCtrl.clear();
      });
      return;
    }
    // Capture the messenger + tokens BEFORE popping — this route's context is
    // defunct once popped, and the snackbar must show on the parent.
    final t = context.wk;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: t.surface,
        content: Text(
          l10n.settingsChangePinUpdatedSnackBar,
          style: t.bodySecondary.copyWith(
            color: t.action,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _onBack() {
    if (_step == 1) {
      setState(() {
        _step = 0;
        _error = '';
        _newCtrl.clear();
        _confirmCtrl.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _currentFocus.requestFocus(),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final isSetStep = _step == 1;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.action),
          onPressed: _onBack,
        ),
        title: Text(
          t.uppercaseLabels
              ? l10n.settingsChangePinTitle.toUpperCase()
              : l10n.settingsChangePinTitle,
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator dots.
              Row(
                children: List.generate(2, (i) {
                  final active = i == _step;
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? t.action : t.surfacePressed,
                      boxShadow: active ? t.glow(t.action) : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Text(
                t.uppercaseLabels
                    ? (isSetStep
                          ? l10n.changePinSetTitle.toUpperCase()
                          : l10n.changePinVerifyTitle.toUpperCase())
                    : (isSetStep
                          ? l10n.changePinSetTitle
                          : l10n.changePinVerifyTitle),
                style: t.sectionLabel.copyWith(color: t.action, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Text(
                isSetStep
                    ? l10n.onboardingPinExplanation
                    : l10n.changePinVerifyPrompt,
                style: t.bodySecondary.copyWith(height: 1.5),
              ),
              const SizedBox(height: 24),

              if (!isSetStep) ...[
                Text(l10n.settingsChangePinOldPin, style: t.bodySecondary),
                const SizedBox(height: 8),
                _pinDots(t, _currentCtrl, _currentFocus,
                    action: TextInputAction.done,
                    onSubmitted: () => _onPrimary(l10n)),
              ] else ...[
                Text(l10n.settingsChangePinNewPin, style: t.bodySecondary),
                const SizedBox(height: 8),
                _pinDots(t, _newCtrl, _newFocus,
                    action: TextInputAction.next,
                    onSubmitted: () => _confirmFocus.requestFocus()),
                const SizedBox(height: 18),
                Text(l10n.settingsChangePinConfirmPin, style: t.bodySecondary),
                const SizedBox(height: 8),
                _pinDots(t, _confirmCtrl, _confirmFocus,
                    action: TextInputAction.done,
                    onSubmitted: () => _onPrimary(l10n)),
              ],

              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _error,
                  style: t.bodySecondary.copyWith(
                    color: t.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: ElevatedButton(
          onPressed: _busy ? null : () => _onPrimary(l10n),
          style: ElevatedButton.styleFrom(
            backgroundColor: t.action,
            foregroundColor: t.onAction,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
          ),
          child: _busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(t.onAction),
                  ),
                )
              : Text(
                  isSetStep
                      ? l10n.settingsProfileChangePinButton
                      : l10n.commonContinue,
                ),
        ),
      ),
    );
  }

  // Dot-style PIN entry: an invisible numeric field behind six dots, tap-anywhere
  // to focus. Mirrors the onboarding PIN input.
  Widget _pinDots(
    WiltkeyTokens t,
    TextEditingController controller,
    FocusNode focusNode, {
    required TextInputAction action,
    required VoidCallback onSubmitted,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              textInputAction: action,
              onSubmitted: (_) => onSubmitted(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
              onChanged: (_) => setState(() => _error = ''),
            ),
          ),
          IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              width: double.infinity,
              decoration: BoxDecoration(
                color: t.surface,
                border: Border.all(color: t.border, width: 1.0),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final hasDigit = index < controller.text.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasDigit ? t.action : Colors.transparent,
                      border: Border.all(
                        color: hasDigit
                            ? t.action
                            : t.positive.withValues(alpha: 0.5),
                        width: 2.0,
                      ),
                      boxShadow: hasDigit ? t.glow(t.action) : null,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
