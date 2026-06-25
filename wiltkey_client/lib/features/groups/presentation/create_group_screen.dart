import 'package:flutter/material.dart';
import 'dart:math';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/pixel_art_editor.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import 'group_invite_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

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

  // 10x10 pixel art icon (100-char hex grid); edited via the shared popup.
  late List<String> _pixelGrid;

  final List<double> _totalGroupSizeOptions = [5.0, 10.0, 20.0, 50.0, 100.0];
  final List<double> _laneSizeOptions = [1.0, 2.0, 5.0, 10.0];
  final List<double> _messageSizeOptions = [0.5, 1.0, 2.0, 5.0, 10.0];

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
    _generateRandomIcon();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    if (!_formKey.currentState!.validate()) return;

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

    final totalGroupBytes = (_totalGroupSizeMb * 1024 * 1024).toInt();
    final laneBytes = (_laneSizeMb * 1024 * 1024).toInt();

    try {
      await _appState.addGroupChat(
        name: groupName,
        groupId: groupId,
        relayUrl: _appState.activeRelayUrl,
        totalGroupSize: totalGroupBytes,
        laneSize: laneBytes,
        groupIconHex: groupIconHex,
        maxMembers: _calculatedMaxMembers,
        groupSeed: groupSeed,
      );

      final newGroup = _appState.contacts.firstWhere(
        (c) => c.keyHash == groupId,
      );

      if (mounted) {
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
                            .toDouble(),
                        min: 0,
                        max: (_totalGroupSizeOptions.length - 1).toDouble(),
                        divisions: _totalGroupSizeOptions.length - 1,
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
                  onPressed: _onCreateGroup,
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
}
