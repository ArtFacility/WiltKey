import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/theme/wk.dart';
import '../../../features/shell/presentation/app_shell.dart';
import 'blocked_contacts_screen.dart';
import 'contact_profile_screen.dart';

/// The Contacts tab: a panel showing the user's own profile row at the top,
/// followed by their social contacts (friends list). Accessible via the bottom
/// nav "Contacts" tab and via a left-to-right swipe gesture from the Chats tab.
/// Swipe right-to-left anywhere on this screen to return to Chats.
class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final AppState _appState = AppState();

  // Swipe right-to-left to return to Chats
  static const double _swipeDistanceThreshold = 120.0;
  static const double _swipeVelocityThreshold = 800.0;
  double _dragStartX = 0;
  bool _dragStarted = false;

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

  void _onDragStart(DragStartDetails details) {
    _dragStartX = details.localPosition.dx;
    _dragStarted = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragStarted) return;
    final dx = details.localPosition.dx - _dragStartX;
    if (dx <= -_swipeDistanceThreshold) {
      _openChatsPanel();
      _dragStarted = false;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragStarted) return;
    final dx = details.localPosition.dx - _dragStartX;
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (dx <= -_swipeDistanceThreshold || velocity < -_swipeVelocityThreshold) {
      _openChatsPanel();
    }
    _dragStarted = false;
  }

  void _onDragCancel() {
    _dragStarted = false;
  }

  void _openChatsPanel() {
    if (!mounted) return;
    AppShell.of(context).selectTab(ShellTab.chats);
  }

  void _openSelfProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactProfileScreen(isSelf: true)),
    );
  }

  void _openContactProfile(SocialContact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactProfileScreen(contact: contact),
      ),
    );
  }

  void _showContactActions(SocialContact contact) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                contact.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: contact.isPinned ? t.action : t.textPrimary,
              ),
              title: Text(
                contact.isPinned ? l10n.contactUnpin : l10n.contactPin,
                style: t.body,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _appState.togglePinSocialContact(contact.keyHash);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_remove_outlined, color: t.action),
              title: Text(l10n.contactProfileRemove, style: t.body),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmRemoveContact(contact);
              },
            ),
            ListTile(
              leading: Icon(Icons.block_outlined, color: t.danger),
              title: Text(
                l10n.contactProfileBlock,
                style: t.body.copyWith(color: t.danger),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmBlockContact(contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveContact(SocialContact contact) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border, width: t.borderWidth),
        ),
        title: Text(
          l10n.contactRemoveConfirmTitle(contact.name),
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
        content: Text(
          l10n.contactRemoveConfirmBody,
          style: t.bodySecondary.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel, style: TextStyle(color: t.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _appState.removeSocialContact(contact.keyHash);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: t.onAction,
            ),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
  }

  void _confirmBlockContact(SocialContact contact) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border, width: t.borderWidth),
        ),
        title: Text(
          l10n.contactBlockConfirmTitle(contact.name),
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
        content: Text(
          l10n.contactBlockConfirmBody,
          style: t.bodySecondary.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel, style: TextStyle(color: t.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _appState.blockContact(contact.keyHash);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: t.onAction,
            ),
            child: Text(l10n.commonBlock),
          ),
        ],
      ),
    );
  }

  String _avatarHex(SocialContact c) {
    if (c.profileImageB64 != null && c.profileImageB64!.isNotEmpty) {
      return c.profileImageB64!;
    }
    return PixelArtAvatar.generateIdenticon(c.keyHash);
  }

  String _ownAvatarHex() {
    if (_appState.profileImageB64.isNotEmpty) {
      return _appState.profileImageB64;
    }
    return PixelArtAvatar.generateIdenticon(_appState.userId);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final contacts = _appState.socialContacts;

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _onDragCancel,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            t.uppercaseLabels ? l10n.contactsTitle.toUpperCase() : l10n.contactsTitle,
            style: t.screenTitle.copyWith(fontSize: 18),
          ),
          backgroundColor: t.bg,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: l10n.settingsBlockedContacts,
              icon: Icon(Icons.block_outlined, color: t.textTertiary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BlockedContactsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                24 + MediaQuery.of(context).viewPadding.bottom,
              ),
              children: [
                // Own profile row (always visible, pinned top)
                _OwnProfileRow(
                  avatarHex: _ownAvatarHex(),
                  name: _appState.effectiveDeviceName,
                  shortNick: _appState.effectiveShortNick,
                  avatarBorderId: _appState.equippedAvatarBorderId,
                  statusEmoji: _appState.effectiveStatusEmoji,
                  statusMessage: _appState.effectiveStatusMessage,
                  onTap: _openSelfProfile,
                ),
                const SizedBox(height: 16),
                if (contacts.isEmpty) ...[
                  // Empty state below the own profile
                  _EmptyState(),
                ] else ...[
                  // Pinned favorites float to the top (DB already orders them
                  // pinned-first); split into its own section when present.
                  if (contacts.any((c) => c.isPinned)) ...[
                    _SectionLabel(text: l10n.contactsSectionPinned),
                    ...contacts
                        .where((c) => c.isPinned)
                        .map((c) => _ContactRow(
                              contact: c,
                              avatarHex: _avatarHex(c),
                              onTap: () => _openContactProfile(c),
                              onLongPress: () => _showContactActions(c),
                            )),
                  ],
                  // Section label
                  _SectionLabel(text: l10n.contactsSectionFriends),
                  // Contact list
                  ...contacts.map((c) => _ContactRow(
                        contact: c,
                        avatarHex: _avatarHex(c),
                        onTap: () => _openContactProfile(c),
                        onLongPress: () => _showContactActions(c),
                      )),
                ],
              ],
            ),
      ),
    );
  }
}

class _OwnProfileRow extends StatelessWidget {
  final String avatarHex;
  final String name;
  final String shortNick;
  final String? avatarBorderId;
  final String statusEmoji;
  final String statusMessage;
  final VoidCallback onTap;

  const _OwnProfileRow({
    required this.avatarHex,
    required this.name,
    required this.shortNick,
    this.avatarBorderId,
    this.statusEmoji = '',
    this.statusMessage = '',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border, width: t.borderWidth),
          borderRadius: BorderRadius.circular(t.radiusCard),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PixelArtAvatar(
                  hexString: avatarHex,
                  size: 56,
                  borderId: avatarBorderId,
                ),
                if (statusEmoji.isNotEmpty)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: t.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.border,
                          width: t.borderWidth,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        statusEmoji,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: t.action.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(t.radiusPill),
                        ),
                        child: Text(
                          shortNick,
                          style: t.badgeLabel.copyWith(color: t.action),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusMessage.isNotEmpty
                        ? statusMessage
                        : AppLocalizations.of(context)!.contactsOwnProfileHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySecondary.copyWith(
                      fontSize: 12,
                      color: statusMessage.isNotEmpty
                          ? t.textPrimary
                          : t.textSecondary,
                    ),
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
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        t.uppercaseLabels ? text.toUpperCase() : text,
        style: t.sectionLabel.copyWith(color: t.textTertiary),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final SocialContact contact;
  final String avatarHex;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ContactRow({
    required this.contact,
    required this.avatarHex,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final status = contact.activeStatus;
    final emoji = contact.activeStatusEmoji;
    final hasStatus =
        (status != null && status.isNotEmpty) ||
        (emoji != null && emoji.isNotEmpty);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border, width: t.borderWidth),
          borderRadius: BorderRadius.circular(t.radiusCard),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PixelArtAvatar(
                  hexString: avatarHex,
                  size: 44,
                  borderId: contact.avatarBorderId,
                ),
                if (emoji != null && emoji.isNotEmpty)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: t.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.border,
                          width: t.borderWidth,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 10)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (contact.isPinned) ...[
                        Icon(Icons.push_pin, size: 14, color: t.action),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          contact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (hasStatus)
                    Text(
                      status ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySecondary.copyWith(
                        fontSize: 12,
                        color: t.textPrimary,
                      ),
                    )
                  else if (contact.shortNick != null &&
                      contact.shortNick!.isNotEmpty)
                    Text(
                      '@${contact.shortNick}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, color: t.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n.contactsEmptyTitle,
              style: t.screenTitle.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.contactsEmptyBody,
              style: t.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}