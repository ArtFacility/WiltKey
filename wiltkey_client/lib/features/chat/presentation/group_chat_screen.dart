import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/custom_emoji.dart';
import '../../../core/image_utils.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/wiltkey_components.dart';
import 'widgets/compression_dialog.dart';
import 'widgets/emoji_autocomplete_bar.dart';
import 'widgets/emoji_picker_panel.dart';
import 'widgets/debug_console_sheet.dart';
import '../../groups/presentation/group_settings_screen.dart';
import '../../groups/presentation/group_invite_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with TickerProviderStateMixin {
  final AppState _appState = AppState();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  int _charCount = 0;
  bool _showEmoji = false;
  bool _loadingOlder = false;
  bool _isAtBottom = true;
  bool _showScrollDownArrow = false;
  final Set<String> _revealedImageIds = {};

  late final AnimationController _sendBloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void initState() {
    super.initState();
    _appState.addListener(_updateState);
    _messageController.addListener(_updateCharCount);
    _scrollController.addListener(_scrollListener);

    final contact = _appState.activeContact;
    if (contact != null) {
      _appState.loadInitialMessages(contact).then((_) async {
        if (!mounted) return;
        // Await decryption (it fills text heights) BEFORE pinning, then re-pin
        // across frames so async height growth (images) can't strand us partway.
        await _appState.decryptBatch(contact);
        if (!mounted) return;
        _pinToBottomUntilStable();
      });
      if (contact.isGroup) {
        _appState.updateGroupMembersMetadata(contact);
        _warmEmojis(contact.keyHash);
      }
    }
  }

  @override
  void dispose() {
    final c = _appState.activeContact;
    if (c != null) _appState.markChatRead(c);
    _sendBloom.dispose();
    _appState.removeListener(_updateState);
    _inputFocus.dispose();
    _messageController.removeListener(_updateCharCount);
    _scrollController.removeListener(_scrollListener);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.maxScrollExtent - pos.pixels < 100;
    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
        if (atBottom) {
          _showScrollDownArrow = false;
        }
      });
    }
    if (pos.pixels < 240) _maybeLoadOlder();
  }

  Future<void> _maybeLoadOlder() async {
    final contact = _appState.activeContact;
    if (contact == null || _loadingOlder) return;
    if (_appState.hasMoreOlder[contact.id] != true) return;
    _loadingOlder = true;
    final pos = _scrollController.position;
    final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
    final added = await _appState.loadOlderMessages(contact);
    if (added > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent - distanceFromBottom,
          );
        }
      });
    }
    _loadingOlder = false;
  }

  List<ChatMessage> _visibleMessages(Contact contact) {
    return (_appState.messages[contact.id] ?? []).where((m) {
      if (m.contentType == 'emoji_def' || m.contentType == 'emoji_delete')
        return false;
      if (m.isSystem) return true;
      if (contact.joinedAt != null && m.timestamp.isBefore(contact.joinedAt!)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
      if (_appState.status == AppStatus.nuked) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      final contact = _appState.activeContact;
      if (contact != null) {
        final messages = _visibleMessages(contact);
        if (messages.isNotEmpty) {
          final lastMessage = messages.last;
          if (lastMessage.isSentByMe) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(),
            );
          } else {
            if (_isAtBottom) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToBottom(),
              );
            } else {
              setState(() {
                _showScrollDownArrow = true;
              });
            }
          }
        }
      }
    }
  }

  void _updateCharCount() {
    setState(() {
      _charCount = _messageController.text.length;
    });
  }

  Future<void> _warmEmojis(String chatKey) async {
    await CustomEmojiStore.load(chatKey);
    if (mounted) setState(() {});
  }

  Future<void> _openGroupDetails(Contact contact) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupSettingsScreen(group: contact),
      ),
    );
    await _warmEmojis(contact.keyHash);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  /// Jumps to the bottom and keeps re-jumping each frame until the scroll extent
  /// stops growing — message decryption and async image decode both expand the
  /// list after the first layout, which otherwise leaves the view stranded at a
  /// stale (shorter) extent partway up the history.
  void _pinToBottomUntilStable() {
    double lastExtent = -1;
    int stableFrames = 0;
    int totalFrames = 0;
    void tick() {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      _scrollController.jumpTo(pos.maxScrollExtent);
      totalFrames++;
      if (pos.maxScrollExtent == lastExtent) {
        stableFrames++;
      } else {
        stableFrames = 0;
        lastExtent = pos.maxScrollExtent;
      }
      if (stableFrames < 3 && totalFrames < 30) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tick());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tick());
  }

  void _errorSnack(String msg) {
    if (!mounted) return;
    final t = context.wk;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: t.surface,
        content: Text(msg, style: t.bodySecondary.copyWith(color: t.danger)),
      ),
    );
  }

  void _toggleEmoji() {
    setState(() => _showEmoji = !_showEmoji);
    if (_showEmoji) {
      _inputFocus.unfocus();
    } else {
      _inputFocus.requestFocus();
    }
  }

  void _hideEmoji() {
    if (_showEmoji) setState(() => _showEmoji = false);
  }

  void _onMicTap() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.chatVoiceComingSoon)));
  }

  void _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _sendBloom.forward(from: 0);

    // Clear the field instantly — the bubble shows immediately as a pending
    // "Encrypting…" placeholder while the send completes in the background.
    _messageController.clear();
    _scrollToBottom();

    final error = await _appState.sendGroupMessage(text);
    if (error != null) {
      _appState.log('[GroupChat] Send failed: $error');
      if (mounted) {
        _errorSnack(error);
        // A pre-flight failure leaves no bubble — restore the draft.
        _messageController.text = text;
      }
    }
  }

  Future<void> _pickAndSendGroupImage(Contact contact) async {
    final picker = ImagePicker();
    XFile? image;
    try {
      _appState.isPickingMedia = true;
      image = await picker.pickImage(source: ImageSource.gallery);
    } finally {
      _appState.isPickingMedia = false;
    }
    if (image == null) return;

    final originalBytes = await image.readAsBytes();
    if (!mounted) return;
    final CompressionResult? choice = await CompressionDialog.show(
      context,
      originalBytes.length,
    );
    if (choice == null) return;

    final imageBytes = await ImageUtils.prepareForSend(
      originalBytes,
      quality: (choice.quality * 100).toInt(),
    );
    final base64Data = base64Encode(imageBytes);
    final byteCost = base64Data.length + 73;

    final l10n = AppLocalizations.of(context)!;
    if (byteCost > contact.remainingBufferBytes) {
      _errorSnack(
        l10n.chatImageTooLargeSnackBar(
          AppState.formatBytes(byteCost),
          AppState.formatBytes(contact.remainingBufferBytes),
        ),
      );
      return;
    }
    if (base64Data.length > 1400000) {
      _errorSnack(l10n.chatImageExceedsMaxSizeSnackBar);
      return;
    }

    final ct = choice.hidden ? 'image_hidden' : 'image';
    final error = await _appState.sendGroupMessage(base64Data, contentType: ct);
    if (error != null) {
      _errorSnack(error);
    }
    _scrollToBottom();
  }

  double _memberFraction(Map<String, dynamic> m) {
    final rem = (m['remaining'] as int?) ?? 0;
    final mx = (m['max'] as int?) ?? 0;
    return mx > 0 ? (rem / mx).clamp(0.0, 1.0) : 0.0;
  }

  /// Compact header ordering: self pinned first, then the lowest-charge members
  /// (closest to wilting — the members worth surfacing). The full roster lives in
  /// the members sheet, so the header only needs a capped preview.
  List<Map<String, dynamic>> _headerOrderedMembers(
    List<Map<String, dynamic>> memberList,
  ) {
    final ordered = [...memberList];
    ordered.sort((a, b) {
      final aSelf = (a['isSelf'] as bool?) ?? false;
      final bSelf = (b['isSelf'] as bool?) ?? false;
      if (aSelf != bSelf) return aSelf ? -1 : 1;
      return _memberFraction(a).compareTo(_memberFraction(b));
    });
    return ordered;
  }

  List<MemberBudget> _memberBudgets(List<Map<String, dynamic>> memberList) {
    return memberList.map((m) {
      final rem = (m['remaining'] as int?) ?? 0;
      final mx = (m['max'] as int?) ?? 0;
      return MemberBudget(
        fraction: mx > 0 ? (rem / mx).clamp(0.0, 1.0) : 0.0,
        keyHash: (m['keyHash'] as String?) ?? '',
        isSelf: (m['isSelf'] as bool?) ?? false,
        isHost: (m['isHost'] as bool?) ?? false,
        isWilted: rem <= 0,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final contact = _appState.activeContact;
    if (contact == null) return const Scaffold(body: SizedBox());

    final messageList = _visibleMessages(contact);
    final memberList = _appState.groupMembersMetadata[contact.id] ?? [];
    final emojiMap = CustomEmojiStore.cachedMap(contact.keyHash);

    // Header strip is a capped preview (self + lowest-charge members); the full
    // roster lives in the members sheet, opened by tapping the strip.
    const int headerMemberCap = 5;
    final orderedHeaderMembers = _headerOrderedMembers(memberList);
    final shownHeaderMembers = orderedHeaderMembers.length > headerMemberCap
        ? orderedHeaderMembers.sublist(0, headerMemberCap)
        : orderedHeaderMembers;
    final int hiddenHeaderMembers =
        orderedHeaderMembers.length - shownHeaderMembers.length;

    final budget = _appState.groupBudget(contact);
    final double currentPercent = budget.fraction;
    final int remainingBytesNow = budget.usableRemaining;

    final bool isWilted = contact.isWilted;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: t.bg,
            elevation: 0,
            titleSpacing: 8,
            title: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openGroupDetails(contact),
                  child: Row(
                    children: [
                      PixelArtAvatar(
                        hexString:
                            (contact.groupIconHex != null &&
                                contact.groupIconHex!.isNotEmpty)
                            ? contact.groupIconHex!
                            : PixelArtAvatar.generateIdenticon(contact.keyHash),
                        size: 34,
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openGroupDetails(contact),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          contact.name,
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n.groupTapForDetails(contact.hostName ?? ''),
                          style: t.dataMono.copyWith(
                            fontSize: 9,
                            color: t.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                context.wkc.budgetIndicator(
                  ourFraction: currentPercent,
                  isWilted: isWilted,
                  variant: BudgetIndicatorVariant.chatHeader,
                  semanticLabel: l10n.chatRemainingLabel(
                    AppState.formatBytes(remainingBytesNow),
                  ),
                ),
              ],
            ),
            actions: [
              if (_appState.showDebugButtons)
                IconButton(
                  icon: Icon(
                    Icons.terminal_outlined,
                    color: t.action,
                    size: 20,
                  ),
                  tooltip: 'Debug console',
                  onPressed: () => DebugConsoleSheet.show(context, _appState),
                ),
              IconButton(
                icon: Icon(Icons.hub_outlined, color: t.identity, size: 20),
                tooltip: 'Group members',
                onPressed: () => _showMembersSheet(contact),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(22),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 2.0,
                ),
                child: GestureDetector(
                  onTap: () => _showMembersSheet(contact),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Expanded(
                        child: memberList.isNotEmpty
                            ? context.wkc.groupBudgetIndicator(
                                members: _memberBudgets(shownHeaderMembers),
                                emptySlots: 0,
                              )
                            : context.wkc.budgetIndicator(
                                ourFraction: currentPercent,
                                isWilted: isWilted,
                                variant: BudgetIndicatorVariant.detail,
                              ),
                      ),
                      if (hiddenHeaderMembers > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '+$hiddenHeaderMembers',
                          style: t.dataMono.copyWith(
                            color: t.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Text(
                        AppState.formatBytes(remainingBytesNow),
                        style: t.dataMono.copyWith(
                          color: isWilted ? t.budgetWilted : t.positive,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: Container(
            color: t.bg,
            child: Column(
              children: [
                if (isWilted)
                  Container(
                    width: double.infinity,
                    color: t.budgetWilted.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_clock, color: t.budgetWilted, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.uppercaseLabels
                                ? l10n.chatLockedLabel.toUpperCase()
                                : l10n.chatLockedLabel,
                            style: t.badgeLabel.copyWith(color: t.budgetWilted),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    itemCount: messageList.length,
                    itemBuilder: (context, index) {
                      final message = messageList[index];
                      final isMe = message.isSentByMe;
                      final String displayText =
                          message.decryptedText ?? message.text;

                      if (message.contentType == 'refill_request') {
                        return _buildRefillRequest(
                          t,
                          contact,
                          message,
                          displayText,
                        );
                      }

                      final bool isSystem = message.senderId == 'system';
                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16, top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: t.action.withValues(alpha: 0.07),
                              border: Border.all(
                                color: t.action.withValues(alpha: 0.25),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(t.radiusPill),
                            ),
                            child: Text(
                              t.uppercaseLabels
                                  ? displayText.toUpperCase()
                                  : displayText,
                              style: t.dataMono.copyWith(
                                color: t.action,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        );
                      }

                      final bool isFirstInBatch =
                          (index == 0) ||
                          (messageList[index - 1].senderId !=
                              message.senderId) ||
                          messageList[index - 1].senderId == 'system';

                      Contact? memberContact;
                      for (final c in _appState.contacts) {
                        if (c.keyHash == message.senderId) {
                          memberContact = c;
                          break;
                        }
                      }

                      final groupProfiles =
                          _appState.groupProfilesCache[contact.id];
                      final memberProfile = groupProfiles?[message.senderId];

                      final String senderName = isMe
                          ? (_appState.deviceName.isNotEmpty
                                ? _appState.deviceName
                                : 'You')
                          : (memberProfile != null
                                ? memberProfile['name'] ?? ''
                                : (memberContact != null
                                      ? memberContact.name
                                      : 'Member ${message.senderId.substring(0, min(6, message.senderId.length))}'));

                      final String avatarHex = isMe
                          ? (_appState.profileImageB64.isNotEmpty
                                ? _appState.profileImageB64
                                : PixelArtAvatar.generateIdenticon(
                                    _appState.userId,
                                  ))
                          : (memberProfile != null &&
                                    memberProfile['profile_image'] != null &&
                                    memberProfile['profile_image']!.isNotEmpty
                                ? memberProfile['profile_image']!
                                : (memberContact != null &&
                                          memberContact.profileImageB64 !=
                                              null &&
                                          memberContact
                                              .profileImageB64!
                                              .isNotEmpty
                                      ? memberContact.profileImageB64!
                                      : PixelArtAvatar.generateIdenticon(
                                          message.senderId,
                                        )));

                      // Self uses the action accent; the host uses the identity
                      // accent; every other member gets their own stable colour
                      // (the same one as their flower/bar slice) so messages are
                      // easy to tell apart.
                      final bool isSenderHost =
                          !isMe &&
                          contact.hostKeyHash != null &&
                          message.senderId == contact.hostKeyHash;
                      final Color memberColor = isMe
                          ? t.action
                          : (isSenderHost
                                ? t.identity
                                : memberPaletteColor(message.senderId));
                      final Color borderColor = isMe
                          ? t.bubbleMeBorder
                          : memberColor.withValues(alpha: 0.45);
                      // Tint each member's bubble fill toward their own colour
                      // (subtle), so senders are distinguishable at a glance.
                      // Blending into [bubbleThem] keeps it theme-appropriate:
                      // it darkens on dark themes, brightens on the light one.
                      final Color bgColor = isMe
                          ? t.bubbleMe
                          : Color.lerp(t.bubbleThem, memberColor, 0.14)!;
                      final Color nameColor = memberColor;

                      final Widget bubble = Container(
                        margin: EdgeInsets.only(
                          bottom: isFirstInBatch ? 12 : 4,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(
                            color: borderColor,
                            width: t.borderWidth,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(t.radiusCard),
                            topRight: Radius.circular(t.radiusCard),
                            bottomLeft: isMe
                                ? Radius.circular(t.radiusCard)
                                : const Radius.circular(6),
                            bottomRight: isMe
                                ? const Radius.circular(6)
                                : Radius.circular(t.radiusCard),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildGroupContent(
                              t,
                              message,
                              displayText,
                              emojiMap,
                              isMe,
                            ),
                            const SizedBox(height: 4),
                            message.isPending
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 8,
                                        height: 8,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.3,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                isMe
                                                    ? t.bubbleMeText.withValues(
                                                        alpha: 0.6,
                                                      )
                                                    : t.textTertiary,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        l10n.chatEncrypting,
                                        style: t.dataMono.copyWith(
                                          fontSize: 9,
                                          color: isMe
                                              ? t.bubbleMeText.withValues(
                                                  alpha: 0.6,
                                                )
                                              : t.textTertiary,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                        style: t.dataMono.copyWith(
                                          fontSize: 9,
                                          color: isMe
                                              ? t.bubbleMeText.withValues(
                                                  alpha: 0.6,
                                                )
                                              : t.textTertiary,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          message.isDelivered
                                              ? Icons.done_all
                                              : Icons.check,
                                          color: message.isDelivered
                                              ? t.action
                                              : t.textTertiary,
                                          size: 10,
                                        ),
                                      ],
                                    ],
                                  ),
                          ],
                        ),
                      );

                      return Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            isFirstInBatch
                                ? PixelArtAvatar(hexString: avatarHex, size: 28)
                                : const SizedBox(width: 28),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (isFirstInBatch)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: 4.0,
                                      left: isMe ? 0.0 : 2.0,
                                      right: isMe ? 2.0 : 0.0,
                                    ),
                                    child: Text(
                                      senderName,
                                      style: t.dataMono.copyWith(
                                        color: nameColor,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                message.isPending
                                    ? Opacity(opacity: 0.6, child: bubble)
                                    : bubble,
                              ],
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            isFirstInBatch
                                ? PixelArtAvatar(hexString: avatarHex, size: 28)
                                : const SizedBox(width: 28),
                          ],
                        ],
                      );
                    },
                  ),
                ),

                Container(
                  color: t.bg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: isWilted
                      ? (!contact.isHost
                            ? _buildRefillComposer(t, contact)
                            : _buildLockedComposer(t))
                      : _buildComposer(t, contact),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 90,
          right: 16,
          child: AnimatedOpacity(
            opacity: _showScrollDownArrow ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _showScrollDownArrow
                ? FloatingActionButton.small(
                    backgroundColor: t.surface,
                    shape: CircleBorder(
                      side: BorderSide(color: t.action.withValues(alpha: 0.5)),
                    ),
                    onPressed: () {
                      _scrollToBottom();
                      setState(() {
                        _showScrollDownArrow = false;
                      });
                    },
                    child: Icon(Icons.arrow_downward, color: t.action),
                  )
                : const SizedBox(),
          ),
        ),
      ],
    );
  }

  Widget _buildRefillRequest(
    WiltkeyTokens t,
    Contact contact,
    ChatMessage message,
    String displayText,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.budgetWilted.withValues(alpha: 0.06),
        border: Border.all(
          color: t.budgetWilted.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.battery_alert, color: t.budgetWilted, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.uppercaseLabels ? displayText.toUpperCase() : displayText,
                  style: t.dataMono.copyWith(
                    color: t.budgetWilted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (contact.isHost) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await _appState.grantLaneRefill(contact, message.senderId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.groupRefillGranted)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.groupRefillFailed(e.toString())),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add_moderator, size: 14),
              label: Text(
                t.uppercaseLabels
                    ? l10n.groupGrantRefill.toUpperCase()
                    : l10n.groupGrantRefill,
                style: t.badgeLabel,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.action,
                foregroundColor: t.onAction,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLockedComposer(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.budgetWilted.withValues(alpha: 0.05),
        border: Border.all(
          color: t.budgetWilted.withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Text(
        t.uppercaseLabels
            ? l10n.groupLaneLocked.toUpperCase()
            : l10n.groupLaneLocked,
        style: t.dataMono.copyWith(color: t.budgetWilted, letterSpacing: 0.6),
      ),
    );
  }

  Widget _buildRefillComposer(WiltkeyTokens t, Contact contact) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.budgetWilted.withValues(alpha: 0.05),
        border: Border.all(
          color: t.budgetWilted.withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.uppercaseLabels
                      ? l10n.groupLaneDepleted.toUpperCase()
                      : l10n.groupLaneDepleted,
                  style: t.dataMono.copyWith(
                    color: t.budgetWilted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(l10n.groupLaneDepletedExplanation, style: t.bodySecondary),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _appState.requestLaneRefill(contact);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.groupRefillRequestSent)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.budgetWilted,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
            child: Text(
              t.uppercaseLabels
                  ? l10n.groupRequestRefill.toUpperCase()
                  : l10n.groupRequestRefill,
              style: t.badgeLabel.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(WiltkeyTokens t, Contact contact) {
    final l10n = AppLocalizations.of(context)!;
    final bool overSize =
        contact.maxMessageSize != null && _charCount > contact.maxMessageSize!;
    final int cost = _charCount > 0 ? _charCount + 73 : 0;
    return Column(
      children: [
        EmojiAutocompleteBar(
          controller: _messageController,
          emojiMap: CustomEmojiStore.cachedMap(contact.keyHash),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: IconButton(
                icon: Icon(
                  _showEmoji
                      ? Icons.keyboard_outlined
                      : Icons.emoji_emotions_outlined,
                  color: t.action,
                  size: 22,
                ),
                onPressed: _toggleEmoji,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocus,
                maxLines: null,
                onTap: _hideEmoji,
                style: t.body.copyWith(fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.chatMessageHint,
                  hintStyle: t.body.copyWith(
                    fontSize: 13,
                    color: t.textTertiary,
                  ),
                  filled: true,
                  fillColor: t.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: t.border,
                      width: t.borderWidth,
                    ),
                    borderRadius: BorderRadius.circular(t.radiusCard),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: t.action,
                      width: t.borderWidth,
                    ),
                    borderRadius: BorderRadius.circular(t.radiusCard),
                  ),
                ),
              ),
            ),
            if (contact.imagesAllowed ?? true) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: IconButton(
                  icon: Icon(
                    Icons.photo_library_outlined,
                    color: t.action,
                    size: 22,
                  ),
                  onPressed: () => _pickAndSendGroupImage(contact),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: _charCount == 0
                  ? IconButton(
                      icon: Icon(
                        Icons.mic_none_outlined,
                        color: t.action,
                        size: 22,
                      ),
                      onPressed: _onMicTap,
                    )
                  : AnimatedBuilder(
                      animation: _sendBloom,
                      builder: (context, child) {
                        final scale = 1.0 + 0.16 * sin(_sendBloom.value * pi);
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: overSize ? t.textTertiary : t.action,
                          borderRadius: BorderRadius.circular(t.radiusControl),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.send, color: t.onAction, size: 18),
                          onPressed: overSize ? null : _handleSend,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        if (_showEmoji)
          EmojiPickerPanel(
            controller: _messageController,
            emojiMap: CustomEmojiStore.cachedMap(contact.keyHash),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              overSize
                  ? l10n.groupExceedsSizeLimit(contact.maxMessageSize!)
                  : l10n.chatCostIndicator(
                      cost > 0 ? AppState.formatBytes(cost) : "0 B",
                    ),
              style: t.dataMono.copyWith(
                color: (overSize || cost > contact.remainingBufferBytes)
                    ? t.danger
                    : t.textTertiary,
              ),
            ),
            Text(
              '${l10n.chatRemainingLabel(AppState.formatBytes(max(0, contact.remainingBufferBytes - cost)))} / ${AppState.formatBytes(contact.maxBufferBytes)}',
              style: t.dataMono.copyWith(color: t.textTertiary),
            ),
          ],
        ),
      ],
    );
  }

  void _removeMemberFromTopology(String memberKeyHash, String memberName) {
    final contact = _appState.activeContact;
    if (contact == null) return;
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusCard),
            side: BorderSide(color: t.danger, width: 1),
          ),
          title: Text(
            t.uppercaseLabels
                ? l10n.groupRemoveMemberTitle.toUpperCase()
                : l10n.groupRemoveMemberTitle,
            style: t.screenTitle.copyWith(color: t.danger, fontSize: 16),
          ),
          content: Text(
            l10n.groupRemoveMemberBody(memberName),
            style: t.bodySecondary,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.commonCancel,
                style: TextStyle(color: t.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  contact.memberKeyHashes.remove(memberKeyHash);
                  _appState.notifyMessageReceived();
                  _appState.log(
                    '[Group] Removed member $memberKeyHash from group ${contact.name}',
                  );
                  _appState.broadcastGroupMetadataUpdate(contact);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
              child: Text(l10n.groupRemoveMember),
            ),
          ],
        );
      },
    );
  }

  void _leaveGroupFromTopology() {
    final contact = _appState.activeContact;
    if (contact == null) return;
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
                await _appState.nukeContact(
                  contact.keyHash,
                  receivedFromPeer: false,
                );
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
              child: Text(l10n.groupLeaveGroup),
            ),
          ],
        );
      },
    );
  }

  void _showMembersSheet(Contact contact) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.85,
            child: AnimatedBuilder(
              animation: _appState,
              builder: (context, _) {
                final memberList =
                    _appState.groupMembersMetadata[contact.id] ?? [];
                final slotsInfo = _appState.groupSlotsInfo[contact.id];
                final usedSlots = slotsInfo?['used'] ?? 0;
                final totalSlots = slotsInfo?['total'] ?? 0;
                final emptySlots = max(0, totalSlots - usedSlots);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                      child: Row(
                        children: [
                          Icon(Icons.hub, color: t.identity, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            t.uppercaseLabels
                                ? l10n.groupMembersTitle.toUpperCase()
                                : l10n.groupMembersTitle,
                            style: t.screenTitle.copyWith(fontSize: 16),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${memberList.length}/${contact.maxMembers ?? 20}',
                            style: t.dataMono.copyWith(
                              color: t.action,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: t.textSecondary,
                              size: 22,
                            ),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    if (memberList.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: context.wkc.groupBudgetIndicator(
                          members: _memberBudgets(memberList),
                          emptySlots: emptySlots,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.groupMembersExplanation,
                        style: t.bodySecondary,
                      ),
                    ),
                    if (emptySlots > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          l10n.groupEmptySlots(emptySlots),
                          style: t.dataMono.copyWith(
                            color: t.positive,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Divider(color: t.border, height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        children: memberList
                            .map(
                              (m) => _buildMemberSheetCard(
                                t,
                                m,
                                contact,
                                sheetContext,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          if (contact.isHost)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GroupInviteScreen(group: contact),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.person_add, size: 16),
                                label: Text(l10n.groupInviteMember),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: t.identity,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      t.radiusControl,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (!contact.isHost)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _leaveGroupFromTopology();
                                },
                                icon: const Icon(Icons.exit_to_app, size: 16),
                                label: Text(l10n.groupLeaveGroup),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: t.danger,
                                  side: BorderSide(color: t.danger, width: 1),
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      t.radiusControl,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberSheetCard(
    WiltkeyTokens t,
    Map<String, dynamic> m,
    Contact contact,
    BuildContext sheetContext,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final String name = m['name'] ?? '';
    final String keyHash = m['keyHash'] ?? '';
    final int remaining = (m['remaining'] as int?) ?? 0;
    final int maxBytes = (m['max'] as int?) ?? 0;
    final double percent = maxBytes > 0
        ? (remaining / maxBytes).clamp(0.0, 1.0)
        : 0.0;
    final bool wilted = remaining <= 0;
    final bool isSelf = m['isSelf'] ?? false;
    final bool isMemberHost = m['isHost'] ?? false;

    final String? cachedImage =
        _appState.groupProfilesCache[contact.id]?[keyHash]?['profile_image'];
    final String avatarHex = isSelf
        ? (_appState.profileImageB64.isNotEmpty
              ? _appState.profileImageB64
              : PixelArtAvatar.generateIdenticon(_appState.userId))
        : (cachedImage != null && cachedImage.isNotEmpty
              ? cachedImage
              : PixelArtAvatar.generateIdenticon(keyHash));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusCard),
        border: Border.all(
          color: isSelf
              ? t.action.withValues(alpha: 0.3)
              : t.identity.withValues(alpha: 0.18),
          width: t.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelArtAvatar(hexString: avatarHex, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: t.body.copyWith(
                        color: wilted
                            ? t.budgetWilted
                            : (isSelf ? t.action : t.textPrimary),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMemberHost
                          ? (t.uppercaseLabels
                                ? l10n.groupHost.toUpperCase()
                                : l10n.groupHost)
                          : (t.uppercaseLabels
                                ? l10n.groupMember.toUpperCase()
                                : l10n.groupMember),
                      style: t.dataMono.copyWith(
                        color: isMemberHost ? t.action : t.textTertiary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 36,
                child: context.wkc.budgetIndicator(
                  ourFraction: percent,
                  isWilted: wilted,
                  variant: BudgetIndicatorVariant.listRow,
                  semanticLabel: l10n.chatRemainingLabel(
                    AppState.formatBytes(remaining),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                wilted
                    ? (t.uppercaseLabels
                          ? l10n.groupDepleted.toUpperCase()
                          : l10n.groupDepleted)
                    : AppState.formatBytes(remaining),
                style: t.dataMono.copyWith(
                  color: wilted ? t.budgetWilted : t.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!isSelf) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _appState.syncGroupFromMember(contact, keyHash);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.groupSyncingFromMember(name)),
                          backgroundColor: t.identity,
                        ),
                      );
                    },
                    icon: const Icon(Icons.sync, size: 16),
                    label: Text(l10n.groupSyncStepText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.positive,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                    ),
                  ),
                ),
                if (contact.isHost && !isMemberHost) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _removeMemberFromTopology(keyHash, name),
                      icon: const Icon(Icons.person_remove, size: 16),
                      label: Text(l10n.groupRemoveMember),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.danger,
                        side: BorderSide(color: t.danger, width: 1),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(t.radiusControl),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupContent(
    WiltkeyTokens t,
    ChatMessage message,
    String displayText,
    Map<String, CustomEmoji> emojiMap,
    bool isMe,
  ) {
    final ct = message.contentType;
    if (ct == 'image' || ct == 'image_hidden') {
      return _buildGroupImage(t, message);
    }
    final scale = _appState.chatTextScale;
    final textColor = isMe ? t.bubbleMeText : t.textPrimary;
    final jumbo = jumboEmojiCount(displayText, emojiMap);
    if (jumbo != null) {
      final base = jumbo == 1 ? 40.0 : (jumbo <= 3 ? 34.0 : 26.0);
      return EmojiText(
        text: displayText,
        emojiMap: emojiMap,
        style: t.body.copyWith(
          color: textColor,
          fontSize: base * scale,
          height: 1.15,
        ),
        emojiSize: base * 1.25 * scale,
      );
    }
    return EmojiText(
      text: displayText,
      emojiMap: emojiMap,
      style: t.body.copyWith(
        color: textColor,
        fontSize: 13 * scale,
        height: 1.4,
      ),
      emojiSize: 20 * scale,
    );
  }

  Widget _buildGroupImage(WiltkeyTokens t, ChatMessage message) {
    final l10n = AppLocalizations.of(context)!;
    final String? b64 = message.decryptedText;
    if (b64 == null || b64.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(t.action),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            t.uppercaseLabels
                ? l10n.groupDecryptingImage.toUpperCase()
                : l10n.groupDecryptingImage,
            style: t.dataMono.copyWith(color: t.action, fontSize: 11),
          ),
        ],
      );
    }

    final bool isHidden = message.contentType == 'image_hidden';
    final bool revealed = _revealedImageIds.contains(message.id);

    if (isHidden && !revealed) {
      int rawSize = 0;
      try {
        rawSize = base64Decode(b64).length;
      } catch (_) {}
      return GestureDetector(
        onTap: () => setState(() => _revealedImageIds.add(message.id)),
        child: Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(
              color: t.action.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(t.radiusControl),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_off_outlined, color: t.action, size: 28),
              const SizedBox(height: 8),
              Text(
                t.uppercaseLabels
                    ? l10n.groupTapToRevealImage.toUpperCase()
                    : l10n.groupTapToRevealImage,
                style: t.dataMono.copyWith(color: t.action, fontSize: 10),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.groupImageSize(AppState.formatBytes(rawSize)),
                style: t.dataMono.copyWith(
                  color: t.textTertiary,
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Uint8List? imageBytes = message.decodedImageBytes;
    if (imageBytes == null) {
      try {
        imageBytes = base64Decode(b64);
        message.decodedImageBytes = imageBytes;
      } catch (_) {}
    }

    if (imageBytes == null) {
      return _imageError(t);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300, maxWidth: 260),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusControl),
        child: Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _imageError(t),
        ),
      ),
    );
  }

  Widget _imageError(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusControl),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, color: t.danger, size: 16),
          const SizedBox(width: 6),
          Text(
            l10n.groupImageFailedToLoad,
            style: t.bodySecondary.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
