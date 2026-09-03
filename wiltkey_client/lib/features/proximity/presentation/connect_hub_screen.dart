import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../shell/presentation/app_shell.dart';
import '../../groups/presentation/create_group_screen.dart';
import '../../groups/presentation/group_search_screen.dart';
import 'pairing_screen.dart';
import 'qr_pairing_screen.dart';
import '../../stories/presentation/create_story_sheet.dart';
import '../../settings/presentation/settings_screen.dart';

/// The Pair & Connect tab landing: Two main segments anchored to the top:
/// 1. Connect: In-person BLE 1:1, QR Connect, Group Creation & Discovery.
/// 2. Social: Wilting Stories, Broadcast hubs, Quota gauges, with consent gating.
class ConnectHubScreen extends StatefulWidget {
  const ConnectHubScreen({super.key});

  @override
  State<ConnectHubScreen> createState() => _ConnectHubScreenState();
}

class _ConnectHubScreenState extends State<ConnectHubScreen>
    with SingleTickerProviderStateMixin {
  final AppState _appState = AppState();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _appState.addListener(_onState);
  }

  @override
  void dispose() {
    _appState.removeListener(_onState);
    _tabController.dispose();
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: t.bg,
        elevation: 0,
        title: Text(
          t.uppercaseLabels ? l10n.navPair.toUpperCase() : l10n.navPair,
          style: t.screenTitle.copyWith(fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.radiusControl),
              border: Border.all(color: t.border, width: 0.5),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: t.action,
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: t.onAction,
              unselectedLabelColor: t.textSecondary,
              labelStyle: t.sectionLabel.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                Tab(
                  text: t.uppercaseLabels
                      ? (l10n.connectTabConnect ?? 'CONNECT').toUpperCase()
                      : (l10n.connectTabConnect ?? 'Connect'),
                ),
                Tab(
                  text: t.uppercaseLabels
                      ? (l10n.connectTabSocial ?? 'SOCIAL').toUpperCase()
                      : (l10n.connectTabSocial ?? 'Social'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConnectTab(t, l10n),
          _buildSocialTab(t, l10n),
        ],
      ),
    );
  }

  Widget _buildConnectTab(WiltkeyTokens t, AppLocalizations l10n) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      children: [
        _sectionLabel(t, l10n.connectSectionOneOnOne),
        const SizedBox(height: 8),
        _HubCard(
          icon: Icons.bluetooth_searching,
          title: l10n.connectByteBudgetTitle,
          subtitle: l10n.connectByteBudgetDesc,
          onTap: () => _pushPairThenChats(context),
        ),
        _HubCard(
          icon: Icons.hourglass_bottom,
          title: l10n.connectTimeWiltTitle,
          subtitle: l10n.connectTimeWiltDesc,
          onTap: () => _pushPairThenChats(context, timeWilt: true),
        ),
        _HubCard(
          icon: Icons.qr_code_scanner,
          title: l10n.qrConnectTitle,
          subtitle: l10n.qrConnect7DayNotice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QrPairingScreen()),
          ),
        ),
        const SizedBox(height: 22),
        _sectionLabel(t, l10n.connectSectionGroups),
        const SizedBox(height: 8),
        _HubCard(
          icon: Icons.group_add_outlined,
          title: l10n.connectByteBudgetGroupTitle,
          subtitle: l10n.connectByteBudgetGroupDesc,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateGroupScreen()),
          ),
        ),
        _HubCard(
          icon: Icons.hourglass_bottom,
          title: l10n.connectTimeWiltGroupTitle,
          subtitle: l10n.connectTimeWiltGroupDesc,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateGroupScreen(timeWilt: true),
            ),
          ),
        ),
        _HubCard(
          icon: Icons.groups_outlined,
          title: l10n.connectJoinGroupTitle,
          subtitle: l10n.connectJoinGroupDesc,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GroupSearchScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialTab(WiltkeyTokens t, AppLocalizations l10n) {
    if (!_appState.socialAccountEnabled) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.radiusCard),
              border: Border.all(color: t.action.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.public, color: t.action, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.onboardingSocialTitle ?? 'WiltKey Social Hub',
                        style: t.screenTitle.copyWith(fontSize: 17),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.onboardingSocialExplanation ??
                      'Enables your WiltKey Social profile and server-assisted discovery. Your public identity key is registered with the relay (and can be permanently revoked/wiped anytime by you) to verify authorship of 24h Wilting Stories and broadcast posts. All content remains zero-knowledge end-to-end encrypted.',
                  style: t.bodySecondary.copyWith(height: 1.5, fontSize: 13),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      t.uppercaseLabels ? 'ENABLE WILTKEY SOCIAL' : 'Enable WiltKey Social',
                      style: t.body.copyWith(fontWeight: FontWeight.bold, color: t.onAction),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.action,
                      foregroundColor: t.onAction,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                    ),
                    onPressed: () async {
                      await _appState.setSocialAccountEnabled(true);
                      await _appState.setStoriesEnabled(true);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final budget = _appState.socialBudget;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      children: [
        _sectionLabel(t, 'Ephemeral Stories & Media'),
        const SizedBox(height: 8),
        _HubCard(
          icon: Icons.auto_stories_outlined,
          title: '24-Hour Wilting Story',
          subtitle: 'Broadcast a disappearing text, photo, or pixel art to your mutual contacts.',
          onTap: () => CreateStorySheet.show(context),
        ),
        _HubCard(
          icon: Icons.cell_tower,
          title: 'Public Beacon Broadcast',
          subtitle: 'Location-anchored public posts and proximity discovery in a future update.',
          soon: true,
        ),
        const SizedBox(height: 22),
        _sectionLabel(t, 'Weekly Data Quota'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.radiusCard),
            border: Border.all(color: t.border, width: t.borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Weekly Encrypted Budget',
                    style: t.body.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${budget?.usedMbFormatted ?? '0.0'} / ${budget?.maxMbFormatted ?? '10'} MB',
                    style: t.dataMono.copyWith(fontSize: 12, color: t.action),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: budget?.usedFraction ?? 0.0,
                  backgroundColor: t.border,
                  valueColor: AlwaysStoppedAnimation<Color>(t.action),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Zero-knowledge relay encrypted',
                    style: t.bodySecondary.copyWith(fontSize: 11),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                    child: Text(
                      'Manage in Settings →',
                      style: t.dataMono.copyWith(fontSize: 11, color: t.action),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Pushing the pairing flow (rather than swapping a tab) means its BLE manager
  /// lives only while the screen is up. On a successful pair the screen pops
  /// `true`; the hub — which unlike the pushed route is still a shell descendant
  /// — then jumps to Chats.
  Future<void> _pushPairThenChats(
    BuildContext context, {
    bool timeWilt = false,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PairingScreen(timeWilt: timeWilt)),
    );
    if (result == true && context.mounted) {
      AppShell.of(context).selectTab(ShellTab.chats);
    }
  }

  Widget _sectionLabel(WiltkeyTokens t, String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          t.uppercaseLabels ? text.toUpperCase() : text,
          style: t.sectionLabel.copyWith(color: t.textSecondary),
        ),
      );
}

/// A single tappable mode row. When [soon] is true it renders disabled with a
/// SOON chip and ignores taps (the mode isn't built yet).
class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool soon;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.soon = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final Color tint = t.action;
    final bool disabled = soon || onTap == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusCard),
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(
                color: disabled ? t.border : tint.withValues(alpha: 0.35),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(t.radiusCard),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (disabled ? t.textTertiary : tint)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                  child: Icon(
                    icon,
                    color: disabled ? t.textTertiary : tint,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: t.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: disabled
                                    ? t.textSecondary
                                    : t.textPrimary,
                              ),
                            ),
                          ),
                          if (soon) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: t.action.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(t.radiusControl),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.connectBadgeSoon,
                                style: t.sectionLabel.copyWith(
                                  color: t.action,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle, style: t.bodySecondary),
                    ],
                  ),
                ),
                if (!disabled) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: t.textTertiary, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
