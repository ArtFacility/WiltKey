import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/pixel_art_editor.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/localization/locale_controller.dart';
import '../../settings/presentation/widgets/theme_picker.dart';

enum OnboardingPageType { language, welcome, theme, profile, avatar, pin }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final AppState _appState = AppState();

  int _currentPage = 0;

  late final List<OnboardingPageType> _activePages;

  // Step Inputs
  final TextEditingController _usernameController = TextEditingController(
    text: 'Anonymous',
  );
  late final TextEditingController _codenameController;

  // Avatar grid (100-char hex); edited via the shared popup.
  late List<String> _pixelGrid;

  // PIN inputs
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  final FocusNode _confirmPinFocus = FocusNode();
  String _pinError = '';

  @override
  void initState() {
    super.initState();
    _codenameController = TextEditingController(
      text: _generateRandomCodename(),
    );
    _pixelGrid = _generateRandomSymmetricGrid().split('');

    _activePages = [];
    if (!LocaleController().isLocaleSet) {
      _activePages.add(OnboardingPageType.language);
    }
    _activePages.addAll([
      OnboardingPageType.welcome,
      OnboardingPageType.theme,
      OnboardingPageType.profile,
      OnboardingPageType.avatar,
      OnboardingPageType.pin,
    ]);
  }

  String _generateRandomCodename() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = Random();
    return List.generate(
      5,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _codenameController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _pinFocus.dispose();
    _confirmPinFocus.dispose();
    super.dispose();
  }

  String _generateRandomSymmetricGrid() {
    final rand = Random();
    final int numColors = rand.nextInt(2) + 2;
    final List<int> chosenColors = [];
    while (chosenColors.length < numColors) {
      final colorIdx = rand.nextInt(15) + 1;
      if (!chosenColors.contains(colorIdx)) chosenColors.add(colorIdx);
    }
    final List<String> grid = List.filled(100, '0');
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 5; x++) {
        final colorIndex = chosenColors[rand.nextInt(chosenColors.length)];
        final colorChar = colorIndex.toRadixString(16);
        grid[y * 10 + x] = colorChar;
        grid[y * 10 + (9 - x)] = colorChar;
      }
    }
    return grid.join();
  }

  Future<void> _editAvatar() async {
    final l10n = AppLocalizations.of(context)!;
    // No identity hash exists yet (the enclave is created at PIN setup), so the
    // editor falls back to a random sprite rather than an identicon.
    final result = await showPixelArtEditor(
      context,
      initialHex: _pixelGrid.join(),
      title: l10n.onboardingAvatarTitle,
      defaultColorIndex: 1,
    );
    if (result != null) setState(() => _pixelGrid = result.split(''));
  }

  void _nextPage() {
    final l10n = AppLocalizations.of(context)!;
    final currentPageType = _activePages[_currentPage];

    if (currentPageType == OnboardingPageType.language) {
      if (!LocaleController().isLocaleSet) {
        LocaleController().setLocale('system');
      }
    } else if (currentPageType == OnboardingPageType.profile) {
      if (_usernameController.text.trim().isEmpty) {
        _showSnackBar(l10n.onboardingProfileUsernameError);
        return;
      }
      if (_codenameController.text.trim().length != 5) {
        _showSnackBar(l10n.onboardingProfileCodenameError);
        return;
      }
    } else if (currentPageType == OnboardingPageType.pin) {
      final pin = _pinController.text;
      final confirm = _confirmPinController.text;
      if (pin.length < 4 || pin.length > 6) {
        setState(() => _pinError = l10n.onboardingPinLengthError);
        return;
      }
      if (pin != confirm) {
        setState(() => _pinError = l10n.onboardingPinMatchError);
        return;
      }
      setState(() => _pinError = '');
      _initializeSecureEnclave(l10n);
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showSnackBar(String msg) {
    final t = context.wk;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: t.surface,
        content: Text(
          msg,
          style: t.bodySecondary.copyWith(
            color: t.danger,
            fontWeight: FontWeight.bold,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _initializeSecureEnclave(AppLocalizations l10n) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      await _appState.setupPinAndInitialize(
        pin: _pinController.text,
        username: _usernameController.text.trim(),
        codename: _codenameController.text.trim().toUpperCase(),
        profileImage: _pixelGrid.join(),
      );
      if (mounted) Navigator.pop(context); // Pop loading dialog
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _pinError = l10n.onboardingSetupFailed(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final pages = _activePages.map((type) {
      switch (type) {
        case OnboardingPageType.language:
          return _buildLanguagePage(t, l10n);
        case OnboardingPageType.welcome:
          return _buildWelcomePage(t, l10n);
        case OnboardingPageType.theme:
          return _buildThemePage(t, l10n);
        case OnboardingPageType.profile:
          return _buildProfileDetailsPage(t, l10n);
        case OnboardingPageType.avatar:
          return _buildAvatarCustomizerPage(t, l10n);
        case OnboardingPageType.pin:
          return _buildPinSetupPage(t, l10n);
      }
    }).toList();

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Indicator
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.uppercaseLabels
                        ? l10n.onboardingWelcomeTitle.toUpperCase()
                        : l10n.onboardingWelcomeTitle,
                    style: t.dataMono.copyWith(
                      color: t.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: List.generate(pages.length, (index) {
                      final isCurrent = index == _currentPage;
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent ? t.action : t.surfacePressed,
                          boxShadow: isCurrent ? t.glow(t.action) : null,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: pages,
              ),
            ),

            // Bottom Navigation Actions
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 14.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: _prevPage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.textSecondary,
                        side: BorderSide(color: t.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(t.radiusControl),
                        ),
                        minimumSize: const Size(80, 40),
                      ),
                      child: Text(l10n.commonBack),
                    )
                  else
                    const SizedBox(),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.action,
                      foregroundColor: t.onAction,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                      minimumSize: const Size(120, 40),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == _activePages.length - 1
                          ? l10n.commonFinish
                          : l10n.commonContinue,
                    ),
                  ),
                ],
              ),
            ),

            // Security Intel Panel at the very bottom
            _buildSecurityIntelCard(t, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityIntelCard(WiltkeyTokens t, AppLocalizations l10n) {
    final currentPageType = _activePages[_currentPage];
    String title = '';
    String fact = '';

    switch (currentPageType) {
      case OnboardingPageType.language:
        title = l10n.onboardingFactLanguageTitle;
        fact = l10n.onboardingFactLanguageBody;
        break;
      case OnboardingPageType.welcome:
        title = l10n.onboardingFactMetadataTitle;
        fact = l10n.onboardingFactMetadataBody;
        break;
      case OnboardingPageType.theme:
        title = l10n.onboardingFactThemeTitle;
        fact = l10n.onboardingFactThemeBody;
        break;
      case OnboardingPageType.profile:
        title = l10n.onboardingFactOtpTitle;
        fact = l10n.onboardingFactOtpBody;
        break;
      case OnboardingPageType.avatar:
        title = l10n.onboardingFactLimitsTitle;
        fact = l10n.onboardingFactLimitsBody;
        break;
      case OnboardingPageType.pin:
        title = l10n.onboardingFactKdfTitle;
        fact = l10n.onboardingFactKdfBody;
        break;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border, width: 1.0),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.security, size: 13, color: t.action),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.uppercaseLabels
                      ? '${l10n.onboardingIntelTitle.toUpperCase()} // ${title.toUpperCase()}'
                      : '${l10n.onboardingIntelTitle} // ${_titleCase(title)}',
                  style: t.sectionLabel.copyWith(color: t.action, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(fact, style: t.bodySecondary.copyWith(height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildLanguagePage(WiltkeyTokens t, AppLocalizations l10n) {
    final languages = [
      {'code': 'system', 'name': l10n.settingsLanguageSystem, 'flag': '🌐'},
      {'code': 'en', 'name': l10n.settingsLanguageEnglish, 'flag': '🇬🇧'},
      {'code': 'hu', 'name': l10n.settingsLanguageHungarian, 'flag': '🇭🇺'},
      {'code': 'pl', 'name': l10n.settingsLanguagePolish, 'flag': '🇵🇱'},
      {'code': 'de', 'name': l10n.settingsLanguageGerman, 'flag': '🇩🇪'},
      {'code': 'fr', 'name': l10n.settingsLanguageFrench, 'flag': '🇫🇷'},
      {'code': 'sv', 'name': l10n.settingsLanguageSwedish, 'flag': '🇸🇪'},
      {'code': 'zh', 'name': l10n.settingsLanguageChinese, 'flag': '🇨🇳'},
    ];

    final currentCode = LocaleController().locale?.languageCode ?? 'system';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _stepTitle(t, l10n.settingsLanguageLabel),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingLanguageDescription,
            style: t.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          ...languages.map((lang) {
            final code = lang['code']!;
            final selected = code == currentCode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  LocaleController().setLocale(code == 'system' ? null : code);
                },
                child: AnimatedContainer(
                  duration: t.motionShort,
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(t.radiusCard),
                    border: Border.all(
                      color: selected ? t.action : t.border,
                      width: selected ? 2 : t.borderWidth,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          lang['name']!,
                          style: t.body.copyWith(
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected ? t.textPrimary : t.textSecondary,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, color: t.action, size: 20)
                      else
                        Icon(
                          Icons.circle_outlined,
                          color: t.textTertiary,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWelcomePage(WiltkeyTokens t, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.vpn_key_outlined, size: 64, color: t.action),
          const SizedBox(height: 24),
          Text(
            t.uppercaseLabels
                ? l10n.onboardingWelcomeTitle.toUpperCase()
                : l10n.onboardingWelcomeTitle,
            style: t.screenTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingWelcomeDescription,
            textAlign: TextAlign.center,
            style: t.bodySecondary.copyWith(height: 1.6),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: t.danger.withValues(alpha: 0.08),
              border: Border.all(color: t.danger.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gpp_bad_outlined, size: 14, color: t.danger),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    t.uppercaseLabels
                        ? l10n.onboardingWelcomeNoHistory.toUpperCase()
                        : l10n.onboardingWelcomeNoHistory,
                    style: t.dataMono.copyWith(
                      color: t.danger,
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
    );
  }

  Widget _buildThemePage(WiltkeyTokens t, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            l10n.onboardingThemeTitle,
            style: t.screenTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingThemeDescription,
            style: t.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          const ThemePicker(),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsPage(WiltkeyTokens t, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _stepTitle(t, l10n.onboardingProfileTitle),
          const SizedBox(height: 24),
          Text(l10n.onboardingProfileUsernameLabel, style: t.bodySecondary),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            style: t.body.copyWith(fontSize: 13),
            decoration: _inputDecoration(
              t,
              hint: l10n.onboardingProfileUsernameHint,
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.onboardingProfileCodenameLabel, style: t.bodySecondary),
          const SizedBox(height: 8),
          TextField(
            controller: _codenameController,
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
                _codenameController.text = val.toUpperCase();
                _codenameController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _codenameController.text.length),
                );
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingProfileCodenameExplanation,
            style: t.bodySecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCustomizerPage(WiltkeyTokens t, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle(t, l10n.onboardingAvatarTitle),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _editAvatar,
                  child: PixelArtAvatar(
                    hexString: _pixelGrid.join(),
                    size: 160,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _editAvatar,
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(l10n.avatarEditButton),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.action,
                    side: BorderSide(color: t.positive),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinSetupPage(WiltkeyTokens t, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle(t, l10n.onboardingPinTitle),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingPinExplanation,
            style: t.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          Text(l10n.onboardingPinEnter, style: t.bodySecondary),
          const SizedBox(height: 8),
          _buildPinInput(
            t,
            _pinController,
            _pinFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: () => _confirmPinFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          Text(l10n.onboardingPinConfirm, style: t.bodySecondary),
          const SizedBox(height: 8),
          _buildPinInput(
            t,
            _confirmPinController,
            _confirmPinFocus,
            textInputAction: TextInputAction.done,
            onSubmitted: _nextPage,
          ),
          if (_pinError.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _pinError,
              style: t.bodySecondary.copyWith(
                color: t.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinInput(
    WiltkeyTokens t,
    TextEditingController controller,
    FocusNode focusNode, {
    required TextInputAction textInputAction,
    required VoidCallback onSubmitted,
  }) {
    // A tap anywhere on the box focuses the (invisible) field — previously only
    // the field's small intrinsic area was tappable, so most of the box did
    // nothing. The opaque GestureDetector covers the full width/height.
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
              // First field's keyboard "enter" jumps to the confirm field; the
              // confirm field's "enter" submits (see call sites).
              textInputAction: textInputAction,
              onSubmitted: (_) => onSubmitted(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
              onChanged: (val) {
                setState(() {});
              },
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

  Widget _stepTitle(WiltkeyTokens t, String text) => Text(
    t.uppercaseLabels ? text.toUpperCase() : text,
    style: t.sectionLabel.copyWith(color: t.action, fontSize: 14),
  );

  InputDecoration _inputDecoration(WiltkeyTokens t, {String? hint}) =>
      InputDecoration(
        filled: true,
        fillColor: t.surface,
        hintText: hint,
        hintStyle: t.body.copyWith(color: t.textTertiary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.border),
          borderRadius: BorderRadius.circular(t.radiusControl),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.action),
          borderRadius: BorderRadius.circular(t.radiusControl),
        ),
      );

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();
}
