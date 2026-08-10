import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/theme/wk.dart';
import '../../chat/presentation/chat_screen.dart';

/// Full-screen profile for a social contact (or self).
/// Renders with the peer's theme (derived from shared secret seed) when viewing
/// another contact; uses the current theme for self-profile.
class ContactProfileScreen extends StatefulWidget {
  final SocialContact? contact;
  final bool isSelf;

  const ContactProfileScreen({
    super.key,
    this.contact,
    this.isSelf = false,
  }) : assert(contact != null || isSelf);

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  final AppState _appState = AppState();

  int get _seed {
    if (widget.isSelf) {
      return _appState.userId.codeUnits.fold(0, (a, b) => (a + b) & 0x7fffffff);
    }
    return widget.contact!.keyHash.codeUnits.fold(0, (a, b) => (a + b) & 0x7fffffff);
  }

  String _avatarHex() {
    if (widget.isSelf) {
      if (_appState.profileImageB64.isNotEmpty) return _appState.profileImageB64;
      return PixelArtAvatar.generateIdenticon(_appState.userId);
    }
    if (widget.contact!.profileImageB64 != null &&
        widget.contact!.profileImageB64!.isNotEmpty) {
      return widget.contact!.profileImageB64!;
    }
    return PixelArtAvatar.generateIdenticon(widget.contact!.keyHash);
  }

  String _name() {
    return widget.isSelf ? _appState.effectiveDeviceName : widget.contact!.name;
  }

  String _shortNick() {
    return widget.isSelf ? _appState.effectiveShortNick : (widget.contact!.shortNick ?? '');
  }

  String? _avatarBorderId() {
    return widget.isSelf ? _appState.equippedAvatarBorderId : widget.contact!.avatarBorderId;
  }

  void _openChat() {
    if (widget.isSelf || widget.contact == null) return;
    Contact? contact;
    for (final c in _appState.contacts) {
      if (c.keyHash == widget.contact!.keyHash) {
        contact = c;
        break;
      }
    }
    if (contact == null) {
      // Chat was deleted/nuked — just show a toast and return
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.wk.surface,
          content: Text(
            AppLocalizations.of(context)!.contactProfileChatNotFound,
            style: context.wk.bodySecondary.copyWith(color: context.wk.danger),
          ),
        ),
      );
      return;
    }
    final chatId = contact.id;
    _appState.selectContact(contact);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    ).then((_) => _appState.clearVisibleChatIfCurrent(chatId));
  }

  void _removeContact() {
    if (widget.isSelf || widget.contact == null) return;
    final l10n = AppLocalizations.of(context)!;
    final t = context.wk;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border, width: t.borderWidth),
        ),
        title: Text(
          l10n.contactRemoveConfirmTitle(widget.contact!.name),
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
              _appState.removeSocialContact(widget.contact!.keyHash);
              Navigator.pop(context); // Close profile screen
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

  void _blockContact() {
    if (widget.isSelf || widget.contact == null) return;
    final l10n = AppLocalizations.of(context)!;
    final t = context.wk;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border, width: t.borderWidth),
        ),
        title: Text(
          l10n.contactBlockConfirmTitle(widget.contact!.name),
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
              _appState.blockContact(widget.contact!.keyHash);
              Navigator.pop(context); // Close profile screen
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

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final isSelf = widget.isSelf;

    return context.wkc.profileBackdrop(
      seed: _seed,
      child: Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          isSelf
              ? (t.uppercaseLabels ? l10n.contactsOwnProfile.toUpperCase() : l10n.contactsOwnProfile)
              : widget.contact!.name,
          style: t.screenTitle.copyWith(fontSize: 18),
        ),
        backgroundColor: t.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.of(context).viewPadding.bottom,
        ),
        children: [
          // Header with large avatar
          Center(
            child: Column(
              children: [
                PixelArtAvatar(
                  hexString: _avatarHex(),
                  size: 96,
                  borderId: _avatarBorderId(),
                ),
                const SizedBox(height: 16),
                Text(
                  _name(),
                  style: t.screenTitle.copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                if (_shortNick().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.action.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(t.radiusPill),
                    ),
                    child: Text(
                      '@${_shortNick()}',
                      style: t.badgeLabel.copyWith(color: t.action, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Status / Wilting story section (future)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border, width: t.borderWidth),
              borderRadius: BorderRadius.circular(t.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSelf
                      ? l10n.contactsOwnProfileHint
                      : l10n.contactProfileStatusPlaceholder,
                  style: t.bodySecondary,
                ),
                const SizedBox(height: 12),
                // Placeholder for status/story input
                TextField(
                  enabled: isSelf,
                  maxLines: 3,
                  style: t.body,
                  decoration: InputDecoration(
                    hintText: isSelf
                        ? l10n.contactsOwnProfileHint
                        : l10n.contactProfileStatusPlaceholder,
                    hintStyle: t.body.copyWith(color: t.textTertiary),
                    filled: true,
                    fillColor: t.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                      borderSide: BorderSide(color: t.border, width: t.borderWidth),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                      borderSide: BorderSide(color: t.border, width: t.borderWidth),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                      borderSide: BorderSide(color: t.action, width: t.borderWidth),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Action buttons (not for self)
          if (!isSelf) ...[
            _ActionButton(
              icon: Icons.chat_bubble_outline,
              label: l10n.contactProfileOpenChat,
              color: t.action,
              onPressed: _openChat,
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.person_remove_outlined,
              label: l10n.contactProfileRemove,
              color: t.warning,
              onPressed: _removeContact,
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.block,
              label: l10n.contactProfileBlock,
              color: t.danger,
              onPressed: _blockContact,
            ),
          ],
        ],
      ),
    ),
  );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 20, color: color),
        label: Text(
          label,
          style: t.badgeLabel.copyWith(color: color, fontSize: 13),
        ),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusControl),
          ),
        ),
      ),
    );
  }
}