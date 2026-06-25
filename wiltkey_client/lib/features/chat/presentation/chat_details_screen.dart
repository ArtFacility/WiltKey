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
import 'widgets/nuke_confirm_dialog.dart';

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
    final int budget = ChatMetaStore.budgetFor(contact.maxBufferBytes);
    final bool emojisOk = ChatMetaStore.customEmojisAllowed(
      contact.maxBufferBytes,
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
        padding: const EdgeInsets.all(16),
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
                  ),
                  const SizedBox(height: 12),
                  Text(
                    contact.name,
                    style: t.body.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
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
                  // Detail budget glyph (large flower / full bar) + labels.
                  context.wkc.budgetIndicator(
                    ourFraction: contact.chargePercentage,
                    theirFraction: contact.getTheirChargePercentage(
                      _appState.userId,
                    ),
                    isWilted: contact.isWilted,
                    split: true,
                    variant: BudgetIndicatorVariant.detail,
                    semanticLabel: l10n.chatRemainingLabel(
                      AppState.formatBytes(contact.remainingBufferBytes),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.chatDetailsHeaderMeRemaining(
                      AppState.formatBytes(contact.remainingBufferBytes),
                      AppState.formatBytes(
                        contact.getTheirRemainingBytes(_appState.userId),
                      ),
                    ),
                    style: t.dataMono.copyWith(color: t.positive),
                  ),
                ],
              ),
            ),
            Divider(color: t.border, height: 32),

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

            // Metadata space (relative budget)
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

            // Secure lanes / byte-range
            _title(t, l10n.chatDetailsSectionLanes, t.action),
            const SizedBox(height: 8),
            _buildLanes(t, contact),
            const SizedBox(height: 24),

            // Custom emojis
            _buildEmojiSection(t, emojisOk, budget),
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
