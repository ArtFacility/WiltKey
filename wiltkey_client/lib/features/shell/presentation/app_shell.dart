import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/security/security_service.dart';
import '../../../core/theme/wk.dart';
import '../../dashboard/presentation/chats_tab.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/presentation/group_chat_screen.dart';
import '../../chat/presentation/widgets/screenshot_ui.dart';
import '../../proximity/presentation/connect_hub_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../contacts/presentation/contact_list_screen.dart';
import 'wk_bottom_nav.dart';

/// Lets descendants jump to another tab (e.g. a wilted chat row → Pair tab).
abstract class ShellNavigator {
  void selectTab(int index);
}

/// Tab indices, named so call sites don't use magic numbers.
class ShellTab {
  static const int contacts = 0; // far-left panel (swipe-in)
  static const int chats = 1;
  static const int pair = 2;
  static const int settings = 3;
}

/// Root scaffold after unlock: a 4-tab bottom bar (Contacts / Chats / Pair / Settings)
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

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver
    implements ShellNavigator {
  final AppState _appState = AppState();
  int _index = ShellTab.chats;

  // Slide transition between tabs: the outgoing page drifts off while the
  // incoming page slides in from the side the user swiped toward (it starts at
  // ±screen width and eases in). All four tabs stay mounted via Offstage (state
  // is preserved, same as the old IndexedStack) — only the active and in-flight
  // pages are on-stage and translated.
  late final AnimationController _slide;
  int _fromIndex = -1; // <0 when idle, else the outgoing tab index
  late final List<Widget> _tabs = [
    // Social contacts list (friends list) — independent of chat contacts.
    const ContactListScreen(),
    const ChatsTab(),
    // The Connect hub itself mounts no BLE — scanning only starts when the user
    // pushes into an in-person mode from here.
    const ConnectHubScreen(),
    const SettingsScreen(embedded: true),
  ];

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _appState.addListener(_onState);
    WidgetsBinding.instance.addObserver(this);
    // The shell mounts right after unlock — if we were opened from a message
    // notification, deep-link straight into that chat.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingChat());
    // One-shot heads-up if a third-party accessibility service can read the
    // screen (informational, not a block).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWarnAccessibility());
    // A peer asking to screenshot a chat with us → show the Allow/Deny prompt
    // here (works regardless of which tab/screen is on top).
    _appState.incomingScreenshotRequest.addListener(_onScreenshotRequest);
    // Archive Time Wilt chats that expired while the app was closed.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _appState.sweepTimeWiltChats());
  }

  /// Peer requested consent for a screenshot → surface the dialog once.
  void _onScreenshotRequest() {
    final req = _appState.incomingScreenshotRequest.value;
    if (req == null || !mounted) return;
    _appState.incomingScreenshotRequest.value = null;
    showScreenshotConsentDialog(context, req);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A notification tapped while the app was already running (warm) doesn't
    // re-run initState, so the deep-link would otherwise be missed — the stashed
    // target chat sits unopened and its unread badge lingers. Re-check on resume.
    if (state == AppLifecycleState.resumed) {
      // Opening the app lands on the Chats tab — unless the user is mid-
      // activity (a pushed screen: chat, editor, composer…). Tabs alone are
      // not "mid-activity": whatever tab was left showing (e.g. Connect) used
      // to greet every app reopen.
      if (mounted && !Navigator.of(context).canPop()) {
        selectTab(ShellTab.chats);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingChat());
      // The user may have enabled an accessibility service while away.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeWarnAccessibility());
      // Re-arm wilting countdowns (timers don't survive backgrounding) and wilt
      // anything whose lifetime elapsed while we were away.
      _appState.sweepAndArmWilting(force: true);
      // Archive any Time Wilt chats whose lifetime elapsed while away.
      _appState.sweepTimeWiltChats();
    }
  }

  // Session-scoped guards so the accessibility warning shows at most once and
  // never stacks: dismissed once → not shown again until the app restarts.
  bool _a11yWarningActive = false;
  bool _a11yWarningDismissed = false;

  /// Surfaces a soft, dismissible warning when a non-allowlisted accessibility
  /// service is active. Fail-open (see [SecurityService]); never blocks the UI.
  Future<void> _maybeWarnAccessibility() async {
    if (_a11yWarningDismissed || _a11yWarningActive) return;
    final res = await SecurityService.checkAccessibility();
    if (!res.unsafe ||
        !mounted ||
        _a11yWarningActive ||
        _a11yWarningDismissed) {
      return;
    }
    _a11yWarningActive = true;
    final l10n = AppLocalizations.of(context)!;
    final names = res.labels.join(', ');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accessibilityWarningTitle),
        content: Text(l10n.accessibilityWarningBody(names)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              SecurityService.openAccessibilitySettings();
            },
            child: Text(l10n.accessibilityWarningOpenSettings),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.accessibilityWarningDismiss),
          ),
        ],
      ),
    );
    _a11yWarningActive = false;
    _a11yWarningDismissed = true;
  }

  // Guards against the cold-start postFrame and a near-simultaneous resume both
  // consuming the pending key before either clears it (which would double-push).
  bool _consumingPending = false;

  /// Opens the chat a tapped notification targeted (1:1 only; group frames carry
  /// a member id that won't resolve, so they harmlessly fall back to the list).
  Future<void> _openPendingChat() async {
    if (_consumingPending) return;
    _consumingPending = true;
    try {
      final key = await WiltkeyNotifications.takePendingChat();
      if (key == null || !mounted) return;
      final idx = _appState.contacts.indexWhere((c) => c.keyHash == key);
      if (idx == -1) return;
      final Contact c = _appState.contacts[idx];
      _appState.selectContact(c);
      if (!mounted) return;
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) =>
                  c.isGroup ? const GroupChatScreen() : const ChatScreen(),
            ),
          )
          .then((_) => _appState.clearVisibleChatIfCurrent(c.id));
    } finally {
      _consumingPending = false;
    }
  }

  @override
  void dispose() {
    _appState.removeListener(_onState);
    _appState.incomingScreenshotRequest.removeListener(_onScreenshotRequest);
    WidgetsBinding.instance.removeObserver(this);
    _slide.dispose();
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  @override
  void selectTab(int index) {
    if (index == _index || index < 0 || index >= _tabs.length) return;
    // Reduced-motion users get an instant switch instead of the slide.
    if (context.reduceMotion) {
      setState(() {
        _fromIndex = -1;
        _index = index;
      });
      return;
    }
    _slide.stop();
    setState(() {
      _fromIndex = _index;
      _index = index;
    });
    _slide.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _fromIndex = -1);
    });
  }

  /// Positions one tab during the slide transition. When idle only the active
  /// tab is on-stage at offset 0; while animating the outgoing tab drifts off
  /// one side while the incoming tab slides in from the other. Offstage keeps
  /// every tab mounted+laid out so per-tab state (scroll, BLE, search) survives.
  Widget _buildSlideableTab(
    int i,
    double width,
    bool animating,
    int from,
    double t,
    double dir,
  ) {
    final bool visible;
    double dx = 0;
    if (animating) {
      visible = i == from || i == _index;
      if (i == _index) {
        dx = dir * width * (1 - t);
      } else if (i == from) {
        dx = -dir * width * t;
      }
    } else {
      visible = i == _index;
    }
    return Offstage(
      offstage: !visible,
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: _tabs[i],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_appState.status == AppStatus.nuked) {
      return _NukedView(onReset: _appState.resetApp);
    }

    return _ShellScope(
      navigator: this,
      child: Scaffold(
        body: Column(
          children: [
            // Unmistakable marker when connected to a WK_TEST_MODE relay:
            // test data lives in an isolated DB, but it must never be
            // mistaken for production activity.
            if (_appState.relayIsTest) const _TestRelayBanner(),
            // A live session lost its device token and is re-issuing (PoW,
            // seconds-long). Explain it instead of silently stalling chat.
            if (_appState.showReauthenticatingBanner)
              const _ReauthenticatingBanner(),
            Expanded(
              child: context.wkc.ambientBackground(
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      AnimatedBuilder(
                        animation: _slide,
                        builder: (context, _) {
                          final double width =
                              MediaQuery.sizeOf(context).width;
                          final bool animating = _fromIndex >= 0;
                          final int from = _fromIndex;
                          final double t =
                              Curves.easeOutCubic.transform(_slide.value);
                          final double dir =
                              animating ? (_index - from).sign.toDouble() : 0;
                          return Stack(
                            children: [
                              for (int i = 0; i < _tabs.length; i++)
                                _buildSlideableTab(
                                    i, width, animating, from, t, dir),
                            ],
                          );
                        },
                      ),
                      // In-app heads-up for messages that land while the app is open and
                      // you're not in that chat (so busy users aren't blind to them).
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _MessageBannerHost(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: WkBottomNavBar(
          currentIndex: _index,
          onTap: selectTab,
          items: [
            WkNavItem(
              Icons.people_outline,
              AppLocalizations.of(context)!.navContacts,
            ),
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

class _ShellScope extends InheritedWidget {
  final ShellNavigator navigator;
  const _ShellScope({required this.navigator, required super.child});

  @override
  bool updateShouldNotify(_ShellScope old) => navigator != old.navigator;
}

/// Slim persistent strip shown while connected to a WK_TEST_MODE relay.
class _TestRelayBanner extends StatelessWidget {
  const _TestRelayBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.amber.shade700,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.science, size: 15, color: Colors.black87),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.testRelayBanner,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim strip while a previously-authenticated session re-issues its device
/// token (PoW runs for seconds). Normal token reconnects never show this.
class _ReauthenticatingBanner extends StatelessWidget {
  const _ReauthenticatingBanner();

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Material(
      color: t.action,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  valueColor: AlwaysStoppedAnimation(t.onAction),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.reauthenticatingBanner,
                style: TextStyle(
                  color: t.onAction,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top heads-up banner for messages arriving while the app is open. Listens to
/// [AppState.messageAlert] (which only fires for a real user message landing in a
/// chat you aren't currently viewing), slides a compact card in from the top,
/// auto-dismisses after a few seconds, and deep-links into the chat on tap.
class _MessageBannerHost extends StatefulWidget {
  const _MessageBannerHost();

  @override
  State<_MessageBannerHost> createState() => _MessageBannerHostState();
}

class _MessageBannerHostState extends State<_MessageBannerHost>
    with SingleTickerProviderStateMixin {
  final AppState _appState = AppState();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  InAppMessageAlert? _displayed; // kept during the slide-out after clearing
  int? _shownSeq;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _appState.messageAlert.addListener(_onAlert);
  }

  void _onAlert() {
    final alert = _appState.messageAlert.value;
    if (alert == null) {
      _slideOut();
      return;
    }
    if (alert.seq == _shownSeq) return; // already showing this one
    setState(() {
      _displayed = alert;
      _shownSeq = alert.seq;
    });
    _anim.forward();
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      _appState.messageAlert.value = null; // → _onAlert → _slideOut
    });
  }

  void _slideOut() {
    _dismissTimer?.cancel();
    if (_anim.status == AnimationStatus.dismissed) return;
    _anim.reverse().then((_) {
      if (mounted) setState(() => _displayed = null);
    });
  }

  void _open(Contact c) {
    _dismissTimer?.cancel();
    _appState.messageAlert.value = null;
    _appState.selectContact(c);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                c.isGroup ? const GroupChatScreen() : const ChatScreen(),
          ),
        )
        .then((_) => _appState.clearVisibleChatIfCurrent(c.id));
  }

  @override
  void dispose() {
    _appState.messageAlert.removeListener(_onAlert);
    _dismissTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  String _avatarHex(Contact c) {
    if (c.isGroup && c.groupIconHex != null && c.groupIconHex!.isNotEmpty) {
      return c.groupIconHex!;
    }
    if (c.profileImageB64 != null && c.profileImageB64!.isNotEmpty) {
      return c.profileImageB64!;
    }
    return PixelArtAvatar.generateIdenticon(c.keyHash);
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayed;
    if (displayed == null) return const SizedBox.shrink();
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final c = displayed.contact;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_anim.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, -16 * (1 - v)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Dismissible(
          key: ValueKey('msg_banner_${displayed.seq}'),
          direction: DismissDirection.up,
          onDismissed: (_) => _appState.messageAlert.value = null,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(t.radiusCard),
              onTap: () => _open(c),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(t.radiusCard),
                  border: Border.all(color: t.action, width: t.borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    PixelArtAvatar(
                      hexString: _avatarHex(c),
                      size: 38,
                      borderId: c.avatarBorderId,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.notificationNewMessageBody,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: t.textTertiary, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
