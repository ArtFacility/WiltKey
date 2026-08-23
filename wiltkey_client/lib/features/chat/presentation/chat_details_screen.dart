import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/chat_metadata.dart';
import '../../../core/custom_emoji.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/wiltkey_components.dart';
import '../../groups/presentation/emoji_creator_screen.dart';
import '../../contacts/presentation/contact_request_ui.dart';
import '../../contacts/presentation/contact_profile_screen.dart';
import 'chat_media_gallery_screen.dart';
import '../../../core/db/wiltkey_db.dart';
import 'widgets/nuke_confirm_dialog.dart';
import '../../../core/theme/widgets/client_integrity_badge.dart';

/// 1-on-1 Chat Details — opened by tapping the peer's name/avatar in the chat.
/// Mirrors the group Details screen: peer profile, the (synced) image
/// permission, the relative metadata budget, the keystream lanes + byte-borrow
/// control, and the Nuke action (moved here from the chat app bar). There is
/// only ever one other party, so it shows just the peer.
class ChatDetailsScreen extends StatefulWidget {
  final Contact contact;
  const ChatDetailsScreen({super.key, required this.contact});

  @override
  State<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends State<ChatDetailsScreen> {
  final AppState _appState = AppState();

  // Always read the freshest contact (profile/permissions can sync in live).
  Contact get _contact {
    final i = _appState.contacts.indexWhere(
      (c) => c.keyHash == widget.contact.keyHash,
    );
    return i != -1 ? _appState.contacts[i] : widget.contact;
  }

  List<CustomEmoji> _emojis = [];

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onState);
    _loadEmojis();
  }

  @override
  void dispose() {
    _appState.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  Future<void> _loadEmojis() async {
    final list = await CustomEmojiStore.load(widget.contact.keyHash);
    if (mounted) setState(() => _emojis = list);
  }

  Future<void> _createEmoji() async {
    final t = context.wk;
    final contact = _contact;
    final emoji = await Navigator.push<CustomEmoji?>(
      context,
      MaterialPageRoute(
        builder: (_) => EmojiCreatorScreen(chatKey: contact.keyHash),
      ),
    );
    if (emoji == null) return;
    final err = await _appState.defineEmoji(contact, emoji);
    await _loadEmojis();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (mounted) {
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

  // Deleting can't reclaim the OTP/metadata space, so it leaves a tombstone (a
  // red-X "burned" slot) that keeps costing budget but propagates the removal.
  void _deleteEmoji(CustomEmoji emoji) {
    if (emoji.deleted) return;
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final contact = _contact;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: t.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _appState.deleteChatEmoji(contact, emoji.name);
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

  void _confirmClearHistory(Contact contact) {
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
              await WiltkeyDatabase.instance.deleteMessagesForChat(contact.id);
              await _appState.loadMessagesForContact(contact);
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

  void _nukeChat() {
    final contact = widget.contact;

    // The overlay lives in the root overlay (carrying our ThemeData) so it
    // survives the popUntil at the end and resolves theme tokens. onDone wipes
    // both ends (nukeContact sends NUKE_RECIPIENT for 1-on-1) and exits to root.
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
            onDone: () {
              entry.remove();
              _appState.nukeContact(contact.keyHash, receivedFromPeer: false);
              navigator.popUntil((route) => route.isFirst);
            },
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final contact = _contact;
    final int budget = ChatMetaStore.budgetFor(
      contact.maxBufferBytes,
      timeWilt: contact.isTimeWilt,
    );
    final bool emojisOk = ChatMetaStore.customEmojisAllowed(
      contact.maxBufferBytes,
      timeWilt: contact.isTimeWilt,
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.action),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t.uppercaseLabels
              ? l10n.chatDetailsTitle.toUpperCase()
              : l10n.chatDetailsTitle,
          style: t.screenTitle.copyWith(fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        // Pad the bottom by the system nav-bar inset so the last action (Nuke)
        // clears 3-button navigation under edge-to-edge — a gesture/3-button
        // user must never have the destructive button sitting under the bar.
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: the peer.
            Center(
              child: Column(
                children: [
                  PixelArtAvatar(
                    hexString:
                        (contact.profileImageB64 != null &&
                            contact.profileImageB64!.isNotEmpty)
                        ? contact.profileImageB64!
                        : PixelArtAvatar.generateIdenticon(contact.keyHash),
                    size: 64,
                    borderId: contact.avatarBorderId,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          contact.name,
                          style: t.body.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ClientIntegrityBadge(
                        badgeType: contact.badgeType,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.shortNick != null && contact.shortNick!.isNotEmpty
                        ? l10n.chatDetailsSubtitleWithNick(
                            contact.shortNick!,
                            contact.isPrivateNode
                                ? l10n.chatDetailsPrivateNode
                                : l10n.chatDetailsOfficialRelay,
                          )
                        : (contact.isPrivateNode
                              ? l10n.chatDetailsPrivateNode
                              : l10n.chatDetailsOfficialRelay),
                    style: t.dataMono.copyWith(color: t.textTertiary),
                  ),
                  const SizedBox(height: 14),
                  // Detail budget glyph (large flower / full bar) + labels. Time
                  // Wilt reuses the single gauge for time-remaining, with a
                  // lifetime line instead of the me/peer byte readout.
                  context.wkc.budgetIndicator(
                    ourFraction: contact.isTimeWilt
                        ? contact.timeWiltRemainingFraction
                        : contact.chargePercentage,
                    theirFraction: contact.isTimeWilt
                        ? 0
                        : contact.getTheirChargePercentage(_appState.userId),
                    isWilted: contact.isTimeWilt
                        ? contact.isArchived
                        : contact.isWilted,
                    split: !contact.isTimeWilt,
                    variant: BudgetIndicatorVariant.detail,
                    semanticLabel: contact.isTimeWilt
                        ? contact.timeWiltCountdownLabel
                        : l10n.chatRemainingLabel(
                            AppState.formatBytes(contact.remainingBufferBytes),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    contact.isTimeWilt
                        ? (contact.isArchived
                              ? 'Wilted — read-only'
                              : 'Wilts in ${contact.timeWiltCountdownLabel}')
                        : l10n.chatDetailsHeaderMeRemaining(
                            AppState.formatBytes(contact.remainingBufferBytes),
                            AppState.formatBytes(
                              contact.getTheirRemainingBytes(_appState.userId),
                            ),
                          ),
                    style: t.dataMono.copyWith(
                      color: contact.isTimeWilt && contact.isArchived
                          ? t.textTertiary
                          : t.positive,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: t.border, height: 32),

            // Social contact relationship
            () {
              final bool isSocialContact = _appState.socialContacts.any(
                (sc) => sc.keyHash == contact.keyHash,
              );
              if (!isSocialContact) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    border: Border.all(
                      color: t.action.withOpacity(0.35),
                      width: t.borderWidth,
                    ),
                    borderRadius: BorderRadius.circular(t.radiusCard),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_add_outlined, color: t.action, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.contactAddTitle,
                              style: t.body.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              l10n.contactAddBody(contact.name),
                              style: t.bodySecondary.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => showAddContactFlow(
                          context,
                          appState: _appState,
                          contact: contact,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.action,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          l10n.contactAddConfirm,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                final sc = _appState.socialContacts.firstWhere(
                  (c) => c.keyHash == contact.keyHash,
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: _panel(t),
                  child: Row(
                    children: [
                      Icon(Icons.badge_outlined, color: t.positive, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.uppercaseLabels
                              ? 'SAVED CONTACT'
                              : 'Saved contact',
                          style: t.dataMono.copyWith(
                            fontSize: 11,
                            color: t.positive,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactProfileScreen(contact: sc),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward, size: 13),
                        label: Text(
                          t.uppercaseLabels ? 'VIEW PROFILE' : 'View profile',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }
            }(),

            // Profile sync
            _title(t, l10n.chatDetailsSectionProfile, t.action),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _panel(t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.chatDetailsProfileExplanation,
                    style: t.bodySecondary,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      _appState.sendChatInfoUpdate(contact);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: t.surface,
                          content: Text(
                            l10n.chatDetailsProfileSnackBar,
                            style: TextStyle(color: t.action),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.sync, size: 14),
                    label: Text(l10n.chatDetailsProfileSyncButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.positive,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Permissions
            _title(t, l10n.chatDetailsSectionPermissions, t.action),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _panel(t),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.chatDetailsPermissionsPhotos,
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: contact.imagesAllowed ?? true,
                        activeThumbColor: t.identity,
                        onChanged: (v) =>
                            _appState.setChatImagesAllowed(contact, v),
                      ),
                    ],
                  ),
                  Divider(color: t.border, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.chatDetailsPermissionsEmojis,
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        emojisOk
                            ? l10n.chatDetailsPermissionsEmojisAvailable
                            : l10n.chatDetailsPermissionsEmojisNeedsSize,
                        style: t.dataMono.copyWith(
                          color: emojisOk ? t.action : t.textTertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Metadata space + secure lanes / byte-borrow ("request chat space")
            // are byte-budget concepts — hidden for Time Wilt (unbounded stream).
            if (!contact.isTimeWilt) ...[
              _title(t, l10n.chatDetailsSectionMetadata, t.action),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: _panel(t),
                child: Text(
                  l10n.chatDetailsMetadataExplanation(
                    AppState.formatBytes(budget),
                    AppState.formatBytes(contact.maxBufferBytes),
                  ),
                  style: t.bodySecondary,
                ),
              ),
              const SizedBox(height: 24),
              _title(t, l10n.chatDetailsSectionLanes, t.action),
              const SizedBox(height: 8),
              _buildLanes(t, contact),
              const SizedBox(height: 24),
            ],

            // Custom emojis
            _buildEmojiSection(t, emojisOk, budget),
            const SizedBox(height: 24),

            // Media, Voice & Links Gallery
            _title(t, l10n.chatDetailsSectionMedia, t.action),
            const SizedBox(height: 8),
            Container(
              decoration: _panel(t),
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
                      builder: (_) => ChatMediaGalleryScreen(contact: contact),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // History cleanup
            _title(t, l10n.chatDetailsClearHistory, t.textSecondary),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _panel(t),
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
                    onPressed: () => _confirmClearHistory(contact),
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
            _title(t, l10n.chatDetailsSectionDestructive, t.danger),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.danger.withValues(alpha: 0.03),
                border: Border.all(color: t.danger.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              child: ElevatedButton.icon(
                onPressed: () => NukeConfirmDialog.show(context, _nukeChat),
                icon: const Icon(Icons.flash_on, size: 14),
                label: Text(l10n.chatDetailsNukeButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.danger,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanes(WiltkeyTokens t, Contact contact) {
    final l10n = AppLocalizations.of(context)!;
    final a = contact.additionalSlots;
    int borrowedRanges = 0;
    int borrowedRemaining = 0;
    for (int i = 0; i + 2 < a.length; i += 3) {
      borrowedRanges++;
      final r = a[i + 2] - a[i + 1];
      if (r > 0) borrowedRemaining += r;
    }

    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: t.dataMono.copyWith(color: t.textSecondary)),
          Text(
            value,
            style: t.dataMono.copyWith(color: color ?? t.textSecondary),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panel(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            l10n.chatDetailsLanesMySend,
            '${contact.outgoingOffset} → ${contact.outgoingMaxOffset}',
          ),
          row(
            l10n.chatDetailsLanesPeerSend,
            '${contact.incomingOffset} → ${contact.incomingMaxOffset}',
          ),
          if (borrowedRanges > 0)
            row(
              l10n.chatDetailsLanesBorrowed,
              '$borrowedRanges (+${AppState.formatBytes(borrowedRemaining)})',
              color: t.action,
            ),
          row(
            l10n.chatDetailsLanesCapacityLeft,
            AppState.formatBytes(contact.remainingBufferBytes),
            color: contact.isWilted ? t.danger : t.action,
          ),
          const SizedBox(height: 12),
          Text(l10n.chatDetailsLanesExplanation, style: t.bodySecondary),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              _appState.requestBorrow(contact);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: t.surface,
                  content: Text(
                    l10n.chatDetailsLanesSnackBar,
                    style: TextStyle(color: t.action),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.swap_horiz, size: 14),
            label: Text(l10n.chatDetailsLanesBorrowButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.positive,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiSection(WiltkeyTokens t, bool emojisOk, int budget) {
    final l10n = AppLocalizations.of(context)!;
    final int used = _emojis.fold<int>(0, (s, e) => s + e.approxBytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _title(t, l10n.chatDetailsSectionEmojis, t.identity),
            Text(
              emojisOk
                  ? '${AppState.formatBytes(used)} / ${AppState.formatBytes(budget)}'
                  : '—',
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
          decoration: _panel(t),
          child: emojisOk
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.chatDetailsEmojisExplanation,
                      style: t.bodySecondary,
                    ),
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
                )
              : Text(
                  l10n.chatDetailsEmojisExplanationDisabled,
                  style: t.bodySecondary,
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

  Widget _title(WiltkeyTokens t, String text, Color c) => Text(
    t.uppercaseLabels ? text.toUpperCase() : _sentence(text),
    style: t.sectionLabel.copyWith(color: c),
  );

  // Garden shows section labels in sentence case; cyberpunk keeps the caps.
  String _sentence(String s) =>
      s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();

  BoxDecoration _panel(WiltkeyTokens t) => BoxDecoration(
    color: t.surface,
    border: Border.all(color: t.border),
    borderRadius: BorderRadius.circular(t.radiusControl),
  );
}
