import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/custom_emoji.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/nuke_capture.dart';
import 'emoji_creator_screen.dart';
import '../../chat/presentation/chat_media_gallery_screen.dart';
import '../../../core/db/wiltkey_db.dart';
import '../../../core/theme/widgets/client_integrity_badge.dart';
import '../../../core/build_flavor.dart';
import '../../../core/entitlements/entitlement_service.dart';
import '../../../core/cosmetics/avatar_border_controller.dart';

/// Group Details screen — opened by tapping the group name/avatar in the chat.
/// Hosts host policies, the custom-emoji manager, the reserved metadata-space
/// readout, and the destructive actions (leave / nuke) that used to sit in the
/// chat app bar.
class GroupSettingsScreen extends StatefulWidget {
  final Contact group;
  const GroupSettingsScreen({super.key, required this.group});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final AppState _appState = AppState();

  /// Captures this screen as the themed nuke overlay's base (see
  /// `captureNukeScreen` / `nukeOverlay(screen: …)`).
  final GlobalKey _nukeCaptureKey = GlobalKey();

  // Host-editable policy state.
  late bool _imagesAllowed;

  List<CustomEmoji> _emojis = [];

  @override
  void initState() {
    super.initState();
    _imagesAllowed = widget.group.imagesAllowed ?? true;
    _appState.addListener(_updateState);
    _loadEmojis();
  }

  @override
  void dispose() {
    _appState.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  Future<void> _loadEmojis() async {
    final list = await CustomEmojiStore.load(widget.group.keyHash);
    if (mounted) setState(() => _emojis = list);
  }

  // --- Host policy save -------------------------------------------------------

  void _saveGroupSettings() {
    final t = context.wk;
    setState(() {
      final idx = _appState.contacts.indexWhere(
        (c) => c.keyHash == widget.group.keyHash,
      );
      if (idx != -1) {
        final existing = _appState.contacts[idx];
        // copyWith (not a manual rebuild) so fields the policy editor doesn't
        // touch — Time Wilt lifetime/expiry, recharge-pending, etc. — survive.
        _appState.contacts[idx] = existing.copyWith(
          imagesAllowed: _imagesAllowed,
        );
        _appState.notifyMessageReceived();
        _appState.broadcastGroupMetadataUpdate(_appState.contacts[idx]);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: t.surface,
        content: Text(
          AppLocalizations.of(context)!.groupDetailsSavePoliciesSnackBar,
          style: TextStyle(color: t.action),
        ),
      ),
    );
  }

  // --- Custom emojis ----------------------------------------------------------

  Future<void> _createEmoji() async {
    final t = context.wk;
    final emoji = await Navigator.push<CustomEmoji?>(
      context,
      MaterialPageRoute(
        builder: (_) => EmojiCreatorScreen(chatKey: widget.group.keyHash),
      ),
    );
    if (emoji != null) {
      final err = await _appState.defineEmoji(widget.group, emoji);
      await _loadEmojis();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: t.surface,
            content: Text(
              err == null ? l10n.chatDetailsAddEmojiSnackBar(emoji.name) : err,
              style: TextStyle(color: err == null ? t.action : t.danger),
            ),
          ),
        );
      }
    }
  }

  void _deleteEmoji(CustomEmoji emoji) {
    if (emoji.deleted) return; // already a tombstone
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.danger, width: 1),
        ),
        title: Text(
          t.uppercaseLabels
              ? l10n.chatDetailsDeleteEmojiTitle.toUpperCase()
              : l10n.chatDetailsDeleteEmojiTitle,
          style: t.screenTitle.copyWith(color: t.danger, fontSize: 16),
        ),
        content: Text(l10n.chatDetailsDeleteEmojiBody, style: t.bodySecondary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: t.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _appState.deleteChatEmoji(widget.group, emoji.name);
              await _loadEmojis();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.chatDetailsDeleteEmojiDelete),
          ),
        ],
      ),
    );
  }

  // --- Destructive ------------------------------------------------------------

  void _leaveGroup() {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.danger, width: 1.5),
        ),
        title: Text(
          t.uppercaseLabels
              ? l10n.groupLeaveGroupTitle.toUpperCase()
              : l10n.groupLeaveGroupTitle,
          style: t.screenTitle.copyWith(color: t.danger, fontSize: 16),
        ),
        content: Text(l10n.groupLeaveGroupBody, style: t.bodySecondary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: t.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await CustomEmojiStore.clear(widget.group.keyHash);
              await _appState.nukeContact(
                widget.group.keyHash,
                receivedFromPeer: false,
              );
              if (!mounted) return;
              Navigator.pop(context); // details
              Navigator.pop(context); // chat
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.groupLeaveGroup),
          ),
        ],
      ),
    );
  }

  void _nukeGroup() {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    // "Destroy for everyone" is a majority VOTE when there are other members —
    // one member can't unilaterally wipe everyone's history. A solo group (no
    // other members) is destroyed immediately.
    final bool hasPeers = widget.group.memberKeyHashes
        .where((h) => h != _appState.userId)
        .isNotEmpty;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.danger, width: 1.5),
        ),
        title: Text(
          () {
            final s = hasPeers
                ? l10n.groupNukeProposeTitle
                : l10n.groupDetailsDeleteConfirmTitle;
            return t.uppercaseLabels ? s.toUpperCase() : s;
          }(),
          style: t.screenTitle.copyWith(color: t.danger, fontSize: 16),
        ),
        content: Text(
          hasPeers
              ? l10n.groupNukeProposeBody
              : l10n.groupDetailsDeleteConfirmBody,
          style: t.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: t.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (hasPeers) {
                _proposeGroupNuke();
              } else {
                _playNukeAndDestroy();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(
              hasPeers
                  ? l10n.groupNukeProposeConfirm
                  : l10n.groupDetailsDeleteConfirmButton,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(Contact group) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border),
        ),
        title: Text(
          t.uppercaseLabels
              ? l10n.chatDetailsClearHistoryConfirm.toUpperCase()
              : l10n.chatDetailsClearHistoryConfirm,
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
        content: Text(
          l10n.chatDetailsClearHistoryDialogBody,
          style: t.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: t.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await WiltkeyDatabase.instance.deleteMessagesForChat(group.id);
              await _appState.loadMessagesForContact(group);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: t.surface,
                  content: Text(
                    l10n.chatDetailsClearHistorySuccess,
                    style: TextStyle(color: t.action),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.chatDetailsClearHistoryConfirm),
          ),
        ],
      ),
    );
  }

  /// Send a "destroy for everyone" proposal to the other members and return to
  /// the chat, where the outcome (a member's card / the tally) plays out. The
  /// group is NOT destroyed here — only a passing majority vote wipes it.
  Future<void> _proposeGroupNuke() async {
    final l10n = AppLocalizations.of(context)!;
    await _appState.proposeGroupNuke(widget.group);
    if (!mounted) return;
    Navigator.of(context).pop(); // back to the chat
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.groupNukeVoteSent)),
    );
  }

  /// Plays the theme's nuke animation over the screen, then full-mesh nukes the
  /// group (every member is wiped — see AppState.nukeGroup) and exits to root.
  void _playNukeAndDestroy() async {
    final group = widget.group;

    // Capture the screen before covering it, for themes that use the real
    // screen as their destruction base.
    final screen = await captureNukeScreen(_nukeCaptureKey);
    if (!mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final wkc = context.wkc;
    final themeData = Theme.of(context);
    final navigator = Navigator.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Theme(
          data: themeData,
          child: wkc.nukeOverlay(
            screen: screen,
            onDone: () async {
              entry.remove();
              await CustomEmojiStore.clear(group.keyHash);
              await _appState.nukeGroup(group);
              navigator.popUntil((route) => route.isFirst);
            },
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }

  // --- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final group = widget.group;
    final isHost = group.isHost;

    return RepaintBoundary(
      key: _nukeCaptureKey,
      child: Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          t.uppercaseLabels
              ? l10n.groupDetailsTitle.toUpperCase()
              : l10n.groupDetailsTitle,
          style: t.screenTitle.copyWith(fontSize: 18),
        ),
        backgroundColor: t.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.action),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  PixelArtAvatar(
                    hexString:
                        group.groupIconHex ??
                        PixelArtAvatar.generateIdenticon(group.keyHash),
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    group.name,
                    style: t.body.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.groupDetailsSharedPadHost(group.hostName ?? "—"),
                    style: t.dataMono.copyWith(color: t.textTertiary),
                  ),
                ],
              ),
            ),
            Divider(color: t.border, height: 24),

            // Group Members with Client Attestation Badges
            _buildMembersSection(t),
            Divider(color: t.border, height: 32),

            // Notification Preference
            _sectionTitle(t, l10n.chatNotificationSettingsTitle, t.action),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: _panelDeco(t),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'all',
                    groupValue: group.notificationMode,
                    activeColor: t.action,
                    title: Text(l10n.chatNotificationModeAll, style: t.body),
                    onChanged: (val) {
                      if (val != null) {
                        _appState.setChatNotificationMode(group, val);
                        setState(() {});
                      }
                    },
                  ),
                  Divider(color: t.border, height: 1, indent: 16, endIndent: 16),
                  RadioListTile<String>(
                    value: 'mentions_only',
                    groupValue: group.notificationMode,
                    activeColor: t.action,
                    title: Text(l10n.chatNotificationModeMentions, style: t.body),
                    onChanged: (val) {
                      if (val != null) {
                        _appState.setChatNotificationMode(group, val);
                        setState(() {});
                      }
                    },
                  ),
                  Divider(color: t.border, height: 1, indent: 16, endIndent: 16),
                  RadioListTile<String>(
                    value: 'muted',
                    groupValue: group.notificationMode,
                    activeColor: t.danger,
                    title: Text(
                      l10n.chatNotificationModeMuted,
                      style: t.body.copyWith(
                        color: group.notificationMode == 'muted' ? t.danger : null,
                      ),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        _appState.setChatNotificationMode(group, val);
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
            Divider(color: t.border, height: 32),

            // Host policies
            if (isHost) ...[
              _sectionTitle(t, l10n.groupDetailsSectionEditPolicies, t.action),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: _panelDeco(t),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            l10n.groupCreatePolicyAllowImages,
                            style: t.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _imagesAllowed,
                          activeThumbColor: t.identity,
                          onChanged: (val) =>
                              setState(() => _imagesAllowed = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saveGroupSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.positive,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.groupDetailsSavePoliciesButton),
              ),
              const SizedBox(height: 24),
            ],

            // Custom emojis
            _buildEmojiSection(t),
            const SizedBox(height: 24),

            // Metadata space (reserved info lane)
            _buildMetadataSection(t),
            const SizedBox(height: 24),

            // Non-host: global sync
            if (!isHost) ...[
              _sectionTitle(t, l10n.groupDetailsSectionSync, t.action),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: _panelDeco(t),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.groupDetailsSyncExplanation,
                      style: t.bodySecondary,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        _appState.requestGroupMetadata(group);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: t.surface,
                            content: Text(
                              l10n.groupDetailsSyncSnackBar,
                              style: TextStyle(color: t.action),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.sync, size: 14),
                      label: Text(l10n.groupDetailsSyncButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.positive,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Media, Voice & Links Gallery
            _sectionTitle(t, l10n.chatDetailsSectionMedia, t.action),
            const SizedBox(height: 10),
            Container(
              decoration: _panelDeco(t),
              child: ListTile(
                leading: Icon(Icons.perm_media_outlined, color: t.action),
                title: Text(
                  l10n.chatDetailsSectionMedia,
                  style: t.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                trailing: Icon(Icons.chevron_right, color: t.textTertiary),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatMediaGalleryScreen(contact: group),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // History cleanup
            _sectionTitle(t, l10n.chatDetailsClearHistory, t.textSecondary),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _panelDeco(t),
              child: Row(
                children: [
                  Icon(Icons.cleaning_services_outlined, color: t.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.chatDetailsClearHistory,
                      style: t.body.copyWith(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _confirmClearHistory(group),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.textSecondary,
                      side: BorderSide(color: t.border),
                    ),
                    child: Text(l10n.chatDetailsClearHistoryConfirm),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Destructive
            _sectionTitle(t, l10n.chatDetailsSectionDestructive, t.danger),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.danger.withValues(alpha: 0.03),
                border: Border.all(color: t.danger.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isHost) ...[
                    ElevatedButton.icon(
                      onPressed: _leaveGroup,
                      icon: const Icon(Icons.exit_to_app, size: 14),
                      label: Text(l10n.groupLeaveGroup),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.danger.withValues(alpha: 0.2),
                        foregroundColor: t.danger,
                        side: BorderSide(color: t.danger),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ElevatedButton.icon(
                    onPressed: _nukeGroup,
                    icon: const Icon(Icons.flash_on, size: 14),
                    label: Text(l10n.groupDetailsNukeButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.danger,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMembersSection(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    final group = widget.group;
    final myUserId = _appState.userId;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: GroupDatabase.instance.getAllProfiles(group.keyHash),
      builder: (context, snapshot) {
        final profiles = snapshot.data ?? [];
        final profileMap = <String, Map<String, dynamic>>{
          for (final p in profiles)
            if (p['member_key_hash'] != null)
              p['member_key_hash'] as String: p,
        };

        // All members in memberKeyHashes
        final allHashes = group.memberKeyHashes.isNotEmpty
            ? group.memberKeyHashes
            : [myUserId];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(
              t,
              '${l10n.groupMembersTitle} (${allHashes.length})',
              t.action,
            ),
            const SizedBox(height: 10),
            // Capped + scrollable: a 20-member group used to grow the section
            // unbounded inside the page scroll, pushing every other setting
            // off-screen.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Container(
                decoration: _panelDeco(t),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: allHashes.length,
                  separatorBuilder: (_, _) => Divider(color: t.border, height: 1),
                  itemBuilder: (context, idx) {
                  final hash = allHashes[idx];
                  final isMe = hash == myUserId;
                  final isHost = hash == group.hostKeyHash;
                  final p = profileMap[hash];

                  final name = isMe
                      ? '${_appState.effectiveDeviceName} (${l10n.contactSelfBadge})'
                      : ((p?['name'] as String?)?.isNotEmpty == true
                          ? p!['name'] as String
                          : l10n.groupAnonymousMember);

                  final avatarHex = isMe
                      ? _appState.profileImageB64
                      : (p?['profile_image'] as String?) ??
                          PixelArtAvatar.generateIdenticon(hash);

                  final borderId = isMe
                      ? AvatarBorderController.instance.borderId
                      : p?['avatar_border'] as String?;

                  final ClientBadgeType badgeType;
                  if (isMe) {
                    badgeType = kPlayStore
                        ? (EntitlementService.instance.plusActive
                            ? ClientBadgeType.playPlus
                            : ClientBadgeType.playOfficial)
                        : ClientBadgeType.tinkerer;
                  } else {
                    final att = p?['client_attestation'] as String?;
                    final exp = p?['attestation_expires_at'] as int?;
                    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                    if (exp != null && exp < nowSec) {
                      badgeType = ClientBadgeType.tinkerer;
                    } else if (att == 'play_plus') {
                      badgeType = ClientBadgeType.playPlus;
                    } else if (att == 'play_official') {
                      badgeType = ClientBadgeType.playOfficial;
                    } else {
                      badgeType = ClientBadgeType.tinkerer;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        PixelArtAvatar(
                          hexString: avatarHex.isNotEmpty
                              ? avatarHex
                              : PixelArtAvatar.generateIdenticon(hash),
                          size: 36,
                          borderId: borderId,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.body.copyWith(
                                    fontWeight: isMe || isHost
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ClientIntegrityBadge(
                                badgeType: badgeType,
                                size: 14,
                              ),
                              if (isHost) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.action.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(t.radiusPill),
                                  ),
                                  child: Text(
                                    l10n.groupMemberRoleHost,
                                    style: t.badgeLabel.copyWith(
                                      color: t.action,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                 },
               ),
             ),
            ),
           ],
         );
       },
     );
   }

  Widget _buildEmojiSection(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle(t, l10n.groupDetailsSectionEmojis, t.identity),
            Text(
              '${_emojis.length}',
              style: t.dataMono.copyWith(
                color: t.identity,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _panelDeco(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.chatDetailsEmojisExplanation, style: t.bodySecondary),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._emojis.map((e) => _buildEmojiTile(t, e)),
                  _buildAddEmojiTile(t),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiTile(WiltkeyTokens t, CustomEmoji emoji) {
    if (emoji.deleted) {
      return Container(
        width: 64,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: t.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(t.radiusControl),
          border: Border.all(color: t.danger.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.close, color: t.danger, size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              ':${emoji.name}:',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.dataMono.copyWith(
                color: t.textTertiary,
                fontSize: 8,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => _deleteEmoji(emoji),
      child: Container(
        width: 64,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(t.radiusControl),
          border: Border.all(color: t.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(
              emoji.bytes,
              width: 40,
              height: 40,
              gaplessPlayback: true,
            ),
            const SizedBox(height: 4),
            Text(
              ':${emoji.name}:',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.dataMono.copyWith(color: t.textSecondary, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddEmojiTile(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: _createEmoji,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: t.identity.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(t.radiusControl),
          border: Border.all(color: t.identity.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: t.identity, size: 22),
            const SizedBox(height: 2),
            Text(
              t.uppercaseLabels
                  ? l10n.chatDetailsEmojisCreate.toUpperCase()
                  : l10n.chatDetailsEmojisCreate,
              style: t.badgeLabel.copyWith(color: t.identity, fontSize: 7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSection(WiltkeyTokens t) {
    final int reserved = AppState.infoLaneSize; // 1 MB reserved info lane
    final int emojiBytes = _emojis.fold<int>(
      0,
      (sum, e) => sum + e.approxBytes,
    );
    final double pct = reserved > 0
        ? (emojiBytes / reserved).clamp(0.0, 1.0)
        : 0.0;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(t, l10n.groupDetailsSectionMetadata, t.action),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _panelDeco(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.groupDetailsMetadataExplanation,
                style: t.bodySecondary,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  color: t.action,
                  backgroundColor: t.budgetEmpty,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.groupDetailsSectionEmojis}: ${AppState.formatBytes(emojiBytes)}',
                    style: t.dataMono.copyWith(
                      color: t.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    'Reserved: ${AppState.formatBytes(reserved)}',
                    style: t.dataMono.copyWith(
                      color: t.textSecondary,
                      fontSize: 9,
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

  Widget _sectionTitle(WiltkeyTokens t, String text, Color color) => Text(
    t.uppercaseLabels ? text.toUpperCase() : _sentence(text),
    style: t.sectionLabel.copyWith(color: color),
  );

  String _sentence(String s) =>
      s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();

  BoxDecoration _panelDeco(WiltkeyTokens t) => BoxDecoration(
    color: t.surface,
    border: Border.all(color: t.border),
    borderRadius: BorderRadius.circular(t.radiusControl),
  );
}
