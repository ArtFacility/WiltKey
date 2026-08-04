import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../shell/presentation/app_shell.dart';
import '../../groups/presentation/create_group_screen.dart';
import '../../groups/presentation/group_search_screen.dart';
import 'pairing_screen.dart';
// TEMPORARY (see kRemotePairingTesting): debug-only remote entries.
import 'package:wiltkey_client/core/build_flavor.dart';
import 'remote_pair_tab.dart';
import 'remote_group_pair_view.dart';

/// The Pair-tab landing: a menu of every way to start (or join) a chat, grouped
/// by one-on-one vs group. Deliberately mounts no BLE — nothing scans until the
/// user actually picks an in-person mode and pushes into it. This replaced the
/// old "land straight in BLE proximity" behaviour and, by giving groups a
/// first-class home here, fixes the "nobody knew groups existed" discoverability
/// gap (they were buried under a '+' popup on the chat list).
///
/// Stateful with its own [AppState] listener (like [ChatsTab]) so the debug
/// remote rows show/hide the instant the debug toggle flips, without relying on
/// a parent rebuild.
class ConnectHubScreen extends StatefulWidget {
  const ConnectHubScreen({super.key});

  @override
  State<ConnectHubScreen> createState() => _ConnectHubScreenState();
}

class _ConnectHubScreenState extends State<ConnectHubScreen> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onState);
  }

  @override
  void dispose() {
    _appState.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    // Read live so flipping the debug toggle shows/hides the remote rows.
    final showRemote =
        kRemotePairingTesting && kPlayStore && _appState.showDebugButtons;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          t.uppercaseLabels ? l10n.navPair.toUpperCase() : l10n.navPair,
          style: t.screenTitle.copyWith(fontSize: 18),
        ),
        backgroundColor: t.bg,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
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
          if (showRemote)
            _HubCard(
              icon: Icons.cloud_sync_outlined,
              title: l10n.connectRemotePairTitle,
              subtitle: l10n.connectRemotePairDesc,
              accent: t.warning,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RemotePairScreen()),
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
            soon: true,
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
          if (showRemote)
            _HubCard(
              icon: Icons.cloud_download_outlined,
              title: l10n.connectJoinRemoteGroupTitle,
              subtitle: l10n.connectJoinRemoteGroupDesc,
              accent: t.warning,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RemoteGroupJoinView()),
              ),
            ),
        ],
      ),
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
  final Color? accent;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.soon = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final Color tint = accent ?? t.action;
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
