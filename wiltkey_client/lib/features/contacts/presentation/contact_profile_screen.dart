import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/theme_registry.dart';
import '../../chat/presentation/chat_screen.dart';
import 'status_emoji_picker_sheet.dart';

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
  late final TextEditingController _statusController;
  String _selectedEmoji = '';
  int? _selectedDurationHours;

  @override
  void initState() {
    super.initState();
    _statusController = TextEditingController(
      text: widget.isSelf ? _appState.effectiveStatusMessage : '',
    );
    if (widget.isSelf) {
      _selectedEmoji = _appState.effectiveStatusEmoji;
      if (_appState.statusExpiresAtMs != null && !_appState.isOwnStatusExpired) {
        final leftMs =
            _appState.statusExpiresAtMs! -
            DateTime.now().millisecondsSinceEpoch;
        final leftHours = (leftMs / (1000 * 3600)).round();
        if (leftHours <= 1) {
          _selectedDurationHours = 1;
        } else if (leftHours <= 4) {
          _selectedDurationHours = 4;
        } else if (leftHours <= 24) {
          _selectedDurationHours = 24;
        } else {
          _selectedDurationHours = 48;
        }
      }
    }
  }

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  SocialContact? _currentContact() {
    if (widget.isSelf || widget.contact == null) return null;
    final idx = _appState.socialContacts.indexWhere(
      (c) => c.keyHash == widget.contact!.keyHash,
    );
    if (idx != -1) return _appState.socialContacts[idx];
    return widget.contact;
  }

  String _statusEmoji() {
    if (widget.isSelf) {
      return _selectedEmoji;
    }
    final c = _currentContact();
    return c?.activeStatusEmoji ?? '';
  }

  Future<void> _pickStatusEmoji() async {
    final picked = await showStatusEmojiPickerSheet(
      context,
      currentEmoji: _selectedEmoji,
    );
    if (picked != null) {
      setState(() {
        _selectedEmoji = picked;
      });
    }
  }

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

  Contact? _chatContact() {
    if (widget.isSelf || widget.contact == null) return null;
    for (final c in _appState.contacts) {
      if (c.keyHash == widget.contact!.keyHash) return c;
    }
    return null;
  }

  bool _hasActiveChat(Contact? contact) {
    if (contact == null) return false;
    if (contact.isPendingEmergency) return false;
    if (contact.isWilted || contact.isArchived) return false;
    final expires = contact.wiltExpiresAt;
    if (expires != null && !DateTime.now().isBefore(expires)) return false;
    return true;
  }

  /// Emergency chat: a 12-hour Time Wilt chat created remotely — no BLE pairing
  /// needed. Starting one destructively replaces any previous chat and starts
  /// a pending session until the peer acknowledges.
  Future<void> _startEmergencyChat() async {
    if (widget.isSelf || widget.contact == null) return;
    final l10n = AppLocalizations.of(context)!;
    final t = context.wk;

    final chatC = _chatContact();
    if (chatC != null && chatC.isPendingEmergency) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: t.surface,
          content: Text(
            l10n.chatsEmergencyPendingSnackBar(widget.contact!.name),
            style: t.bodySecondary.copyWith(color: t.warning),
          ),
        ),
      );
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border, width: t.borderWidth),
        ),
        title: Text(
          l10n.emergencyChatConfirmTitle(widget.contact!.name),
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
        content: Text(
          l10n.emergencyChatConfirmBody(widget.contact!.name),
          style: t.bodySecondary.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel, style: TextStyle(color: t.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.warning,
              foregroundColor: t.onAction,
            ),
            child: Text(l10n.emergencyChatStart),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    final error = await _appState.createEmergencyChat(widget.contact!.keyHash);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: t.surface,
          content: Text(
            error,
            style: t.bodySecondary.copyWith(color: t.danger),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: t.surface,
        content: Text(
          l10n.emergencyChatStarted,
          style: t.bodySecondary.copyWith(color: t.action),
        ),
      ),
    );
    setState(() {});
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
    final isSelf = widget.isSelf;
    final themeData = (!isSelf && widget.contact?.themeId != null)
        ? WiltkeyThemeRegistry.byId(widget.contact!.themeId!).build()
        : Theme.of(context);

    return Theme(
      data: themeData,
      child: Builder(
        builder: (themedContext) {
          final t = themedContext.wk;
          final l10n = AppLocalizations.of(themedContext)!;

          return themedContext.wkc.profileBackdrop(
            seed: _seed,
            child: Scaffold(
              // Transparent so the theme's profile backdrop (Matrix rain / meadow /
              // hanging slips) painted BEHIND this Scaffold shows through; each backdrop
              // supplies its own opaque base colour.
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(
                  isSelf
                      ? (t.uppercaseLabels
                          ? l10n.contactsOwnProfile.toUpperCase()
                          : l10n.contactsOwnProfile)
                      : widget.contact!.name,
                  style: t.screenTitle.copyWith(fontSize: 18),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: t.textPrimary),
                  onPressed: () => Navigator.pop(themedContext),
                ),
                actions: [
                  if (!isSelf && widget.contact != null) ...[
                    IconButton(
                      icon: Icon(
                        widget.contact!.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: widget.contact!.isPinned
                            ? t.action
                            : t.textSecondary,
                      ),
                      tooltip: widget.contact!.isPinned
                          ? l10n.contactUnpin
                          : l10n.contactPin,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _appState.togglePinSocialContact(widget.contact!.keyHash);
                        setState(() {});
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: t.textPrimary),
                      color: t.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusCard),
                        side: BorderSide(color: t.border, width: t.borderWidth),
                      ),
                      onSelected: (value) {
                        if (value == 'remove') {
                          _removeContact();
                        } else if (value == 'block') {
                          _blockContact();
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.person_remove_outlined, size: 18, color: t.warning),
                              const SizedBox(width: 12),
                              Text(
                                l10n.contactProfileRemove,
                                style: t.body.copyWith(color: t.warning),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Icons.block, size: 18, color: t.danger),
                              const SizedBox(width: 12),
                              Text(
                                l10n.contactProfileBlock,
                                style: t.body.copyWith(color: t.danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              body: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  24 + MediaQuery.of(themedContext).viewPadding.bottom,
                ),
                children: [
                  // Header with large avatar
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            PixelArtAvatar(
                              hexString: _avatarHex(),
                              size: 96,
                              borderId: _avatarBorderId(),
                            ),
                            if (_statusEmoji().isNotEmpty)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: GestureDetector(
                                  onTap: widget.isSelf ? _pickStatusEmoji : null,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: t.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: t.border,
                                        width: t.borderWidth,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _statusEmoji(),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                              )
                            else if (widget.isSelf)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: GestureDetector(
                                  onTap: _pickStatusEmoji,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: t.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: t.border,
                                        width: t.borderWidth,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.add_reaction_outlined,
                                      size: 15,
                                      color: t.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: t.action.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(t.radiusPill),
                            ),
                            child: Text(
                              '@${_shortNick()}',
                              style: t.badgeLabel.copyWith(
                                color: t.action,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Status section — editable on self, read-only display for contacts.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: t.border, width: t.borderWidth),
                      borderRadius: BorderRadius.circular(t.radiusCard),
                    ),
                    child: isSelf
                        ? _buildSelfStatus(t, l10n)
                        : _buildContactStatus(t, l10n),
                  ),
                  const SizedBox(height: 16),
                  // Keyhash / Safety fingerprint card
                  _buildKeyhashCard(
                    t,
                    l10n,
                    isSelf ? _appState.userId : widget.contact!.keyHash,
                  ),
                  const SizedBox(height: 24),
                  // Primary action area (for contacts)
                  if (!isSelf) ...[
                    _buildPrimaryActionArea(t, l10n),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeyhashCard(
    WiltkeyTokens t,
    AppLocalizations l10n,
    String keyHash,
  ) {
    final displayHash = keyHash.length > 24
        ? '${keyHash.substring(0, 12)}...${keyHash.substring(keyHash.length - 12)}'
        : keyHash;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border, width: t.borderWidth),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Row(
        children: [
          Icon(Icons.fingerprint, size: 22, color: t.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.contactProfileSafetyNumber,
                  style: t.badgeLabel.copyWith(
                    color: t.textTertiary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayHash,
                  style: t.dataMono.copyWith(fontSize: 13, color: t.textPrimary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: 18, color: t.action),
            tooltip: l10n.commonCopy,
            onPressed: () {
              HapticFeedback.lightImpact();
              Clipboard.setData(ClipboardData(text: keyHash));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: t.surface,
                  content: Text(
                    l10n.commonCopied,
                    style: t.bodySecondary.copyWith(color: t.action),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionArea(WiltkeyTokens t, AppLocalizations l10n) {
    final chatC = _chatContact();
    if (chatC != null && chatC.isPendingEmergency) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.warning.withValues(alpha: 0.1),
          border: Border.all(
            color: t.warning.withValues(alpha: 0.3),
            width: t.borderWidth,
          ),
          borderRadius: BorderRadius.circular(t.radiusCard),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: t.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.emergencyChatPending,
                style: t.bodySecondary.copyWith(
                  fontSize: 13,
                  color: t.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasChat = _hasActiveChat(chatC);
    if (hasChat) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.chat_bubble_rounded, size: 20),
              label: Text(
                l10n.contactProfileOpenChat,
                style: t.badgeLabel.copyWith(
                  color: t.onAction,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _openChat();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.action,
                foregroundColor: t.onAction,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              icon: Icon(Icons.sos, size: 18, color: t.warning),
              label: Text(
                l10n.contactProfileEmergencyChat,
                style: t.badgeLabel.copyWith(
                  color: t.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _startEmergencyChat();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: t.warning.withValues(alpha: 0.5),
                  width: t.borderWidth,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.warning.withValues(alpha: 0.1),
        border: Border.all(
          color: t.warning.withValues(alpha: 0.3),
          width: t.borderWidth,
        ),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: t.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.contactProfileWiltedHint,
                  style: t.bodySecondary.copyWith(
                    fontSize: 12,
                    color: t.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.sos, size: 20),
              label: Text(
                l10n.contactProfileEmergencyChat,
                style: t.badgeLabel.copyWith(
                  color: t.onAction,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _startEmergencyChat();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.warning,
                foregroundColor: t.onAction,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Self: a live status editor that persists + broadcasts on save.
  Widget _buildSelfStatus(WiltkeyTokens t, AppLocalizations l10n) {
    final hasActiveStatus =
        _appState.effectiveStatusMessage.isNotEmpty ||
        _appState.effectiveStatusEmoji.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.contactStatusLabel,
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
            if (hasActiveStatus)
              TextButton(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _statusController.clear();
                    _selectedEmoji = '';
                    _selectedDurationHours = null;
                  });
                  await _appState.clearOwnStatus();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: t.surface,
                      content: Text(
                        l10n.contactStatusUpdated,
                        style: t.bodySecondary.copyWith(color: t.action),
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.commonRemove,
                  style: t.badgeLabel.copyWith(color: t.danger, fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Row with status emoji picker button + text field
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _pickStatusEmoji();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(t.radiusControl),
                  border: Border.all(color: t.border, width: t.borderWidth),
                ),
                alignment: Alignment.center,
                child: _selectedEmoji.isNotEmpty
                    ? Text(_selectedEmoji, style: const TextStyle(fontSize: 22))
                    : Icon(
                        Icons.add_reaction_outlined,
                        size: 22,
                        color: t.textSecondary,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _statusController,
                builder: (context, value, _) {
                  final length = value.text.length;
                  return TextField(
                    controller: _statusController,
                    maxLines: 2,
                    maxLength: 100,
                    style: t.body,
                    decoration: InputDecoration(
                      hintText: l10n.contactStatusHint,
                      hintStyle: t.body.copyWith(color: t.textTertiary),
                      filled: true,
                      fillColor: t.bg,
                      helperText: '$length/100',
                      helperStyle: t.dataMono.copyWith(
                        fontSize: 11,
                        color: length >= 100 ? t.danger : t.textTertiary,
                      ),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                        borderSide: BorderSide(
                          color: t.border,
                          width: t.borderWidth,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                        borderSide: BorderSide(
                          color: t.border,
                          width: t.borderWidth,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                        borderSide: BorderSide(
                          color: t.action,
                          width: t.borderWidth,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Clear after duration selector
        Text(
          'Clear status after',
          style: t.badgeLabel.copyWith(color: t.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _durationChip(t, label: 'Never', hours: null),
              const SizedBox(width: 6),
              _durationChip(t, label: '1 hour', hours: 1),
              const SizedBox(width: 6),
              _durationChip(t, label: '4 hours', hours: 4),
              const SizedBox(width: 6),
              _durationChip(t, label: '24 hours', hours: 24),
              const SizedBox(width: 6),
              _durationChip(t, label: '48 hours', hours: 48),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: Text(
              l10n.contactStatusSave,
              style: t.badgeLabel.copyWith(color: t.onAction),
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final text = _statusController.text.trim();
              final expiresMs = _selectedDurationHours == null
                  ? null
                  : DateTime.now()
                        .add(Duration(hours: _selectedDurationHours!))
                        .millisecondsSinceEpoch;
              await _appState.updateOwnStatus(
                text,
                emoji: _selectedEmoji,
                expiresAtMs: expiresMs,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: t.surface,
                  content: Text(
                    l10n.contactStatusUpdated,
                    style: t.bodySecondary.copyWith(color: t.action),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.onAction,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _durationChip(
    WiltkeyTokens t, {
    required String label,
    required int? hours,
  }) {
    final isSelected = _selectedDurationHours == hours;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedDurationHours = hours);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? t.action.withValues(alpha: 0.15) : t.bg,
          border: Border.all(
            color: isSelected ? t.action : t.border,
            width: t.borderWidth,
          ),
          borderRadius: BorderRadius.circular(t.radiusPill),
        ),
        child: Text(
          label,
          style: t.badgeLabel.copyWith(
            color: isSelected ? t.action : t.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Contact: read-only display of the peer's synced status.
  Widget _buildContactStatus(WiltkeyTokens t, AppLocalizations l10n) {
    final contact = _currentContact() ?? widget.contact!;
    final status = contact.activeStatus;
    final emoji = contact.activeStatusEmoji;
    final hasStatus =
        (status != null && status.isNotEmpty) ||
        (emoji != null && emoji.isNotEmpty);

    String? expiryText;
    if (contact.statusExpiresAt != null && !contact.isStatusExpired) {
      final leftSec =
          ((contact.statusExpiresAt! - DateTime.now().millisecondsSinceEpoch) /
                  1000)
              .round();
      if (leftSec > 0) {
        if (leftSec < 60) {
          expiryText = 'Expires in ${leftSec}s';
        } else if (leftSec < 3600) {
          expiryText = 'Expires in ${(leftSec / 60).round()}m';
        } else {
          final h = (leftSec / 3600).floor();
          final m = ((leftSec % 3600) / 60).round();
          expiryText = m > 0 ? 'Expires in ${h}h ${m}m' : 'Expires in ${h}h';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.contactStatusLabel,
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
            if (expiryText != null)
              Text(
                expiryText,
                style: t.dataMono.copyWith(fontSize: 11, color: t.textTertiary),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!hasStatus)
          Text(
            l10n.contactProfileStatusPlaceholder,
            style: t.bodySecondary.copyWith(height: 1.5),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (emoji != null && emoji.isNotEmpty) ...[
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
              ],
              if (status != null && status.isNotEmpty)
                Expanded(
                  child: Text(
                    status,
                    style: t.body.copyWith(height: 1.4),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
