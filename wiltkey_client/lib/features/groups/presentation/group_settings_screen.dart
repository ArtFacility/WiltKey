import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/custom_emoji.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import 'emoji_creator_screen.dart';

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

  // Host-editable policy state.
  late bool _imagesAllowed;
  late int _maxMembers;
  late double _maxMessageSizeKb;

  List<CustomEmoji> _emojis = [];

  @override
  void initState() {
    super.initState();
    _imagesAllowed = widget.group.imagesAllowed ?? true;
    _maxMembers = widget.group.maxMembers ?? 20;
    _maxMessageSizeKb = (widget.group.maxMessageSize ?? 2048) / 1024.0;
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
        _appState.contacts[idx] = Contact(
          id: existing.id,
          name: existing.name,
          keyHash: existing.keyHash,
          relayUrl: existing.relayUrl,
          isPrivateNode: existing.isPrivateNode,
          maxBufferBytes: existing.maxBufferBytes,
          remainingBufferBytes: existing.remainingBufferBytes,
          peerRemainingBufferBytes: existing.peerRemainingBufferBytes,
          lastActivity: existing.lastActivity,
          isWilted: existing.isWilted,
          isGroup: true,
          memberCount: existing.memberCount,
          hostName: existing.hostName,
          isHost: existing.isHost,
          hostKeyHash: existing.hostKeyHash,
          memberKeyHashes: existing.memberKeyHashes,
          groupIconHex: existing.groupIconHex,
          maxMembers: _maxMembers,
          maxMessageSize: (_maxMessageSizeKb * 1024).toInt(),
          imagesAllowed: _imagesAllowed,
          joinedAt: existing.joinedAt,
          shortNick: existing.shortNick,
          profileImageB64: existing.profileImageB64,
          outgoingOffset: existing.outgoingOffset,
          outgoingMaxOffset: existing.outgoingMaxOffset,
          incomingOffset: existing.incomingOffset,
          incomingMaxOffset: existing.incomingMaxOffset,
          groupSeed: existing.groupSeed,
          laneSize: existing.laneSize,
          totalGroupSize: existing.totalGroupSize,
          slotIndex: existing.slotIndex,
          additionalSlots: existing.additionalSlots,
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
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.danger, width: 1.5),
        ),
        title: Text(
          t.uppercaseLabels
              ? l10n.groupDetailsDeleteConfirmTitle.toUpperCase()
              : l10n.groupDetailsDeleteConfirmTitle,
          style: t.screenTitle.copyWith(color: t.danger, fontSize: 16),
        ),
        content: Text(
          l10n.groupDetailsDeleteConfirmBody,
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
              _playNukeAndDestroy();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.groupDetailsDeleteConfirmButton),
          ),
        ],
      ),
    );
  }

  /// Plays the theme's nuke animation over the screen, then full-mesh nukes the
  /// group (every member is wiped — see AppState.nukeGroup) and exits to root.
  void _playNukeAndDestroy() {
    final group = widget.group;
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

    return Scaffold(
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
                    Divider(color: t.border, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.groupCreatePolicyMaxMembersLabel,
                          style: t.bodySecondary,
                        ),
                        Text(
                          l10n.chatsMemberCount(_maxMembers),
                          style: t.dataMono.copyWith(color: t.action),
                        ),
                      ],
                    ),
                    Slider(
                      value: _maxMembers.toDouble(),
                      min: 2,
                      max: 100,
                      divisions: 98,
                      activeColor: t.action,
                      inactiveColor: t.budgetEmpty,
                      onChanged: (val) =>
                          setState(() => _maxMembers = val.round()),
                    ),
                    Divider(color: t.border, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.groupCreatePolicyPayloadSize,
                          style: t.bodySecondary,
                        ),
                        Text(
                          '${_maxMessageSizeKb.toStringAsFixed(1)} KB',
                          style: t.dataMono.copyWith(color: t.action),
                        ),
                      ],
                    ),
                    Slider(
                      value: _maxMessageSizeKb,
                      min: 0.5,
                      max: 10.0,
                      divisions: 19,
                      activeColor: t.action,
                      inactiveColor: t.budgetEmpty,
                      onChanged: (val) =>
                          setState(() => _maxMessageSizeKb = val),
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
