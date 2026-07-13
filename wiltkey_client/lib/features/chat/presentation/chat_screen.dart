import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/custom_emoji.dart';
import 'widgets/image_source_sheet.dart';
import 'widgets/screenshot_ui.dart';
import 'widgets/wilt_duration_sheet.dart';
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
import 'widgets/voice_recording_mixin.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, VoiceRecordingMixin {
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

  // Wraps the message list so a consented screenshot can render it to an image.
  final GlobalKey _captureBoundaryKey = GlobalKey();

  // The chat this screen opened with — used to release the "visible chat" flag on
  // dispose only if a newer chat hasn't taken over (see [AppState.visibleChatId]).
  String? _openChatId;

  // Send-button "bloom" micro-animation.
  late final AnimationController _sendBloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  // Voice recording (hold-to-record mic + quality chip + HUD) lives in
  // VoiceRecordingMixin; this screen just wires the hooks below.
  @override
  Contact? get voiceContact => _appState.activeContact;

  @override
  Future<String?> sendVoiceMessage(String base64Payload, String mimeType) =>
      _appState.sendMessage(
        base64Payload,
        contentType: 'voice',
        mimeType: mimeType,
      );

  @override
  void onVoiceError(String message) => _errorSnack(message);

  @override
  void onVoiceSent() => _scrollToBottom();

  @override
  void onVoiceRecordingStarted() {
    _hideEmoji();
    _inputFocus.unfocus();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appState.addListener(_updateState);
    _messageController.addListener(_updateCharCount);
    _scrollController.addListener(_scrollListener);
    _appState.screenshotCaptureSignal.addListener(_onScreenshotCaptureSignal);
    _appState.screenshotDeniedSignal.addListener(_onScreenshotDeniedSignal);

    final contact = _appState.activeContact;
    if (contact != null) {
      _openChatId = contact.id;
      _appState.visibleChatId = contact.id; // now on screen → mute its own alerts
      // Load the most-recent page (windowed), then decrypt any OTP-only ones.
      _appState.loadInitialMessages(contact).then((_) async {
        if (!mounted) return;
        // Await decryption (it fills text heights) BEFORE pinning, then re-pin
        // across frames so async height growth (images) can't strand us partway.
        await _appState.decryptBatch(contact);
        if (!mounted) return;
        _pinToBottomUntilStable();
        // One-shot reconciliation on open: only fires when there's actually
        // something to fix (a stuck-undelivered run or an inbound gap), so it's
        // not server spam — just heals the common "stuck on single-check" case
        // without the user hunting for the sync button.
        if (!contact.isGroup && _needsReconcile(contact)) {
          _appState.syncOneOnOneChat(contact);
        }
      });
      CustomEmojiStore.load(contact.keyHash).then((_) {
        if (mounted) setState(() {});
      });
    }

    initVoiceRecording();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Mark everything seen during this session read, so leaving the chat clears
    // its unread badge on the list.
    final c = _appState.activeContact;
    if (c != null) _appState.markChatRead(c);
    // Release the "visible chat" flag so the dashboard resumes alerting for this
    // chat — but only if a newer chat hasn't already claimed it (deep-link on top).
    if (_appState.visibleChatId == _openChatId) _appState.visibleChatId = null;
    _sendBloom.dispose();
    _appState.removeListener(_updateState);
    _appState.screenshotCaptureSignal.removeListener(_onScreenshotCaptureSignal);
    _appState.screenshotDeniedSignal.removeListener(_onScreenshotDeniedSignal);
    _messageController.removeListener(_updateCharCount);
    _scrollController.removeListener(_scrollListener);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    disposeVoiceRecording();
    super.dispose();
  }

  /// Enough peers approved our request → render this chat to an image + open it.
  void _onScreenshotCaptureSignal() {
    if (!mounted) return;
    if (_appState.screenshotCaptureSignal.value != _appState.activeContact?.id) {
      return;
    }
    _appState.screenshotCaptureSignal.value = null;
    captureChatAndOpen(context, _captureBoundaryKey);
  }

  void _onScreenshotDeniedSignal() {
    if (!mounted) return;
    if (_appState.screenshotDeniedSignal.value != _appState.activeContact?.id) {
      return;
    }
    _appState.screenshotDeniedSignal.value = null;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.screenshotDenied)));
  }

  Future<void> _requestScreenshot(Contact contact) async {
    await _appState.requestScreenshot(contact);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.screenshotWaiting)));
  }

  /// One row of the header overflow menu: accent icon + label.
  Widget _menuRow(WiltkeyTokens t, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: t.action, size: 18),
        const SizedBox(width: 12),
        Text(label, style: t.body),
      ],
    );
  }

  /// Fires on every viewport metrics change, including each frame the soft
  /// keyboard animates in/out. If we were pinned to the bottom (reading the
  /// latest message — the one you're replying to), stay pinned as the list's
  /// viewport shrinks, instead of leaving the last message hidden behind the
  /// keyboard.
  @override
  void didChangeMetrics() {
    if (!_isAtBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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
        // Show the jump-to-latest pill whenever we're scrolled up (not only when
        // a new message lands), and hide it the moment we're back at the bottom.
        _showScrollDownArrow = !atBottom;
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

  /// A small "jump to latest" pill that fades/slides in whenever the user is
  /// scrolled up, sitting just above the composer. Tapping it snaps to the
  /// bottom. Hidden (and non-interactive) when already at the bottom.
  Widget _scrollDownPill(WiltkeyTokens t) {
    return IgnorePointer(
      ignoring: !_showScrollDownArrow,
      child: AnimatedSlide(
        offset: _showScrollDownArrow ? Offset.zero : const Offset(0, 0.6),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _showScrollDownArrow ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: Center(
            child: Material(
              color: t.surface,
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              shape: StadiumBorder(
                side: BorderSide(color: t.action.withValues(alpha: 0.5)),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () {
                  _scrollToBottom();
                  setState(() => _showScrollDownArrow = false);
                },
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    Icons.keyboard_double_arrow_down,
                    size: 20,
                    color: t.action,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
      // Stop once the height has been steady for several frames, or after a cap
      // (~2.5s) so we never trap the user from scrolling on a slow-loading chat.
      // The generous window lets many async image decodes finish growing the
      // list before we settle, so an image-heavy chat opens pinned to the bottom
      // instead of stranding a few screens up.
      if (stableFrames < 6 && totalFrames < 150) {
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

  /// Tapping the image button: choose camera vs gallery, then run the send flow.
  Future<void> _onImageButton() async {
    final src = await showImageSourceSheet(context);
    if (src == null || !mounted) return;
    await _pickAndSendImage(src);
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final contact = _appState.activeContact;
    if (contact == null) return;

    final ImagePicker picker = ImagePicker();
    XFile? image;
    try {
      _appState.isPickingMedia = true;
      image = await picker.pickImage(source: source);
    } finally {
      _appState.isPickingMedia = false;
    }
    if (image == null) return;

    final originalBytes = await image.readAsBytes();

    if (!mounted) return;
    // The dialog compresses live and returns the exact bytes it showed a size
    // for — so we send those directly instead of recompressing (and guessing).
    final CompressionResult? choice = await CompressionDialog.show(
      context,
      originalBytes,
    );
    if (choice == null) return;

    final base64Data = base64Encode(choice.bytes);
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
      allowSave: choice.allowSave,
      ephemeral: choice.ephemeral,
      ttlSeconds: choice.ttlSeconds,
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

  /// Long-press on the send button → compose a wilting (disappearing) message.
  /// Picks a lifetime, then sends with ephemeral flags. Backing out sends nothing
  /// (a normal message still goes on a plain tap).
  void _handleSendWilting() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final secs = await showWiltDurationSheet(context);
    if (secs == null || !mounted) return;
    _sendBloom.forward(from: 0);
    _messageController.clear();
    _scrollToBottom();
    final error = await _appState.sendMessage(
      text,
      ephemeral: true,
      ttlSeconds: secs,
    );
    if (error != null && mounted) {
      _errorSnack(error);
      _messageController.text = text;
    }
  }

  /// Long-press on an emoji in the picker → send it immediately as a sticker
  /// (a big, bubble-less solitary message). Rides the normal text path with a
  /// sentinel marker, so encryption/delivery/resync are unchanged.
  void _handleSendSticker(String payload) async {
    _sendBloom.forward(from: 0);
    _scrollToBottom();
    final error = await _appState.sendMessage(wrapSticker(payload));
    if (error != null && mounted) _errorSnack(error);
  }

  /// True when a sent message is still on a single check while a *later* sent
  /// message already double-checked — a strong tell that an earlier delivery
  /// receipt was lost. Also true when the peer's incoming pointer shows a gap
  /// (we're missing inbound history). Drives both the auto-reconcile-on-open and
  /// the attention dot on the header sync button.
  bool _needsReconcile(Contact contact) {
    final list = _appState.messages[contact.id] ?? [];
    bool seenDeliveredLater = false;
    for (int i = list.length - 1; i >= 0; i--) {
      final m = list[i];
      if (!m.isSentByMe || m.isPending || m.isFailed) continue;
      if (m.isDelivered) {
        seenDeliveredLater = true;
      } else if (seenDeliveredLater) {
        return true; // undelivered older than a delivered one → stuck receipt
      }
    }
    return false;
  }

  Future<void> _handleSyncTap(Contact contact) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final t = context.wk;
    final ok = await _appState.syncOneOnOneChat(contact);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: t.surface,
        content: Text(
          ok ? l10n.chatSyncStarted : l10n.chatSyncOffline,
          style: t.bodySecondary.copyWith(color: ok ? t.action : t.danger),
        ),
      ),
    );
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

    return PopScope(
      // Back / back-gesture closes the emoji panel first; the chat only pops
      // once nothing else is open.
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showEmoji) _hideEmoji();
      },
      child: Stack(
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
                              : PixelArtAvatar.generateIdenticon(
                                  contact.keyHash,
                                ),
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
                // Overflow menu keeps the header uncluttered: only the budget
                // glyph stays inline; sync / screenshot / debug live in here. The
                // sync glyph still reflects the "sync problem" state on the button.
                PopupMenuButton<String>(
                  icon: Icon(
                    _needsReconcile(contact)
                        ? Icons.sync_problem
                        : Icons.more_vert,
                    color: t.action,
                    size: 20,
                  ),
                  color: t.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusControl),
                    side: BorderSide(color: t.border, width: t.borderWidth),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'sync':
                        _handleSyncTap(contact);
                      case 'screenshot':
                        _requestScreenshot(contact);
                      case 'debug':
                        DebugConsoleSheet.show(context, _appState);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'sync',
                      child: _menuRow(
                        t,
                        _needsReconcile(contact)
                            ? Icons.sync_problem
                            : Icons.sync,
                        l10n.chatSyncTooltip,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'screenshot',
                      child: _menuRow(
                        t,
                        Icons.screenshot_outlined,
                        l10n.screenshotRequestTooltip,
                      ),
                    ),
                    if (_appState.showDebugButtons)
                      PopupMenuItem(
                        value: 'debug',
                        child: _menuRow(
                          t,
                          Icons.terminal_outlined,
                          'Debug terminal',
                        ),
                      ),
                  ],
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
                          Icon(
                            Icons.lock_clock,
                            color: t.budgetWilted,
                            size: 16,
                          ),
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
                              style: t.badgeLabel.copyWith(
                                color: t.budgetWilted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          key: _captureBoundaryKey,
                          child: ColoredBox(
                            color: t.bg,
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
                        ),
                        // Jump-to-latest pill, anchored just above the composer
                        // (bottom of the message area), centred horizontally.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: _scrollDownPill(t),
                        ),
                      ],
                    ),
                  ),

                  // SafeArea keeps the composer clear of the system gesture/nav
                  // bar (it collapses to zero when the keyboard is up). Pushed
                  // chat screens have no bottomNavigationBar to absorb that inset,
                  // unlike the dashboard/settings tabs inside AppShell.
                  SafeArea(
                    top: false,
                    child: Container(
                      color: t.bg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: isWilted
                          ? _buildLockedComposer(t)
                          : _buildComposer(t, contact, maxFormatted),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            if (!isRecordingVoice)
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
              child: isRecordingVoice
                  ? buildRecordingHud(t, l10n)
                  : TextField(
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
            if (!isRecordingVoice && (contact.imagesAllowed ?? true)) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: IconButton(
                  icon: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: t.action,
                    size: 22,
                  ),
                  onPressed: _onImageButton,
                ),
              ),
            ],
            const SizedBox(width: 8),
            if (_charCount == 0)
              // Empty field → hold-to-record mic (tap it for the quality picker).
              buildVoiceButton(t, l10n)
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: AnimatedBuilder(
                  animation: _sendBloom,
                  builder: (context, child) {
                    final v = _sendBloom.value;
                    final scale =
                        1.0 + 0.16 * sin(v * pi); // bloom out and back
                    return Transform.scale(scale: scale, child: child);
                  },
                  // Tap = normal send; long-press = wilting message. InkWell
                  // handles both gestures itself (a tooltip's own long-press
                  // recognizer would otherwise steal it).
                  child: Material(
                    color: t.action,
                    borderRadius: BorderRadius.circular(t.radiusControl),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _handleSend,
                      onLongPress: _handleSendWilting,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.send, color: t.onAction, size: 18),
                      ),
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
            onSendSticker: _handleSendSticker,
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
