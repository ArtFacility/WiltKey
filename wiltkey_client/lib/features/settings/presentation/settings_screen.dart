import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/build_flavor.dart';
import '../../../core/state.dart';
import '../../../core/auth/biometric_auth.dart';
import '../../../core/debug_clipboard.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/persistence.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/pixel_art_editor.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_registry.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/entitlements/entitlement_service.dart';
import '../../../core/cosmetics/avatar_border_controller.dart';
import '../../shop/presentation/shop_screen.dart';
import 'widgets/border_picker.dart';
import 'theme_selector_screen.dart';
import 'change_pin_screen.dart';
import '../../../core/update/update_service.dart';

/// Publisher shown in the Settings "About" footer. The version string itself is
/// read from the build at runtime (package_info_plus), so pubspec.yaml's
/// `version:` is the single source of truth — nothing to keep in sync here.
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

  // App version string ("v1.0.0 (1)") read from the build at runtime.
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _appState.addListener(_updateStateFromModel);
    // Equipping/removing an avatar border is a profile change → announce it to
    // peers (like editing the avatar or nick), so their copy of us updates.
    AvatarBorderController.instance.addListener(_onBorderChanged);

    BiometricAuth.isAvailable().then((available) {
      if (mounted) setState(() => _biometricAvailable = available);
    });

    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _appVersion = 'v${info.version} (${info.buildNumber})');
      }
    });

    _usernameController = TextEditingController(text: _appState.deviceName);
    _shortNickController = TextEditingController(text: _appState.shortNick);
    _relayController = TextEditingController(text: _appState.localDevRelayUrl);
    _useDevRelay = _appState.useLocalDevRelay;

    final hex = PixelArtEditor.isValidHex(_appState.profileImageB64)
        ? _appState.profileImageB64
        : PixelArtAvatar.generateIdenticon(_appState.userId);
    _pixelGrid = hex.split('');
  }

  void _updateStateFromModel() {
    if (mounted) {
      setState(() {
        _useDevRelay = _appState.useLocalDevRelay;
      });
    }
  }

  void _onBorderChanged() => _appState.broadcastProfileUpdate();

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideIndicatorTimer?.cancel();
    _appState.removeListener(_updateStateFromModel);
    AvatarBorderController.instance.removeListener(_onBorderChanged);
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

  Future<void> _openTemplateSelector() async {
    final l10n = AppLocalizations.of(context)!;
    final t = context.wk;
    final templates = (await WiltkeyPersistence().loadAvatarTemplates()).toList();

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
        side: BorderSide(color: t.border),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.uppercaseLabels
                            ? l10n.settingsProfileTemplatesTitle.toUpperCase()
                            : l10n.settingsProfileTemplatesTitle,
                        style: t.screenTitle.copyWith(fontSize: 16),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 20, color: t.textSecondary),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (templates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          l10n.settingsProfileNoTemplates,
                          style: t.bodySecondary.copyWith(fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: GridView.builder(
                        shrinkWrap: true,
                        itemCount: templates.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.85,
                        ),
                        itemBuilder: (ctx, i) {
                          final tmpl = templates[i];
                          return GestureDetector(
                            onTap: () {
                              setState(() => _pixelGrid = tmpl.split(''));
                              _saveProfile();
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.settingsProfileTemplateEquipped),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: t.border),
                                      ),
                                      child: PixelArtAvatar(
                                        hexString: tmpl,
                                        size: 48,
                                      ),
                                    ),
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: GestureDetector(
                                        onTap: () async {
                                          await WiltkeyPersistence().deleteAvatarTemplate(tmpl);
                                          templates.removeAt(i);
                                          setModalState(() {});
                                          if (mounted) setState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: t.bg,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: t.border),
                                          ),
                                          child: Icon(Icons.close, size: 10, color: t.danger),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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

  void _openChangePin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePinScreen()),
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
              icon: const Icon(Icons.shield_outlined, size: 20),
              text: t.uppercaseLabels
                  ? l10n.settingsTabSecurity.toUpperCase()
                  : l10n.settingsTabSecurity,
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
              _buildSecurityTab(t, l10n),
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
          // --- Identity: avatar anchor, name, short nick, account id ---
          // Avatar preview with the equipped border; tap to open the editor.
          ListenableBuilder(
            listenable: AvatarBorderController.instance,
            builder: (context, _) => Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _editAvatar();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PixelArtAvatar(
                      hexString: _pixelGrid.join(),
                      size: 96,
                      borderId: AvatarBorderController.instance.borderId,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: t.action,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.surface, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.edit, size: 14, color: t.onAction),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                _openTemplateSelector();
              },
              icon: Icon(Icons.collections_bookmark_outlined, size: 15, color: t.action),
              label: Text(
                t.uppercaseLabels
                    ? l10n.settingsProfileTemplatesButton.toUpperCase()
                    : l10n.settingsProfileTemplatesButton,
                style: t.dataMono.copyWith(
                  color: t.action,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Avatar border — right under the avatar it decorates. Equipping it is
          // a profile change → broadcast (handled by the controller listener).
          Text(
            l10n.settingsBorderSection,
            style: t.dataMono.copyWith(
              color: t.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          BorderPicker(sampleHex: _pixelGrid.join()),
          const SizedBox(height: 20),

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
                    HapticFeedback.lightImpact();
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
          const SizedBox(height: 20),

          // --- Actions: Shop & Theme ---
          _buildShopCard(t, l10n),
          const SizedBox(height: 10),
          _buildThemeCard(t, l10n),
          Divider(color: t.border, height: 32),

          // --- Other visuals ---
          _section(t, l10n.settingsProfileSectionOtherVisuals),
          const SizedBox(height: 12),
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
                        onChanged: (v) {
                          if (v != _appState.chatTextScale) {
                            HapticFeedback.selectionClick();
                          }
                          setState(() => _appState.setChatTextScale(v));
                        },
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
          const SizedBox(height: 28),
          _buildAboutFooter(t, l10n),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // Security tab: fingerprint unlock, PIN change, and the destructive identity
  // reset — kept out of Profile so that tab stays purely customization.
  Widget _buildSecurityTab(WiltkeyTokens t, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(t, l10n.settingsSecuritySectionAccess),
          const SizedBox(height: 12),

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
                        onChanged: _biometricBusy
                            ? null
                            : (val) {
                                HapticFeedback.lightImpact();
                                _onBiometricToggle(val);
                              },
                      ),
                    ],
                  ),
                  Text(
                    l10n.settingsBiometricDescription,
                    style: t.bodySecondary,
                  ),
                  // PIN-fallback window — only meaningful once fingerprint unlock
                  // is on. 1–24 h, or the last notch = Never (fingerprint stays).
                  if (_appState.biometricUnlockEnabled) ...[
                    Divider(color: t.border, height: 20),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 16, color: t.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.settingsBiometricIdleTitle,
                            style:
                                t.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          _appState.biometricIdleHours <= 0
                              ? l10n.settingsBiometricIdleNever
                              : l10n.settingsBiometricIdleValue(
                                  _appState.biometricIdleHours),
                          style: t.dataMono.copyWith(
                            color: t.action,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: (_appState.biometricIdleHours <= 0
                              ? 25
                              : _appState.biometricIdleHours.clamp(1, 24))
                          .toDouble(),
                      min: 1,
                      max: 25, // 25th notch = Never
                      divisions: 24,
                      activeColor: t.action,
                      inactiveColor: t.budgetEmpty,
                      label: _appState.biometricIdleHours <= 0
                          ? l10n.settingsBiometricIdleNever
                          : l10n.settingsBiometricIdleValue(
                              _appState.biometricIdleHours),
                      onChanged: (val) {
                        final pos = val.round();
                        if (pos != (_appState.biometricIdleHours <= 0 ? 25 : _appState.biometricIdleHours)) {
                          HapticFeedback.selectionClick();
                        }
                        _appState.setBiometricIdleHours(pos >= 25 ? 0 : pos);
                        setState(() {});
                      },
                    ),
                    Text(
                      l10n.settingsBiometricIdleDescription,
                      style: t.bodySecondary,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _openChangePin();
              },
              icon: const Icon(Icons.lock_outline, size: 16),
              label: Text(l10n.settingsProfileChangePinButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.action,
                side: BorderSide(color: t.action, width: t.borderWidth),
                minimumSize: const Size.fromHeight(45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          _section(t, l10n.settingsSecuritySectionDanger),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.danger.withValues(alpha: 0.08),
              border: Border.all(
                color: t.danger.withValues(alpha: 0.25),
                width: t.borderWidth,
              ),
              borderRadius: BorderRadius.circular(t.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: t.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.settingsProfileResetIdentityButton,
                        style: t.body.copyWith(
                          color: t.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.settingsResetConfirmBody,
                  style: t.bodySecondary.copyWith(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _confirmResetIdentity();
                    },
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: Text(
                      l10n.settingsProfileResetIdentityButton,
                      style: t.badgeLabel.copyWith(color: t.danger, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.danger,
                      side: BorderSide(color: t.danger, width: t.borderWidth),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                    ),
                  ),
                ),
              ],
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
    final mutedOrFilteredContacts = _appState.contacts
        .where((c) => c.isMuted || c.isMentionsOnly)
        .toList();

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
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),

          // Categories section
          _section(t, l10n.settingsNotifyCategories),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: _panel(t),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    l10n.settingsNotifyDirectMessages,
                    style: t.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n.settingsNotifyDirectMessagesSubtitle,
                    style: t.bodySecondary,
                  ),
                  value: _appState.notifyDirectMessages,
                  activeThumbColor: t.action,
                  onChanged: (val) async {
                    await _appState.setNotifyDirectMessages(val);
                    if (mounted) setState(() {});
                  },
                ),
                Divider(color: t.border, height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: Text(
                    l10n.settingsNotifyGroupMessages,
                    style: t.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n.settingsNotifyGroupMessagesSubtitle,
                    style: t.bodySecondary,
                  ),
                  value: _appState.notifyGroupMessages,
                  activeThumbColor: t.action,
                  onChanged: (val) async {
                    await _appState.setNotifyGroupMessages(val);
                    if (mounted) setState(() {});
                  },
                ),
                Divider(color: t.border, height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: Text(
                    l10n.settingsNotifyEvents,
                    style: t.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n.settingsNotifyEventsSubtitle,
                    style: t.bodySecondary,
                  ),
                  value: _appState.notifyEvents,
                  activeThumbColor: t.action,
                  onChanged: (val) async {
                    await _appState.setNotifyEvents(val);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Muted Chats & Groups section
          _section(t, l10n.settingsMutedChatsTitle),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: _panel(t),
            child: mutedOrFilteredContacts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        l10n.settingsNoMutedChats,
                        style: t.bodySecondary,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < mutedOrFilteredContacts.length; i++) ...[
                        if (i > 0)
                          Divider(color: t.border, height: 16),
                        Row(
                          children: [
                            PixelArtAvatar(
                              hexString: mutedOrFilteredContacts[i].isGroup
                                  ? (mutedOrFilteredContacts[i].groupIconHex ??
                                      PixelArtAvatar.generateIdenticon(
                                        mutedOrFilteredContacts[i].keyHash,
                                      ))
                                  : (mutedOrFilteredContacts[i].profileImageB64 ??
                                      PixelArtAvatar.generateIdenticon(
                                        mutedOrFilteredContacts[i].keyHash,
                                      )),
                              size: 32,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mutedOrFilteredContacts[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    mutedOrFilteredContacts[i].isMuted
                                        ? l10n.chatNotificationModeMuted
                                        : l10n.chatNotificationModeMentions,
                                    style: t.dataMono.copyWith(
                                      fontSize: 11,
                                      color: mutedOrFilteredContacts[i].isMuted
                                          ? t.danger
                                          : t.action,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await _appState.setChatNotificationMode(
                                  mutedOrFilteredContacts[i],
                                  'all',
                                );
                                if (mounted) setState(() {});
                              },
                              child: Text(
                                l10n.settingsUnmute,
                                style: t.body.copyWith(
                                  color: t.action,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 32),
          _buildAboutFooter(t, l10n),
        ],
      ),
    );
  }

  bool _checkingUpdates = false;

  Future<void> _checkUpdatesManual(AppLocalizations l10n) async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    final info = await UpdateService.instance.checkForUpdates(force: true);
    if (!mounted) return;
    setState(() => _checkingUpdates = false);

    if (info != null &&
        info.isUpdateAvailable(UpdateService.instance.currentBuildNumber)) {
      UpdateService.showWhatsNewSheet(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsUpToDate),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // App identity footer with version, publisher, update status, and "What's New".
  Widget _buildAboutFooter(WiltkeyTokens t, AppLocalizations l10n) {
    final updateService = UpdateService.instance;
    final isAvailable = updateService.isUpdateAvailable;
    final info = updateService.cachedInfo;

    return Center(
      child: Column(
        children: [
          Text(
            'WiltKey',
            style: t.screenTitle.copyWith(fontSize: 15, letterSpacing: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            _appVersion.isEmpty ? kAppPublisher : '$_appVersion · $kAppPublisher',
            style: t.dataMono,
          ),
          const SizedBox(height: 10),
          if (isAvailable && info != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(t.radiusPill),
              onTap: () => UpdateService.showWhatsNewSheet(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: t.action.withValues(alpha: 0.1),
                  border: Border.all(color: t.action, width: t.borderWidth),
                  borderRadius: BorderRadius.circular(t.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.system_update_alt, size: 13, color: t.action),
                    const SizedBox(width: 6),
                    Text(
                      l10n.settingsUpdateAvailable(info.latestVersion),
                      style: t.body.copyWith(
                        fontSize: 11,
                        color: t.action,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => UpdateService.showWhatsNewSheet(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  l10n.settingsWhatsNew,
                  style: t.bodySecondary.copyWith(
                    fontSize: 12,
                    color: t.action,
                  ),
                ),
              ),
              Text('·', style: t.dataMono.copyWith(color: t.textTertiary)),
              TextButton(
                onPressed:
                    _checkingUpdates ? null : () => _checkUpdatesManual(l10n),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: _checkingUpdates
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.action,
                        ),
                      )
                    : Text(
                        l10n.settingsCheckForUpdates,
                        style: t.bodySecondary.copyWith(
                          fontSize: 12,
                          color: t.textSecondary,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
        kFcmEnabled
            ? l10n.notificationModePrivate
            : l10n.notificationModeLowPower,
        kFcmEnabled
            ? l10n.notificationModePrivateDesc
            : l10n.notificationModeLowPowerDesc,
      ),
      NotificationMode.instant => (
        l10n.notificationModeInstant,
        // Play flavor backs Instant with FCM, not a foreground socket — describe
        // that instead of the FOSS "no Google push" copy.
        kFcmEnabled
            ? l10n.notificationModeInstantDescFcm
            : l10n.notificationModeInstantDesc,
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
                      Row(
                        children: [
                          CopyDebugLogButton(logs: AppState.debugLogs),
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

  // Shop / Support action card. Play builds route to the purchasable shop; FOSS
  // builds to the "Support the project" page — both use the same ShopScreen, which
  // picks its face from the flavor.
  Widget _buildShopCard(WiltkeyTokens t, AppLocalizations l10n) {
    final isPlay = EntitlementService.instance.billingAvailable;
    return InkWell(
      borderRadius: BorderRadius.circular(t.radiusControl),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(t.radiusControl),
        ),
        child: Row(
          children: [
            Icon(
              isPlay ? Icons.storefront : Icons.volunteer_activism,
              color: t.action,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPlay ? l10n.shopEntryTitle : l10n.supportEntryTitle,
                    style: t.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPlay
                        ? (l10n.shopEntrySubtitle)
                        : (l10n.supportEntrySubtitle),
                    style: t.bodySecondary.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  // Theme selector button — a compact row showing the active theme; taps into the
  // dedicated selector screen (keeps the Profile tab short as owned themes grow).
  Widget _buildThemeCard(WiltkeyTokens t, AppLocalizations l10n) {
    return ListenableBuilder(
      listenable: ThemeController(),
      builder: (context, _) {
        final current = WiltkeyThemeRegistry.byId(ThemeController().themeId);
        return InkWell(
          borderRadius: BorderRadius.circular(t.radiusControl),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ThemeSelectorScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
            child: Row(
              children: [
                Icon(Icons.palette_outlined, color: t.action, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsThemeLabel,
                        style: t.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        current.localizedName(context),
                        style: t.bodySecondary,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: t.textTertiary, size: 20),
              ],
            ),
          ),
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
