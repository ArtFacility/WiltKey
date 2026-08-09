import 'package:flutter/material.dart';
import 'dart:math';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import 'package:wiltkey_client/features/shop/presentation/shop_screen.dart';
import '../../../core/state.dart';
import '../../../core/entitlements/entitlement_service.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/pixel_art_editor.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import 'group_invite_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  /// When true the screen opens straight into Time Wilt mode (from the Connect
  /// hub's "Time Wilt group" card) — no byte-budget sliders, no mode toggle.
  final bool timeWilt;
  const CreateGroupScreen({super.key, this.timeWilt = false});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final AppState _appState = AppState();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();

  // Group policy state
  double _totalGroupSizeMb = 20.0; // Default 20 MB total OTP
  double _laneSizeMb = 2.0; // Default 2 MB per lane
  bool _imagesAllowed = true;
  double _maxMessageSizeKb = 2.0; // Default 2 KB per message

  // Time Wilt group state: "limited time, unlimited budget". When on, the two
  // byte-budget sliders are replaced by a lifetime slider + a members slider,
  // and each member gets a huge disjoint lane (see AppState.twGroupLaneSize).
  bool _timeWiltMode = false;
  int _twLifetimeSecs = 604800; // default 7 days
  int _twMaxMembers = 20;
  // Free users cap at 20 members; Plus unlocks the rest up to 100. (100 still
  // fits the 32-bit group-keystream reach: 120GB/100 ≈ 1.2GB per member.)
  final List<int> _twMemberOptions = [5, 10, 20, 30, 50, 100];
  static const int _freeMemberMaxIndex = 2; // index of 20

  // Lifetime stops shared with the 1:1 Time Wilt slider (label, seconds, Plus).
  static const List<(String, int, bool)> _wiltLifetimes = [
    ('1h', 3600, false),
    ('3h', 10800, false),
    ('6h', 21600, false),
    ('12h', 43200, false),
    ('1d', 86400, false),
    ('2d', 172800, false),
    ('3d', 259200, false),
    ('5d', 432000, false),
    ('7d', 604800, false),
    ('14d', 1209600, false),
    ('30d', 2592000, false),
    ('45d', 3888000, true),
    ('60d', 5184000, true),
    ('90d', 7776000, true),
    ('6mo', 15552000, true),
  ];

  // 10x10 pixel art icon (100-char hex grid); edited via the shared popup.
  late List<String> _pixelGrid;

  // Guards the create flow: generating the group keystream/lanes is a heavy,
  // multi-hundred-ms await, so we lock out repeat taps (which would otherwise
  // spawn duplicate groups) and show a blocking progress dialog meanwhile.
  bool _creating = false;

  // Pad-generation progress for the "forging the pad" dialog (0..1). A big group
  // pad (up to 500 MB) would otherwise show a frozen-looking indeterminate bar.
  double _createProgress = 0.0;
  final ValueNotifier<double> _createProgressNotifier = ValueNotifier(0.0);

  // Group total-pad tiers. The first [_freeGroupSizeCount] are free for everyone;
  // the larger ones need the larger-pads unlock (only the CREATOR — the host —
  // needs it; members just receive whatever total the host set). Append-only in
  // spirit, though a group's total is fixed at creation so nothing persisted
  // depends on this list's indices.
  final List<double> _totalGroupSizeOptions = [
    5.0, 10.0, 20.0, 50.0, 100.0, // free
    150.0, 200.0, 300.0, 400.0, 500.0, // premium
  ];
  static const int _freeGroupSizeCount = 5; // indices 0..4 (5–100 MB) are free
  final List<double> _laneSizeOptions = [1.0, 2.0, 5.0, 10.0];
  final List<double> _messageSizeOptions = [0.5, 1.0, 2.0, 5.0, 10.0];

  /// Highest total-pad index the user may select (gated on the larger-pads unlock).
  int get _maxGroupSizeIndex => EntitlementService.instance.largerPadsUnlocked
      ? _totalGroupSizeOptions.length - 1
      : _freeGroupSizeCount - 1;

  int get _calculatedMaxMembers {
    final totalBytes = (_totalGroupSizeMb * 1024 * 1024).toInt();
    final laneBytes = (_laneSizeMb * 1024 * 1024).toInt();
    final infoLaneSize = AppState.infoLaneSize;
    final members = (totalBytes - infoLaneSize) ~/ laneBytes;
    return members < 2 ? 2 : members;
  }

  @override
  void initState() {
    super.initState();
    _timeWiltMode = widget.timeWilt;
    _generateRandomIcon();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _createProgressNotifier.dispose();
    super.dispose();
  }

  void _generateRandomIcon() {
    final rand = Random();
    final numColors = rand.nextInt(2) + 2; // either 2 or 3 colors
    final List<int> chosenColors = [0]; // Include transparent/black
    while (chosenColors.length < numColors) {
      final colorIdx = rand.nextInt(16);
      if (!chosenColors.contains(colorIdx)) {
        chosenColors.add(colorIdx);
      }
    }

    final List<String> grid = List.filled(100, '0');
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 5; x++) {
        final colorIndex = chosenColors[rand.nextInt(chosenColors.length)];
        final colorChar = colorIndex.toRadixString(16);
        grid[y * 10 + x] = colorChar;
        grid[y * 10 + (9 - x)] = colorChar; // horizontal symmetry
      }
    }

    setState(() {
      _pixelGrid = grid;
    });
  }

  Future<void> _editIcon() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showPixelArtEditor(
      context,
      initialHex: _pixelGrid.join(),
      title: l10n.groupCreatePixelArtIcon,
      defaultColorIndex: 5, // purple, the group default
    );
    if (result != null) setState(() => _pixelGrid = result.split(''));
  }

  void _onCreateGroup() async {
    // Re-entry guard: the blocking dialog below already swallows taps, but this
    // closes the tiny synchronous window before it appears — so no accidental
    // duplicate groups even on a frantic double-tap.
    if (_creating) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _creating = true);
    _showCreatingDialog();

    final groupName = _nameController.text.trim();
    final groupIconHex = _pixelGrid.join();

    final randomBytes = List<int>.generate(
      32,
      (i) => Random.secure().nextInt(256),
    );
    final groupId = randomBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final groupSeedBytes = List<int>.generate(
      32,
      (i) => Random.secure().nextInt(256),
    );
    final groupSeed = groupSeedBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    // Enforcement: clamp to what this user may actually create, so a premium
    // tier can never slip through from a stale selection (the host is the only
    // one who needs the unlock — members just receive the total).
    final clampedIndex = _totalGroupSizeOptions
        .indexOf(_totalGroupSizeMb)
        .clamp(0, _maxGroupSizeIndex);
    // Time Wilt groups ignore the byte sliders: each member gets a huge disjoint
    // lane (unlimited budget), and the group carries a lifetime instead.
    final bool tw = _timeWiltMode;
    // Enforce the member cap by entitlement (free = 20, Plus = 100), so a stale
    // selection can't exceed what this host may actually create.
    final int twMemberCap = EntitlementService.instance.largerPadsUnlocked
        ? _twMemberOptions.last
        : _twMemberOptions[_freeMemberMaxIndex];
    final int maxMembers =
        tw ? _twMaxMembers.clamp(2, twMemberCap) : _calculatedMaxMembers;
    final int laneBytes = tw
        ? AppState.twGroupLaneSize(maxMembers)
        : (_laneSizeMb * 1024 * 1024).toInt();
    final int totalGroupBytes = tw
        ? AppState.infoLaneSize + laneBytes * maxMembers
        : (_totalGroupSizeOptions[clampedIndex] * 1024 * 1024).toInt();

    try {
      await _appState.addGroupChat(
        name: groupName,
        groupId: groupId,
        relayUrl: _appState.activeRelayUrl,
        totalGroupSize: totalGroupBytes,
        laneSize: laneBytes,
        groupIconHex: groupIconHex,
        maxMembers: maxMembers,
        groupSeed: groupSeed,
        wiltLifetimeSecs: tw ? _twLifetimeSecs : null,
        onPadProgress: (written, total) {
          if (total <= 0) return;
          final frac = written / total;
          if (frac - _createProgress < 0.01 && written < total) return;
          _createProgress = frac;
          _createProgressNotifier.value = frac;
        },
      );

      final newGroup = _appState.contacts.firstWhere(
        (c) => c.keyHash == groupId,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close progress
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GroupInviteScreen(group: newGroup),
          ),
        );
      }
    } catch (e) {
      _appState.log('[Group Error] Failed to create group: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close progress
        setState(() => _creating = false); // allow a retry
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.groupCreateFailedSnackBar(e.toString()),
            ),
          ),
        );
      }
    }
  }

  /// Non-dismissible "forging the pad" progress popup. The keystream generation
  /// is a single opaque await (no progress signal), so the bar is indeterminate.
  void _showCreatingDialog() {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false, // back button can't cancel mid-generation
        child: Dialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusCard),
            side: BorderSide(color: t.border, width: t.borderWidth),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 18, color: t.identity),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.uppercaseLabels
                            ? l10n.groupCreateProgressTitle.toUpperCase()
                            : l10n.groupCreateProgressTitle,
                        style: t.body.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.groupCreateProgressSubtitle,
                  style: t.bodySecondary,
                ),
                const SizedBox(height: 16),
                // Determinate for big pads (up to 500 MB now) — an indeterminate
                // bar there reads as "frozen". Falls back to indeterminate until
                // the first progress tick lands.
                ValueListenableBuilder<double>(
                  valueListenable: _createProgressNotifier,
                  builder: (context, progress, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(t.radiusPill),
                        child: LinearProgressIndicator(
                          value: progress > 0 ? progress : null,
                          minHeight: 6,
                          backgroundColor: t.budgetEmpty,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(t.identity),
                        ),
                      ),
                      if (progress > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: t.dataMono.copyWith(
                            color: t.identity,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          t.uppercaseLabels
              ? l10n.groupCreateTitle.toUpperCase()
              : l10n.groupCreateTitle,
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
        backgroundColor: t.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.action),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: t.bg,
        // SafeArea keeps the scrollable form (and its Create button) clear of
        // the system gesture/nav bar — this screen is pushed without a
        // bottomNavigationBar to absorb that inset.
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon preview — tap "Edit icon" to open the shared editor popup.
                Center(
                  child: Column(
                    children: [
                      Text(
                        l10n.groupCreatePixelArtIcon,
                        style: t.dataMono.copyWith(
                          color: t.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _editIcon,
                        child: PixelArtAvatar(
                          hexString: _pixelGrid.join(),
                          size: 120,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _editIcon,
                        icon: Icon(Icons.edit, size: 16, color: t.action),
                        label: Text(
                          t.uppercaseLabels
                              ? l10n.groupCreateEditIcon.toUpperCase()
                              : l10n.groupCreateEditIcon,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.action,
                          side: BorderSide(color: t.positive),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Group Profile Fields
                TextFormField(
                  controller: _nameController,
                  style: t.body.copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: t.uppercaseLabels
                        ? l10n.groupCreateNameLabel.toUpperCase()
                        : l10n.groupCreateNameLabel,
                    labelStyle: t.bodySecondary.copyWith(
                      color: t.positive,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: t.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: t.action),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return l10n.groupCreateNameEmptyValidator;
                    if (value.length > 24)
                      return l10n.groupCreateNameLengthValidator;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Text(
                  t.uppercaseLabels
                      ? l10n.groupCreatePoliciesSection.toUpperCase()
                      : l10n.groupCreatePoliciesSection,
                  style: t.sectionLabel.copyWith(color: t.action),
                ),
                const SizedBox(height: 12),

                // Time Wilt groups explain themselves up top (the mode is chosen
                // by which Connect-hub card opened this screen, not a toggle).
                if (_timeWiltMode) ...[
                  _policyPanel(
                    t,
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_bottom, size: 18, color: t.action),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.groupTimeWiltToggleSub,
                            style: t.bodySecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Byte-budget sizing — hidden in Time Wilt mode.
                if (!_timeWiltMode) ...[
                // Total Shared Pad Size Slider
                _policyPanel(
                  t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.groupCreatePolicyPadSize,
                            style: t.body.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_totalGroupSizeMb.toStringAsFixed(1)} MB',
                            style: t.dataMono.copyWith(
                              color: t.identity,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Slider(
                        value: _totalGroupSizeOptions
                            .indexOf(_totalGroupSizeMb)
                            .clamp(0, _maxGroupSizeIndex)
                            .toDouble(),
                        min: 0,
                        max: _maxGroupSizeIndex.toDouble(),
                        divisions: _maxGroupSizeIndex,
                        activeColor: t.identity,
                        inactiveColor: t.budgetEmpty,
                        onChanged: (val) {
                          setState(() {
                            _totalGroupSizeMb =
                                _totalGroupSizeOptions[val.round()];
                            if (_laneSizeMb >= _totalGroupSizeMb) {
                              _laneSizeMb = _laneSizeOptions.firstWhere(
                                (opt) => opt < _totalGroupSizeMb,
                                orElse: () => 0.5,
                              );
                            }
                          });
                        },
                      ),
                      if (!EntitlementService.instance.largerPadsUnlocked) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ShopScreen(
                                initialTab: ShopTab.plus,
                              ),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(t.radiusControl),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(Icons.lock_open, size: 13, color: t.action),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    l10n.groupLargerPadsUpsell('500 MB'),
                                    style: t.bodySecondary
                                        .copyWith(color: t.action),
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 14, color: t.action),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Per-Member Lane Size Slider
                _policyPanel(
                  t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.groupCreatePolicyLaneSize,
                            style: t.body.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_laneSizeMb.toStringAsFixed(1)} MB',
                            style: t.dataMono.copyWith(
                              color: t.action,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Slider(
                        value: _laneSizeOptions.indexOf(_laneSizeMb).toDouble(),
                        min: 0,
                        max: (_laneSizeOptions.length - 1).toDouble(),
                        divisions: _laneSizeOptions.length - 1,
                        activeColor: t.action,
                        inactiveColor: t.budgetEmpty,
                        onChanged: (val) {
                          setState(() {
                            _laneSizeMb = _laneSizeOptions[val.round()];
                            if (_laneSizeMb >= _totalGroupSizeMb) {
                              _totalGroupSizeMb = _totalGroupSizeOptions
                                  .firstWhere(
                                    (opt) => opt > _laneSizeMb,
                                    orElse: () => 100.0,
                                  );
                            }
                          });
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.groupCreatePolicyMaxMembersLabel,
                            style: t.bodySecondary,
                          ),
                          Text(
                            l10n.groupCreatePolicyMaxMembersValue(
                              _calculatedMaxMembers,
                            ),
                            style: t.dataMono.copyWith(
                              color: t.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ], // end byte-budget sizing

                // Time Wilt sizing — lifetime + members (unlimited budget).
                if (_timeWiltMode) ...[
                  _policyPanel(t, child: _buildLifetimePanel(t, l10n)),
                  const SizedBox(height: 12),
                  _policyPanel(t, child: _buildMembersPanel(t, l10n)),
                  const SizedBox(height: 12),
                ],

                // Images Toggle & Message Size
                _policyPanel(
                  t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.groupCreatePolicyAllowImages,
                                  style: t.body.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  l10n.groupCreatePolicyAllowImagesSub,
                                  style: t.bodySecondary,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _imagesAllowed,
                            activeColor: t.identity,
                            onChanged: (val) =>
                                setState(() => _imagesAllowed = val),
                          ),
                        ],
                      ),
                      Divider(color: t.border, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.groupCreatePolicyPayloadSize,
                            style: t.body.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_maxMessageSizeKb.toStringAsFixed(1)} KB',
                            style: t.dataMono.copyWith(
                              color: t.action,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Slider(
                        value: _messageSizeOptions
                            .indexOf(_maxMessageSizeKb)
                            .toDouble(),
                        min: 0,
                        max: (_messageSizeOptions.length - 1).toDouble(),
                        divisions: _messageSizeOptions.length - 1,
                        activeColor: t.action,
                        inactiveColor: t.budgetEmpty,
                        onChanged: (val) {
                          setState(() {
                            _maxMessageSizeKb =
                                _messageSizeOptions[val.round()];
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _creating ? null : _onCreateGroup,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(l10n.groupCreateButton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.identity,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _policyPanel(WiltkeyTokens t, {required Widget child}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: t.surface,
      border: Border.all(color: t.border),
      borderRadius: BorderRadius.circular(t.radiusControl),
    ),
    child: child,
  );

  /// Time Wilt lifetime slider (mirrors the 1:1 pairing lifetime picker): free
  /// up to 30d, Plus extends the same track to 6mo (free on FOSS).
  Widget _buildLifetimePanel(WiltkeyTokens t, AppLocalizations l10n) {
    final bool extendedUnlocked =
        EntitlementService.instance.largerPadsUnlocked;
    final int lastFreeIndex = _wiltLifetimes.lastIndexWhere((o) => !o.$3);
    final int maxIndex =
        extendedUnlocked ? _wiltLifetimes.length - 1 : lastFreeIndex;
    int currentIndex = _wiltLifetimes.indexWhere((o) => o.$2 == _twLifetimeSecs);
    if (currentIndex < 0) currentIndex = lastFreeIndex;
    currentIndex = currentIndex.clamp(0, maxIndex);
    final String tickLabel = _wiltLifetimes[currentIndex].$1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.timeWiltLifetimeLabel,
              style: t.body.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Text(
              tickLabel,
              style: t.dataMono.copyWith(
                color: t.action,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: currentIndex.toDouble(),
          min: 0,
          max: maxIndex.toDouble(),
          divisions: maxIndex > 0 ? maxIndex : 1,
          label: tickLabel,
          activeColor: t.action,
          inactiveColor: t.budgetEmpty,
          onChanged: (v) {
            final idx = v.round().clamp(0, maxIndex);
            setState(() => _twLifetimeSecs = _wiltLifetimes[idx].$2);
          },
        ),
        if (!extendedUnlocked)
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ShopScreen(initialTab: ShopTab.plus),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 13, color: t.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    l10n.timeWiltPlusHint,
                    style: t.bodySecondary.copyWith(color: t.action),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(l10n.timeWiltExplanation, style: t.bodySecondary),
      ],
    );
  }

  /// Max-members slider for a Time Wilt group. More members = a slightly smaller
  /// (but still multi-GB, effectively unlimited) per-member lane.
  Widget _buildMembersPanel(WiltkeyTokens t, AppLocalizations l10n) {
    final bool plusUnlocked = EntitlementService.instance.largerPadsUnlocked;
    final int maxIndex =
        plusUnlocked ? _twMemberOptions.length - 1 : _freeMemberMaxIndex;
    int idx = _twMemberOptions.indexOf(_twMaxMembers);
    if (idx < 0) idx = _freeMemberMaxIndex;
    idx = idx.clamp(0, maxIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.groupTimeWiltMembersLabel,
              style: t.body.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Text(
              '$_twMaxMembers',
              style: t.dataMono.copyWith(
                color: t.identity,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: idx.toDouble(),
          min: 0,
          max: maxIndex.toDouble(),
          divisions: maxIndex > 0 ? maxIndex : 1,
          activeColor: t.identity,
          inactiveColor: t.budgetEmpty,
          onChanged: (v) => setState(
            () => _twMaxMembers =
                _twMemberOptions[v.round().clamp(0, maxIndex)],
          ),
        ),
        if (!plusUnlocked)
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ShopScreen(initialTab: ShopTab.plus),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.lock_open, size: 13, color: t.action),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.groupTimeWiltMembersUpsell,
                      style: t.bodySecondary.copyWith(color: t.action),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 14, color: t.action),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
