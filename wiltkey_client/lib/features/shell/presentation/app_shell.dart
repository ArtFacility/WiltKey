import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/wk.dart';
import '../../dashboard/presentation/chats_tab.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/presentation/group_chat_screen.dart';
import '../../proximity/presentation/pairing_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'wk_bottom_nav.dart';

/// Lets descendants jump to another tab (e.g. a wilted chat row → Pair tab).
abstract class ShellNavigator {
  void selectTab(int index);
}

/// Tab indices, named so call sites don't use magic numbers.
class ShellTab {
  static const int chats = 0;
  static const int pair = 1;
  static const int settings = 2;
}

/// Root scaffold after unlock: a 3-tab bottom bar (Chats / Pair / Settings)
/// over an [IndexedStack]. Replaces the old DashboardScreen + pushed Settings +
/// pushed Pairing chrome.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Access the nearest shell to switch tabs.
  static ShellNavigator of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ShellScope>();
    assert(scope != null, 'AppShell.of() called outside an AppShell');
    return scope!.navigator;
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> implements ShellNavigator {
  final AppState _appState = AppState();
  int _index = ShellTab.chats;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onState);
    // The shell mounts right after unlock — if we were opened from a message
    // notification, deep-link straight into that chat.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingChat());
  }

  /// Opens the chat a tapped notification targeted (1:1 only; group frames carry
  /// a member id that won't resolve, so they harmlessly fall back to the list).
  Future<void> _openPendingChat() async {
    final key = await WiltkeyNotifications.takePendingChat();
    if (key == null || !mounted) return;
    final idx = _appState.contacts.indexWhere((c) => c.keyHash == key);
    if (idx == -1) return;
    final Contact c = _appState.contacts[idx];
    _appState.selectContact(c);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            c.isGroup ? const GroupChatScreen() : const ChatScreen(),
      ),
    );
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
  void selectTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_appState.status == AppStatus.nuked) {
      return _NukedView(onReset: _appState.resetApp);
    }

    return _ShellScope(
      navigator: this,
      child: Scaffold(
        body: context.wkc.ambientBackground(
          child: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _index,
              children: [
                const ChatsTab(),
                // PairTab mounts PairingScreen ONLY while active, so BLE never
                // scans from launch and stops the moment you leave the tab.
                _PairTab(isActive: _index == ShellTab.pair),
                const SettingsScreen(embedded: true),
              ],
            ),
          ),
        ),
        bottomNavigationBar: WkBottomNavBar(
          currentIndex: _index,
          onTap: selectTab,
          items: [
            WkNavItem(
              Icons.chat_bubble_outline,
              AppLocalizations.of(context)!.navChats,
            ),
            WkNavItem(Icons.adjust, AppLocalizations.of(context)!.navPair),
            WkNavItem(
              Icons.settings_outlined,
              AppLocalizations.of(context)!.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mounts the heavyweight [PairingScreen] (and thus its BLE manager) only when
/// the Pair tab is selected. When inactive it renders nothing, so the screen's
/// State (and BLE scanning) is torn down — equivalent to the old push/pop.
class _PairTab extends StatelessWidget {
  final bool isActive;
  const _PairTab({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return isActive ? const PairingScreen() : const SizedBox.shrink();
  }
}

class _ShellScope extends InheritedWidget {
  final ShellNavigator navigator;
  const _ShellScope({required this.navigator, required super.child});

  @override
  bool updateShouldNotify(_ShellScope old) => navigator != old.navigator;
}

class _NukedView extends StatelessWidget {
  final VoidCallback onReset;
  const _NukedView({required this.onReset});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.report_gmailerrorred, color: t.danger, size: 72),
              const SizedBox(height: 16),
              Text(
                t.uppercaseLabels
                    ? l10n.nukedTitle.toUpperCase()
                    : l10n.nukedTitle,
                style: t.screenTitle.copyWith(color: t.danger),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.nukedExplanation,
                textAlign: TextAlign.center,
                style: t.bodySecondary.copyWith(height: 1.6),
              ),
              const SizedBox(height: 36),
              OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.danger,
                  side: BorderSide(color: t.danger, width: 1),
                  minimumSize: const Size(220, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                ),
                child: Text(
                  t.uppercaseLabels
                      ? l10n.nukedResetButton.toUpperCase()
                      : l10n.nukedResetButton,
                  style: t.badgeLabel.copyWith(color: t.danger, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
