import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/auth/biometric_auth.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/pixel_art_editor.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/localization/locale_controller.dart';
import 'widgets/theme_picker.dart';

/// Shown in the Settings "About" footer. [kAppVersion] tracks the marketing
/// version in pubspec.yaml — bump both together. This 1.0.0 is the first
/// semi-stable public release.
const String kAppVersion = '1.0.0';
const String kAppPublisher = 'ArtFacility';

class SettingsScreen extends StatefulWidget {
  /// When true the screen is hosted inside the app shell as a tab: it drops its
  /// own back button (there's nothing to pop) but keeps its title + tab bar.
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final AppState _appState = AppState();
  late TabController _tabController;

  // Profile fields controllers
  late TextEditingController _usernameController;
  late TextEditingController _shortNickController;

  // Network fields controllers
  late TextEditingController _relayController;
  late bool _useDevRelay;

  // Avatar grid (100-char hex); edited via the shared popup editor.
  late List<String> _pixelGrid;

  // Debounced Save Indicator State
  Timer? _debounceTimer;
  Timer? _hideIndicatorTimer;
  bool _showSaveIndicator = false;

  // Whether the device has usable biometrics (gates the fingerprint toggle).
  bool _biometricAvailable = false;
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _appState.addListener(_updateStateFromModel);

    BiometricAuth.isAvailable().then((available) {
      if (mounted) setState(() => _biometricAvailable = available);
    });

    _usernameController = TextEditingController(text: _appState.deviceName);
    _shortNickController = TextEditingController(text: _appState.shortNick);
    _relayController = TextEditingController(text: _appState.localDevRelayUrl);
    _useDevRelay = _appState.useLocalDevRelay;

    final hex =
        _appState.profileImageB64.length == 100 &&
            _isValidHex(_appState.profileImageB64)
        ? _appState.profileImageB64
        : PixelArtAvatar.generateIdenticon(_appState.userId);
    _pixelGrid = hex.split('');
  }

  bool _isValidHex(String hex) {
    return RegExp(r'^[0-9a-fA-F]{100}$').hasMatch(hex);
  }

  void _updateStateFromModel() {
    if (mounted) {
      setState(() {
        _useDevRelay = _appState.useLocalDevRelay;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideIndicatorTimer?.cancel();
    _appState.removeListener(_updateStateFromModel);
    _tabController.dispose();
    _usernameController.dispose();
    _shortNickController.dispose();
    _relayController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final name = _usernameController.text.trim();
    final nick = _shortNickController.text.trim().toUpperCase();
    final imageHex = _pixelGrid.join();

    // Save locally on every change (so the UI is live), but defer the network
    // announce until edits settle — otherwise each drawn pixel / typed letter
    // would push an update to every peer and group member.
    _appState.updateProfile(name: name, nick: nick, imageB64: imageHex);

    _debounceTimer?.cancel();
    _hideIndicatorTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        // One announce to all 1-on-1 peers and group members.
        _appState.broadcastProfileUpdate();
        setState(() {
          _showSaveIndicator = true;
        });

        _hideIndicatorTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _showSaveIndicator = false;
            });
          }
        });
      }
    });
  }

  Future<void> _editAvatar() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showPixelArtEditor(
      context,
      initialHex: _pixelGrid.join(),
      title: l10n.settingsProfileSectionAvatar,
      identiconSeed: _appState.userId,
      defaultColorIndex: 1,
    );
    if (result != null) {
      setState(() => _pixelGrid = result.split(''));
      // Save locally + one debounced announce to peers and groups.
      _saveProfile();
    }
  }

  void _confirmResetIdentity() {
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
              Icon(Icons.warning_amber_rounded, color: t.danger, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.uppercaseLabels
                      ? l10n.settingsResetConfirmTitle.toUpperCase()
                      : l10n.settingsResetConfirmTitle,
                  style: t.screenTitle.copyWith(color: t.danger, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            l10n.settingsResetConfirmBody,
            style: t.bodySecondary.copyWith(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.settingsResetConfirmCancel,
                style: TextStyle(color: t.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _appState.resetApp(); // Reset identity
                if (!widget.embedded)
                  Navigator.pop(context); // Exit settings if pushed
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
              child: Text(l10n.settingsResetConfirmReset),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onBiometricToggle(bool enable) async {
    setState(() => _biometricBusy = true);
    if (enable) {
      final ok = await _appState.enableBiometricUnlock();
      if (!ok && mounted) {
        final t = context.wk;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: t.surface,
            content: Text(
              l10n.settingsBiometricFailedSnackBar,
              style: TextStyle(color: t.danger),
            ),
          ),
        );
      }
    } else {
      await _appState.disableBiometricUnlock();
    }
    if (mounted) setState(() => _biometricBusy = false);
  }

  void _showChangePinDialog() {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String error = '';

    InputDecoration pinField() => InputDecoration(
      filled: true,
      fillColor: t.bg,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radiusControl),
        borderSide: BorderSide(color: t.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radiusControl),
        borderSide: BorderSide(color: t.action),
      ),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return AlertDialog(
              backgroundColor: t.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusCard),
                side: BorderSide(color: t.positive, width: 1.5),
              ),
              title: Row(
                children: [
                  Icon(Icons.lock_outline, color: t.action, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.uppercaseLabels
                          ? l10n.settingsChangePinTitle.toUpperCase()
                          : l10n.settingsChangePinTitle,
                      style: t.screenTitle.copyWith(fontSize: 15),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsChangePinOldPin, style: t.bodySecondary),
                  const SizedBox(height: 6),
                  TextField(
                    controller: oldPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: t.dataMono.copyWith(
                      color: t.textPrimary,
                      fontSize: 12,
                      letterSpacing: 2.0,
                    ),
                    maxLength: 6,
                    decoration: pinField(),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.settingsChangePinNewPin, style: t.bodySecondary),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: t.dataMono.copyWith(
                      color: t.textPrimary,
                      fontSize: 12,
                      letterSpacing: 2.0,
                    ),
                    maxLength: 6,
                    decoration: pinField(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.settingsChangePinConfirmPin,
                    style: t.bodySecondary,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: t.dataMono.copyWith(
                      color: t.textPrimary,
                      fontSize: 12,
                      letterSpacing: 2.0,
                    ),
                    maxLength: 6,
                    decoration: pinField(),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      error,
                      style: t.bodySecondary.copyWith(
                        color: t.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    oldPinController.dispose();
                    newPinController.dispose();
                    confirmPinController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    l10n.commonCancel,
                    style: TextStyle(color: t.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final oldPin = oldPinController.text;
                    final newPin = newPinController.text;
                    final confirm = confirmPinController.text;

                    if (oldPin.isEmpty || newPin.isEmpty || confirm.isEmpty) {
                      setDialogState(
                        () => error = l10n.settingsChangePinEmptyFieldsError,
                      );
                      return;
                    }
                    if (newPin.length < 4 || newPin.length > 6) {
                      setDialogState(
                        () => error = l10n.settingsChangePinLengthError,
                      );
                      return;
                    }
                    if (newPin != confirm) {
                      setDialogState(
                        () => error = l10n.settingsChangePinMatchError,
                      );
                      return;
                    }

                    final bool success = await _appState.changePin(
                      oldPin,
                      newPin,
                    );
                    if (success) {
                      oldPinController.dispose();
                      newPinController.dispose();
                      confirmPinController.dispose();
                      if (mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
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
                    } else {
                      setDialogState(
                        () => error = l10n.settingsChangePinIncorrectError,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.action,
                    foregroundColor: t.onAction,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                    ),
                  ),
                  child: Text(l10n.settingsProfileChangePinButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back, color: t.action),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          t.uppercaseLabels
              ? l10n.settingsTitle.toUpperCase()
              : l10n.settingsTitle,
          style: t.screenTitle.copyWith(fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: t.action,
          labelColor: t.action,
          unselectedLabelColor: t.textTertiary,
          labelStyle: t.sectionLabel.copyWith(fontSize: 11),
          tabs: [
            Tab(
              icon: const Icon(Icons.person, size: 20),
              text: t.uppercaseLabels
                  ? l10n.settingsTabProfile.toUpperCase()
                  : l10n.settingsTabProfile,
            ),
            Tab(
              icon: const Icon(Icons.wifi, size: 20),
              text: t.uppercaseLabels
                  ? l10n.settingsTabNetwork.toUpperCase()
                  : l10n.settingsTabNetwork,
            ),
            Tab(
              icon: const Icon(Icons.notifications, size: 20),
              text: t.uppercaseLabels
                  ? l10n.settingsTabAlerts.toUpperCase()
                  : l10n.settingsTabAlerts,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildProfileTab(t, l10n),
              _buildNetworkTab(t, l10n),
              _buildNotificationsTab(t, l10n),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: AnimatedOpacity(
              opacity: _showSaveIndicator ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border.all(color: t.action, width: 1.0),
                  borderRadius: BorderRadius.circular(t.radiusControl),
                  boxShadow: t.glow(t.action),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, color: t.action, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      t.uppercaseLabels
                          ? l10n.settingsSavedIndicator.toUpperCase()
                          : l10n.settingsSavedIndicator,
                      style: t.dataMono.copyWith(
                        color: t.action,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(WiltkeyTokens t, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Appearance / theme picker (real, live-preview cards).
          _section(t, l10n.settingsProfileSectionAppearance),
          const SizedBox(height: 8),
          const ThemePicker(),
          const SizedBox(height: 16),
          Text(
            l10n.settingsLanguageLabel,
            style: t.dataMono.copyWith(
              color: t.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: LocaleController().locale?.languageCode ?? 'system',
                dropdownColor: t.surface,
                icon: Icon(Icons.arrow_drop_down, color: t.action),
                style: t.body.copyWith(color: t.textPrimary),
                isExpanded: true,
                onChanged: (String? value) {
                  if (value != null) {
                    LocaleController().setLocale(
                      value == 'system' ? null : value,
                    );
                  }
                },
                items: [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text(l10n.settingsLanguageSystem),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Text(l10n.settingsLanguageEnglish),
                  ),
                  DropdownMenuItem(
                    value: 'hu',
                    child: Text(l10n.settingsLanguageHungarian),
                  ),
                  DropdownMenuItem(
                    value: 'pl',
                    child: Text(l10n.settingsLanguagePolish),
                  ),
                  DropdownMenuItem(
                    value: 'de',
                    child: Text(l10n.settingsLanguageGerman),
                  ),
                  DropdownMenuItem(
                    value: 'fr',
                    child: Text(l10n.settingsLanguageFrench),
                  ),
                  DropdownMenuItem(
                    value: 'sv',
                    child: Text(l10n.settingsLanguageSwedish),
                  ),
                  DropdownMenuItem(
                    value: 'zh',
                    child: Text(l10n.settingsLanguageChinese),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Chat text size — scales message text (and inline emoji) everywhere.
          Text(
            l10n.settingsTextSizeLabel,
            style: t.dataMono.copyWith(
              color: t.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: t.bubbleThem,
                      border: Border.all(
                        color: t.bubbleThemBorder,
                        width: t.borderWidth,
                      ),
                      borderRadius: BorderRadius.circular(t.radiusCard),
                    ),
                    child: Text(
                      l10n.settingsTextSizePreview,
                      style: t.body.copyWith(
                        fontSize: 13 * _appState.chatTextScale,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'A',
                      style: t.body.copyWith(
                        fontSize: 12,
                        color: t.textTertiary,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _appState.chatTextScale,
                        min: 0.8,
                        max: 1.6,
                        divisions: 8,
                        activeColor: t.action,
                        label: '${(_appState.chatTextScale * 100).round()}%',
                        onChanged: (v) =>
                            setState(() => _appState.setChatTextScale(v)),
                      ),
                    ),
                    Text(
                      'A',
                      style: t.body.copyWith(
                        fontSize: 22,
                        color: t.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _section(t, l10n.settingsProfileSectionAvatar),
          const SizedBox(height: 12),

          // Avatar preview — tap "Edit avatar" to open the shared editor popup.
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _editAvatar,
                  child: PixelArtAvatar(
                    hexString: _pixelGrid.join(),
                    size: 140,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _editAvatar,
                  icon: Icon(Icons.edit, size: 16, color: t.action),
                  label: Text(
                    t.uppercaseLabels
                        ? l10n.avatarEditButton.toUpperCase()
                        : l10n.avatarEditButton,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.action,
                    side: BorderSide(color: t.positive),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: t.border, height: 32),

          _section(t, l10n.settingsProfileSectionProfile),
          const SizedBox(height: 12),

          Text(l10n.settingsProfileUsername, style: t.bodySecondary),
          const SizedBox(height: 6),
          TextField(
            controller: _usernameController,
            style: t.body.copyWith(fontSize: 13),
            decoration: _inputDecoration(t),
            onChanged: (_) => _saveProfile(),
          ),
          const SizedBox(height: 16),

          Text(l10n.settingsProfileBleNick, style: t.bodySecondary),
          const SizedBox(height: 6),
          TextField(
            controller: _shortNickController,
            style: t.dataMono.copyWith(color: t.textPrimary, fontSize: 13),
            maxLength: 5,
            inputFormatters: [
              LengthLimitingTextInputFormatter(5),
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
            decoration: _inputDecoration(t).copyWith(
              counterStyle: t.dataMono.copyWith(color: t.textTertiary),
            ),
            onChanged: (val) {
              setState(() {
                _shortNickController.text = val.toUpperCase();
                _shortNickController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _shortNickController.text.length),
                );
              });
              _saveProfile();
            },
          ),
          const SizedBox(height: 8),

          Text(l10n.settingsProfileKeyhash, style: t.bodySecondary),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: t.bg,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _appState.userId,
                    style: t.dataMono.copyWith(color: t.textTertiary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _appState.userId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.settingsProfileKeyhashCopied),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(Icons.copy, color: t.action, size: 16),
                ),
              ],
            ),
          ),
          Divider(color: t.border, height: 40),

          // Optional fingerprint unlock (Android biometrics). Hidden when the
          // device has no enrolled biometrics.
          if (_biometricAvailable) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: _panel(t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.settingsBiometricToggle,
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch(
                        value: _appState.biometricUnlockEnabled,
                        activeColor: t.action,
                        onChanged: _biometricBusy ? null : _onBiometricToggle,
                      ),
                    ],
                  ),
                  Text(
                    l10n.settingsBiometricDescription,
                    style: t.bodySecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Center(
            child: OutlinedButton.icon(
              onPressed: _showChangePinDialog,
              icon: const Icon(Icons.lock_outline, size: 16),
              label: Text(l10n.settingsProfileChangePinButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.action,
                side: BorderSide(color: t.action, width: 1.5),
                minimumSize: const Size.fromHeight(45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: ElevatedButton.icon(
              onPressed: _confirmResetIdentity,
              icon: const Icon(Icons.flash_on, size: 16),
              label: Text(l10n.settingsProfileResetIdentityButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNetworkTab(WiltkeyTokens t, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(t, l10n.settingsNetworkRoutingTitle),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _panel(t),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.settingsNetworkDevRelayToggle,
                      style: t.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Switch(
                      value: _useDevRelay,
                      activeColor: t.action,
                      onChanged: (val) {
                        setState(() {
                          _useDevRelay = val;
                        });
                        _appState.updateDevRelaySettings(
                          use: _useDevRelay,
                          url: _relayController.text.trim(),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_useDevRelay) ...[
                  Text(
                    l10n.settingsNetworkDevRelayUrlLabel,
                    style: t.bodySecondary,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _relayController,
                    style: t.dataMono.copyWith(
                      color: t.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: _inputDecoration(t).copyWith(fillColor: t.bg),
                    onChanged: (val) {
                      _appState.updateDevRelaySettings(
                        use: _useDevRelay,
                        url: val.trim(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  l10n.settingsNetworkDevRelayDescription,
                  style: t.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _section(t, l10n.settingsNetworkActiveGateway),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.bg,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
            child: Text(
              _appState.activeRelayUrl,
              style: t.dataMono.copyWith(color: t.action, fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),

          // Debug console entry (moved here from the old dashboard app bar).
          _section(t, l10n.settingsNetworkDiagnostics),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            decoration: _panel(t),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.settingsDebugButtonsToggle,
                        style: t.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Switch(
                      value: _appState.showDebugButtons,
                      activeColor: t.action,
                      onChanged: (val) {
                        _appState.setShowDebugButtons(val);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                Text(
                  l10n.settingsDebugButtonsDescription,
                  style: t.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showDebugConsole(),
            icon: const Icon(Icons.terminal, size: 16),
            label: Text(l10n.settingsNetworkDebugButton),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.action,
              side: BorderSide(color: t.border),
              minimumSize: const Size.fromHeight(45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab(WiltkeyTokens t, AppLocalizations l10n) {
    final current = _appState.notificationMode;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(t, l10n.settingsAlertsBackgroundNotifications),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: _panel(t),
            child: Column(
              children: [
                for (final mode in NotificationMode.values) ...[
                  if (mode != NotificationMode.values.first)
                    Divider(color: t.border, indent: 16, endIndent: 16),
                  _modeTile(t, l10n, mode, current),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: t.textTertiary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.settingsAlertsExplanation,
                  style: t.bodySecondary.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildAboutFooter(t),
        ],
      ),
    );
  }

  // App identity footer. Uses only proper nouns (name / version / publisher) so
  // it needs no localization.
  Widget _buildAboutFooter(WiltkeyTokens t) => Center(
    child: Column(
      children: [
        Text(
          'WiltKey',
          style: t.screenTitle.copyWith(fontSize: 15, letterSpacing: 1.5),
        ),
        const SizedBox(height: 4),
        Text('v$kAppVersion · $kAppPublisher', style: t.dataMono),
      ],
    ),
  );

  Widget _modeTile(
    WiltkeyTokens t,
    AppLocalizations l10n,
    NotificationMode mode,
    NotificationMode current,
  ) {
    final selected = mode == current;
    final (String label, String description) = switch (mode) {
      NotificationMode.off => (
        l10n.notificationModeOff,
        l10n.notificationModeOffDesc,
      ),
      NotificationMode.lowPower => (
        l10n.notificationModeLowPower,
        l10n.notificationModeLowPowerDesc,
      ),
      NotificationMode.instant => (
        l10n.notificationModeInstant,
        l10n.notificationModeInstantDesc,
      ),
    };
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? t.action : t.textTertiary,
      ),
      title: Text(label, style: t.body.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(description, style: t.bodySecondary),
      onTap: selected ? null : () => _selectNotificationMode(mode),
    );
  }

  Future<void> _selectNotificationMode(NotificationMode mode) async {
    await _appState.setNotificationMode(mode);
    if (mounted) setState(() {});
  }

  void _showDebugConsole() {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.terminal, color: t.action, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            t.uppercaseLabels
                                ? l10n.settingsDebugTitle.toUpperCase()
                                : l10n.settingsDebugTitle,
                            style: t.screenTitle.copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: t.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(color: t.border),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: AppState.logRevision,
                      builder: (context, _) {
                        return ListView.builder(
                          itemCount: AppState.debugLogs.length,
                          reverse: true,
                          itemBuilder: (context, index) {
                            final logItem =
                                AppState.debugLogs[AppState.debugLogs.length -
                                    1 -
                                    index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Text(
                                logItem,
                                style: t.dataMono.copyWith(
                                  color: t.positive,
                                  fontSize: 10.5,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- small tokenized helpers ---

  Widget _section(WiltkeyTokens t, String text) => Text(
    t.uppercaseLabels ? text.toUpperCase() : text,
    style: t.sectionLabel.copyWith(color: t.action),
  );

  BoxDecoration _panel(WiltkeyTokens t) => BoxDecoration(
    color: t.surface,
    border: Border.all(color: t.border),
    borderRadius: BorderRadius.circular(t.radiusControl),
  );

  InputDecoration _inputDecoration(WiltkeyTokens t) => InputDecoration(
    filled: true,
    fillColor: t.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: t.border),
      borderRadius: BorderRadius.circular(t.radiusControl),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: t.action),
      borderRadius: BorderRadius.circular(t.radiusControl),
    ),
  );
}
