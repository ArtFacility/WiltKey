import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/custom_emoji.dart';
import '../../../core/image_utils.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/wiltkey_components.dart';
import 'chat_details_screen.dart';
import 'widgets/message_bubble.dart';
import 'widgets/emoji_autocomplete_bar.dart';
import 'widgets/emoji_picker_panel.dart';
import 'widgets/diagnostics_dialog.dart';
import 'widgets/failed_actions_dialog.dart';
import 'widgets/compression_dialog.dart';
import 'widgets/debug_console_sheet.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final AppState _appState = AppState();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  int _charCount = 0;

  // Emoji picker panel visibility (shown in place of the keyboard).
  bool _showEmoji = false;

  // Guards against firing overlapping older-page loads while scrolling up.
  bool _loadingOlder = false;

  bool _isAtBottom = true;
  bool _showScrollDownArrow = false;
  final Set<String> _revealedMessageIds = {};

  // Send-button "bloom" micro-animation.
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
      // Load the most-recent page (windowed), then decrypt any OTP-only ones.
      _appState.loadInitialMessages(contact).then((_) async {
        if (!mounted) return;
        // Await decryption (it fills text heights) BEFORE pinning, then re-pin
        // across frames so async height growth (images) can't strand us partway.
        await _appState.decryptBatch(contact);
        if (!mounted) return;
        _pinToBottomUntilStable();
      });
      CustomEmojiStore.load(contact.keyHash).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    // Mark everything seen during this session read, so leaving the chat clears
    // its unread badge on the list.
    final c = _appState.activeContact;
    if (c != null) _appState.markChatRead(c);
    _sendBloom.dispose();
    _appState.removeListener(_updateState);
    _messageController.removeListener(_updateCharCount);
    _scrollController.removeListener(_scrollListener);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  List<ChatMessage> _visibleMessages(Contact contact) {
    return (_appState.messages[contact.id] ?? [])
        .where(
          (m) =>
              m.contentType != 'emoji_def' && m.contentType != 'emoji_delete',
        )
        .toList();
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
    // Near the top → page in older history, anchoring the view so it doesn't jump.
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
      // Stop once the height has been steady for a few frames, or after a cap
      // (~0.5s) so we never trap the user from scrolling on a slow-loading chat.
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

  Future<void> _pickAndSendImage() async {
    final contact = _appState.activeContact;
    if (contact == null) return;

    final ImagePicker picker = ImagePicker();
    XFile? image;
    try {
      _appState.isPickingMedia = true;
      image = await picker.pickImage(source: ImageSource.gallery);
    } finally {
      _appState.isPickingMedia = false;
    }
    if (image == null) return;

    final originalBytes = await image.readAsBytes();
    final originalSize = originalBytes.length;

    if (!mounted) return;
    final CompressionResult? choice = await CompressionDialog.show(
      context,
      originalSize,
    );
    if (choice == null) return;

    final imageBytes = await ImageUtils.prepareForSend(
      originalBytes,
      quality: (choice.quality * 100).toInt(),
    );

    final base64Data = base64Encode(imageBytes);
    final byteCost = base64Data.length + 73;
    final String contentType = choice.hidden ? 'image_hidden' : 'image';

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

    final error = await _appState.sendMessage(
      base64Data,
      contentType: contentType,
      mimeType: 'image/webp',
    );
    if (error != null) {
      _errorSnack(error);
    }
    _scrollToBottom();
  }

  void _toggleEmoji() {
    setState(() => _showEmoji = !_showEmoji);
    if (_showEmoji) {
      _inputFocus.unfocus(); // hide the system keyboard, reveal the picker
    } else {
      _inputFocus.requestFocus(); // back to the keyboard
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

    _sendBloom.forward(from: 0); // bloom on tap

    // Clear the field instantly — the bubble shows immediately as a pending
    // "Encrypting…" placeholder while the send completes in the background.
    _messageController.clear();
    _scrollToBottom();

    final error = await _appState.sendMessage(text);
    if (error != null && mounted) {
      _errorSnack(error);
      // A pre-flight failure (e.g. out of keystream) leaves no bubble — restore
      // the draft so the user doesn't lose it.
      _messageController.text = text;
    }
  }

  void _openChatDetails(Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailsScreen(contact: contact),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final contact = _appState.activeContact;
    if (contact == null) return const Scaffold(body: SizedBox());

    final messageList = _visibleMessages(contact);
    final double currentPercent = contact.chargePercentage;
    final String maxFormatted = AppState.formatBytes(contact.maxBufferBytes);
    final bool isWilted = contact.isWilted;
    final bool isArchived = contact.isArchived;

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
                  onTap: () => _openChatDetails(contact),
                  child: Row(
                    children: [
                      PixelArtAvatar(
                        hexString:
                            (contact.profileImageB64 != null &&
                                contact.profileImageB64!.isNotEmpty)
                            ? contact.profileImageB64!
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
                    onTap: () => _openChatDetails(contact),
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
                          l10n.chatTapForDetails,
                          style: t.dataMono.copyWith(
                            fontSize: 9,
                            color: t.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Budget glyph in the header (flower in garden, compact bar in
                // cyberpunk). Tap → diagnostics.
                GestureDetector(
                  onTap: () => DiagnosticsDialog.show(
                    context,
                    contact,
                    _appState.userId,
                  ),
                  child: context.wkc.budgetIndicator(
                    ourFraction: currentPercent,
                    theirFraction: contact.getTheirChargePercentage(
                      _appState.userId,
                    ),
                    isWilted: isWilted,
                    split: true,
                    variant: BudgetIndicatorVariant.chatHeader,
                    semanticLabel: l10n.chatRemainingLabel(
                      AppState.formatBytes(contact.remainingBufferBytes),
                    ),
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
            ],
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
                                ? (isArchived
                                          ? l10n.chatsArchivedSubtitle
                                          : l10n.chatLockedLabel)
                                      .toUpperCase()
                                : (isArchived
                                      ? l10n.chatsArchivedSubtitle
                                      : l10n.chatLockedLabel),
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
                      final String displayText =
                          message.decryptedText ?? message.text;

                      final bool isFirstInBatch =
                          (index == 0) ||
                          (messageList[index - 1].isSentByMe !=
                              message.isSentByMe) ||
                          messageList[index - 1].isSystem;

                      return MessageBubble(
                        message: message,
                        displayText: displayText,
                        contact: contact,
                        appState: _appState,
                        emojiMap: CustomEmojiStore.cachedMap(contact.keyHash),
                        isMe: message.isSentByMe,
                        isFirstInBatch: isFirstInBatch,
                        isRevealed: _revealedMessageIds.contains(message.id),
                        onRevealTap: () {
                          setState(() {
                            _revealedMessageIds.add(message.id);
                          });
                        },
                        onFailedTap: () => FailedActionsDialog.show(
                          context,
                          contact,
                          message,
                          _appState,
                        ),
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
                      ? _buildLockedComposer(t)
                      : _buildComposer(t, contact, maxFormatted),
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

  Widget _buildLockedComposer(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.action.withValues(alpha: 0.05),
        border: Border.all(color: t.action.withValues(alpha: 0.25), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: t.action, size: 14),
          const SizedBox(width: 8),
          Text(
            t.uppercaseLabels
                ? l10n.chatLockedLabel.toUpperCase()
                : l10n.chatLockedLabel,
            style: t.dataMono.copyWith(color: t.action, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(WiltkeyTokens t, Contact contact, String maxFormatted) {
    final l10n = AppLocalizations.of(context)!;
    final cost = _charCount > 0 ? (_charCount + 73) : 0;
    final overBudget = cost > contact.remainingBufferBytes;
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
              padding: const EdgeInsets.only(bottom: 4.0),
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
                minLines: 1,
                maxLines: 8,
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
                  onPressed: _pickAndSendImage,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: _charCount == 0
                  // Empty field: voice-message affordance (recording wired later).
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
                        final v = _sendBloom.value;
                        final scale =
                            1.0 + 0.16 * sin(v * pi); // bloom out and back
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.action,
                          borderRadius: BorderRadius.circular(t.radiusControl),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.send, color: t.onAction, size: 18),
                          onPressed: _handleSend,
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
              l10n.chatCostIndicator(
                cost > 0 ? AppState.formatBytes(cost) : "0 B",
              ),
              style: t.dataMono.copyWith(
                color: overBudget ? t.danger : t.textTertiary,
              ),
            ),
            Text(
              '${l10n.chatRemainingLabel(AppState.formatBytes(max(0, contact.remainingBufferBytes - cost)))} / $maxFormatted',
              style: t.dataMono.copyWith(color: t.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}
