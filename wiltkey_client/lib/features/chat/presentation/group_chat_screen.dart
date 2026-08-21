import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/payload_limits.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/cosmetics/avatar_border_controller.dart';
import '../../../core/custom_emoji.dart';
import '../../contacts/presentation/contact_request_ui.dart';
import 'widgets/image_source_sheet.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/wiltkey_components.dart';
import 'widgets/compression_dialog.dart';
import 'widgets/emoji_autocomplete_bar.dart';
import 'widgets/mention_autocomplete_bar.dart';
import 'widgets/emoji_picker_panel.dart';
import 'widgets/debug_console_sheet.dart';
import 'widgets/voice_recording_mixin.dart';
import 'widgets/voice_message_player.dart';
import 'widgets/download_bubble.dart';
import 'widgets/reactions.dart';
import 'widgets/image_viewer.dart';
import 'widgets/chat_image_thumbnail.dart';
import 'widgets/group_message_bubble.dart';
import 'widgets/wilt_widgets.dart';
import 'widgets/screenshot_ui.dart';
import 'widgets/wilt_duration_sheet.dart';
import 'widgets/reply_preview.dart';
import 'widgets/swipe_to_reply.dart';
import 'widgets/highlight_flash.dart';
import 'widgets/scroll_to_message.dart';
import '../../groups/presentation/group_settings_screen.dart';
import '../../groups/presentation/group_invite_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, VoiceRecordingMixin {
  final AppState _appState = AppState();

  // Chat opened with — releases [AppState.visibleChatId] on dispose only if a
  // newer chat hasn't taken over.
  String? _openChatId;

  // Voice recording (hold-to-record mic + quality chip + HUD) lives in
  // VoiceRecordingMixin; this screen just wires the hooks below.
  @override
  Contact? get voiceContact => _appState.activeContact;

  @override
  Future<String?> sendVoiceMessage(String base64Payload, String mimeType) =>
      _appState.sendGroupMessage(base64Payload, contentType: 'voice');

  @override
  void onVoiceError(String message) => _errorSnack(message);

  @override
  void onVoiceSent() => _scrollToBottom();

  @override
  void onVoiceRecordingStarted() {
    _hideEmoji();
    _inputFocus.unfocus();
  }

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  int _charCount = 0;
  bool _showEmoji = false;
  bool _loadingOlder = false;
  bool _isAtBottom = true;
  bool _showScrollDownArrow = false;
  final Set<String> _revealedImageIds = {};

  // Quote-tap reveal: rows are keyed by message id so [scrollToMessageInList]
  // can jump to a reply's parent; [_flashMessageId]/[_flashTick] drive the
  // one-shot highlight on the target row.
  final Map<String, GlobalKey> _messageRowKeys = {};
  String? _flashMessageId;
  int _flashTick = 0;
  Timer? _flashTimer;

  // The message the composer is currently replying to (null = normal send).
  ChatMessage? _replyingTo;

  // The message currently being edited (null = normal send).
  ChatMessage? _editingMessage;

  // Wraps the message list so a consented screenshot can render it to an image.
  final GlobalKey _captureBoundaryKey = GlobalKey();

  late final AnimationController _sendBloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

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
        _appState.auditAndSyncGroupLanes(contact);
      }
    }

    initVoiceRecording();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _appState.activeContact;
    if (c != null) _appState.markChatRead(c);
    if (_appState.visibleChatId == _openChatId) _appState.visibleChatId = null;
    _sendBloom.dispose();
    _appState.removeListener(_updateState);
    _appState.screenshotCaptureSignal.removeListener(_onScreenshotCaptureSignal);
    _appState.screenshotDeniedSignal.removeListener(_onScreenshotDeniedSignal);
    _inputFocus.dispose();
    _messageController.removeListener(_updateCharCount);
    _scrollController.removeListener(_scrollListener);
    _messageController.dispose();
    _scrollController.dispose();
    _flashTimer?.cancel();
    disposeVoiceRecording();
    super.dispose();
  }

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

  /// Keep the latest message visible as the soft keyboard animates in/out (see
  /// the matching note in ChatScreen).
  @override
  void didChangeMetrics() {
    if (!_isAtBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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
      // Generous window (~2.5s) so many async image decodes can finish growing
      // the list before we settle — an image-heavy chat opens pinned to the
      // bottom instead of stranding a few screens up.
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

  void _startReply(ChatMessage message) {
    if (message.isSystem ||
        message.isPending ||
        message.wilted ||
        message.contentType == 'screenshot_request' ||
        message.contentType == 'group_nuke_request' ||
        message.contentType == 'refill_request') {
      return;
    }
    setState(() => _replyingTo = message);
    _inputFocus.requestFocus();
  }

  void _cancelReply() {
    if (_replyingTo != null) setState(() => _replyingTo = null);
  }

  bool _canReply(ChatMessage m) =>
      !m.isSystem &&
      !m.isPending &&
      !m.wilted &&
      m.contentType != 'screenshot_request' &&
      m.contentType != 'group_nuke_request' &&
      m.contentType != 'refill_request';

  /// Small left→right nudge (resistance + haptic + spring-back) to reply.
  /// See [SwipeToReply].
  Widget _wrapSwipeToReply(ChatMessage message, Widget child) {
    return SwipeToReply(
      enabled: _canReply(message),
      onReply: () => _startReply(message),
      child: child,
    );
  }

  /// Tapping a quote block scrolls to the quoted parent message and flashes it,
  /// so replies to near-identical messages (e.g. several images) are findable.
  /// The parent is resolved from the loaded window; if it isn't there (scrolled
  /// far out / unloaded), the quote already renders muted + un-tappable, so this
  /// only fires when the target is actually reachable.
  Future<void> _revealQuotedMessage(String? parentId) async {
    final contact = _appState.activeContact;
    if (contact == null || parentId == null) return;
    final list = _visibleMessages(contact);
    if (!list.any((m) => m.id == parentId)) return;
    await scrollToMessageInList(
      controller: _scrollController,
      messages: list,
      targetId: parentId,
      rowKeys: _messageRowKeys,
    );
    if (!mounted) return;
    _flashTimer?.cancel();
    setState(() {
      _flashMessageId = parentId;
      _flashTick++;
    });
    _flashTimer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _flashMessageId = null);
    });
  }

  void _startEditing(ChatMessage message) {
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
      _messageController.text = message.decryptedText ?? message.text;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });
    _inputFocus.requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  Future<void> _confirmDeleteMessage(ChatMessage message) async {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: t.danger, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.chatDeleteTitle,
                style: t.screenTitle.copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.chatDeleteBody,
          style: t.bodySecondary.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.commonCancel,
              style: t.body.copyWith(color: t.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.chatDeleteConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final contact = _appState.activeContact;
      if (contact != null) {
        final error = await _appState.deleteMessage(contact, message);
        if (error != null && mounted) _errorSnack(error);
      }
    }
  }

  void _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessage != null) {
      final editing = _editingMessage!;
      final contact = _appState.activeContact;
      _cancelEditing();
      if (contact != null) {
        final error = await _appState.editMessage(contact, editing, text);
        if (error != null && mounted) {
          _errorSnack(error);
          _messageController.text = text;
        }
      }
      return;
    }

    _sendBloom.forward(from: 0);

    // Clear the field instantly — the bubble shows immediately as a pending
    // "Encrypting…" placeholder while the send completes in the background.
    final replyId = _replyingTo?.id;
    _messageController.clear();
    _cancelReply();
    _scrollToBottom();

    final error = await _appState.sendGroupMessage(text, replyToId: replyId);
    if (error != null) {
      _appState.log('[GroupChat] Send failed: $error');
      if (mounted) {
        _errorSnack(error);
        // A pre-flight failure leaves no bubble — restore the draft.
        _messageController.text = text;
      }
    }
  }

  /// Long-press on the send button → compose a wilting (disappearing) group
  /// message. Backing out sends nothing (a normal message still goes on a tap).
  void _handleSendWilting() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final secs = await showWiltDurationSheet(context);
    if (secs == null || !mounted) return;
    _sendBloom.forward(from: 0);
    final replyId = _replyingTo?.id;
    _messageController.clear();
    _cancelReply();
    _scrollToBottom();
    final error = await _appState.sendGroupMessage(
      text,
      ephemeral: true,
      ttlSeconds: secs,
      replyToId: replyId,
    );
    if (error != null) {
      _appState.log('[GroupChat] Wilting send failed: $error');
      if (mounted) {
        _errorSnack(error);
        _messageController.text = text;
      }
    }
  }

  /// Long-press on a picker emoji → send it as a sticker (big, bubble-less).
  /// Rides the normal group-message path with a sentinel marker.
  void _handleSendSticker(String payload) async {
    _sendBloom.forward(from: 0);
    _scrollToBottom();
    final error = await _appState.sendGroupMessage(wrapSticker(payload));
    if (error != null) {
      _appState.log('[GroupChat] Sticker send failed: $error');
      if (mounted) _errorSnack(error);
    }
  }

  /// Tapping the group image button: choose camera vs gallery, then send.
  Future<void> _onGroupImageButton(Contact contact) async {
    final src = await showImageSourceSheet(context);
    if (src == null || !mounted) return;
    await _pickAndSendGroupImage(contact, src);
  }

  Future<void> _pickAndSendGroupImage(
    Contact contact,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
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
    // Dialog compresses live + returns the exact bytes — no recompress here.
    final CompressionResult? choice = await CompressionDialog.show(
      context,
      originalBytes,
    );
    if (choice == null) return;

    final base64Data = base64Encode(choice.bytes);
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
    if (WkPayloadLimits.exceedsOutgoing(base64Data.length)) {
      _errorSnack(
        WkPayloadLimits.blockedByFreeTier(base64Data.length)
            ? l10n.chatImageNeedsPlusSnackBar
            : l10n.chatImageExceedsMaxSizeSnackBar,
      );
      return;
    }

    final ct = choice.hidden ? 'image_hidden' : 'image';
    final error = await _appState.sendGroupMessage(
      base64Data,
      contentType: ct,
      allowSave: choice.allowSave,
      ephemeral: choice.ephemeral,
      ttlSeconds: choice.ttlSeconds,
    );
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

    // Group Time Wilt: swap the byte budget for a lifetime. The host is
    // "infinite" (renders ∞, greys only once every member wilts = the group
    // archives); a member shows its own countdown and wilts on its own expiry.
    final bool isTw = contact.isTimeWilt;
    final bool isTwHost = contact.isTimeWiltGroupHost;
    final bool twWilted = isTw &&
        (contact.isArchived ||
            (!isTwHost && contact.timeWiltRemainingFraction <= 0));
    final double twFraction = isTwHost ? 1.0 : contact.timeWiltRemainingFraction;
    final String twLabel = isTwHost
        ? l10n.groupTimeWiltHostInfinite
        : contact.timeWiltCountdownLabel;

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
                    onTap: () => _openGroupDetails(contact),
                    child: Row(
                      children: [
                        PixelArtAvatar(
                          hexString:
                              (contact.groupIconHex != null &&
                                  contact.groupIconHex!.isNotEmpty)
                              ? contact.groupIconHex!
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
                    ourFraction: isTw ? twFraction : currentPercent,
                    isWilted: isTw ? twWilted : isWilted,
                    variant: BudgetIndicatorVariant.chatHeader,
                    semanticLabel: isTw
                        ? twLabel
                        : l10n.chatRemainingLabel(
                            AppState.formatBytes(remainingBytesNow),
                          ),
                  ),
                ],
              ),
              actions: [
                // Group members stays inline (primary nav); screenshot + debug
                // move into the overflow menu to keep the header uncluttered.
                IconButton(
                  icon: Icon(Icons.hub_outlined, color: t.identity, size: 20),
                  tooltip: 'Group members',
                  onPressed: () => _showMembersSheet(contact),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: t.action, size: 20),
                  color: t.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusControl),
                    side: BorderSide(color: t.border, width: t.borderWidth),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'screenshot':
                        _requestScreenshot(contact);
                      case 'debug':
                        DebugConsoleSheet.show(context, _appState);
                    }
                  },
                  itemBuilder: (context) => [
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
                    // Time Wilt has no per-member byte gauges — just the lifetime
                    // countdown (host = ∞). Feeding the theme's decorative "detail"
                    // gauge into this 22px strip made the bespoke themes (garden
                    // flower, paperink ink-ring, etc.) blow up over the screen; the
                    // small trailing header gauge already carries the fraction.
                    child: isTw
                        ? Row(
                            children: [
                              Icon(
                                isTwHost
                                    ? Icons.all_inclusive
                                    : Icons.hourglass_bottom,
                                size: 13,
                                color: twWilted ? t.budgetWilted : t.action,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                twLabel,
                                style: t.dataMono.copyWith(
                                  color: twWilted ? t.budgetWilted : t.action,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: memberList.isNotEmpty
                                    ? context.wkc.groupBudgetIndicator(
                                        members: _memberBudgets(
                                          shownHeaderMembers,
                                        ),
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
                  if (isWilted && !isTw)
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
                                  ? l10n.chatLockedLabel.toUpperCase()
                                  : l10n.chatLockedLabel,
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

                        if (message.contentType == 'screenshot_request') {
                          return _buildScreenshotRequest(t, contact, message);
                        }

                        if (message.contentType == 'group_nuke_request') {
                          return _buildGroupNukeRequest(t, contact, message);
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
                                borderRadius: BorderRadius.circular(
                                  t.radiusPill,
                                ),
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

                        final Widget row = GroupMessageBubble(
                          message: message,
                          displayText: displayText,
                          group: contact,
                          appState: _appState,
                          isMe: isMe,
                          isFirstInBatch: isFirstInBatch,
                          emojiMap: emojiMap,
                          onQuoteTap: message.replyToId == null
                              ? null
                              : () =>
                                    _revealQuotedMessage(message.replyToId),
                          onFailedTap: null,
                          onMemberTap: _promptAddContactFor,
                          revealedImageIds: _revealedImageIds,
                          onRevealImage: (msgId) =>
                              setState(() => _revealedImageIds.add(msgId)),
                          onEdit: _startEditing,
                          onDelete: _confirmDeleteMessage,
                        );
                        final Widget swipeRow =
                            _wrapSwipeToReply(message, row);
                        return KeyedSubtree(
                          key: _messageRowKeys.putIfAbsent(
                            message.id,
                            GlobalKey.new,
                          ),
                          child: HighlightFlash(
                            active: message.id == _flashMessageId,
                            tick: _flashTick,
                            color: t.action,
                            child: swipeRow,
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
                      child: (contact.groupRechargePending && !contact.isHost)
                          ? _buildRechargeNeededComposer(t)
                          : twWilted
                          ? (contact.isHost
                                ? _buildTimeWiltHostWiltedComposer(t)
                                : _buildTimeWiltRenewComposer(t))
                          : (isWilted && !isTw)
                          ? (!contact.isHost
                                ? _buildRefillComposer(t, contact)
                                : _buildLockedComposer(t))
                          : _buildComposer(t, contact),
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

  /// In-history screenshot-request voting card for a group. Mirrors the 1-on-1
  /// [MessageBubble] card so recipients see an Allow/Deny prompt (majority rules,
  /// tallied by the requester) instead of the raw control JSON as a chat bubble.
  Widget _buildScreenshotRequest(
    WiltkeyTokens t,
    Contact contact,
    ChatMessage message,
  ) {
    final l10n = AppLocalizations.of(context)!;
    Map<String, dynamic> p = {};
    try {
      p = jsonDecode(message.text) as Map<String, dynamic>;
    } catch (_) {}
    final rawName = (p['requester_name'] as String?)?.trim();
    final name = (rawName == null || rawName.isEmpty) ? contact.name : rawName;
    final status = message.wilted
        ? 'expired'
        : (p['status'] as String? ?? 'pending');

    // Resolved / expired → a compact muted status row.
    if (status != 'pending') {
      late final IconData icon;
      late final String label;
      late final Color color;
      switch (status) {
        case 'accepted':
          icon = Icons.check_circle_outline;
          color = t.action;
          label = l10n.screenshotRequestAllowed;
          break;
        case 'declined':
          icon = Icons.cancel_outlined;
          color = t.textTertiary;
          label = l10n.screenshotRequestDeclined;
          break;
        default: // expired
          icon = Icons.timer_off_outlined;
          color = t.textTertiary;
          label = l10n.screenshotRequestExpired;
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 16, top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: t.dataMono.copyWith(fontSize: 11.5, color: color),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.action.withValues(alpha: 0.06),
        border: Border.all(color: t.action.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.screenshot_monitor_outlined, size: 16, color: t.action),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.screenshotRequestInline(name),
                  style: t.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (message.openedAt != null && message.expiresAt != null) ...[
            const SizedBox(height: 7),
            WiltCountdownBar(
              openedAt: message.openedAt!,
              expiresAt: message.expiresAt!,
              color: t.action,
            ),
          ],
          const SizedBox(height: 9),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () =>
                    _appState.respondToScreenshotCard(contact, message, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.textSecondary,
                  side: BorderSide(color: t.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                ),
                child: Text(l10n.pairRequestReject),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () =>
                    _appState.respondToScreenshotCard(contact, message, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.action,
                  foregroundColor: t.onAction,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                ),
                child: Text(l10n.pairRequestAccept),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// In-chat voting card for a "destroy this group for everyone" proposal.
  /// Danger-styled; a majority of the other members must Agree for the wipe.
  Widget _buildGroupNukeRequest(
    WiltkeyTokens t,
    Contact contact,
    ChatMessage message,
  ) {
    final l10n = AppLocalizations.of(context)!;
    Map<String, dynamic> p = {};
    try {
      p = jsonDecode(message.text) as Map<String, dynamic>;
    } catch (_) {}
    final rawName = (p['requester_name'] as String?)?.trim();
    final name = (rawName == null || rawName.isEmpty) ? contact.name : rawName;
    final status = message.wilted
        ? 'expired'
        : (p['status'] as String? ?? 'pending');

    if (status != 'pending') {
      late final IconData icon;
      late final String label;
      late final Color color;
      switch (status) {
        case 'accepted':
          icon = Icons.check_circle_outline;
          color = t.danger;
          label = l10n.groupNukeVoteAllow;
          break;
        case 'declined':
          icon = Icons.shield_outlined;
          color = t.textTertiary;
          label = l10n.groupNukeVoteDeny;
          break;
        default: // expired
          icon = Icons.timer_off_outlined;
          color = t.textTertiary;
          label = l10n.screenshotRequestExpired;
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 16, top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: t.dataMono.copyWith(fontSize: 11.5, color: color),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.06),
        border: Border.all(color: t.danger.withValues(alpha: 0.4), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: t.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.groupNukeVoteTitle,
                  style: t.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.groupNukeVoteBody,
            style: t.bodySecondary.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            '— $name',
            style: t.dataMono.copyWith(fontSize: 10.5, color: t.textTertiary),
          ),
          if (message.openedAt != null && message.expiresAt != null) ...[
            const SizedBox(height: 7),
            WiltCountdownBar(
              openedAt: message.openedAt!,
              expiresAt: message.expiresAt!,
              color: t.danger,
            ),
          ],
          const SizedBox(height: 9),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () =>
                    _appState.respondToGroupNukeCard(contact, message, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.textSecondary,
                  side: BorderSide(color: t.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                ),
                child: Text(l10n.groupNukeVoteDeny),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () =>
                    _appState.respondToGroupNukeCard(contact, message, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.danger,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                ),
                child: Text(l10n.groupNukeVoteAllow),
              ),
            ],
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

  /// Shown to a member whose group the host recharged: sending is impossible
  /// (their seed/lane is dead), so the composer becomes a "meet the host again"
  /// prompt instead of the byte-depleted refill composer.
  Widget _buildRechargeNeededComposer(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.action.withValues(alpha: 0.06),
        border: Border.all(color: t.action.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.autorenew, size: 16, color: t.action),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              t.uppercaseLabels
                  ? l10n.groupRechargeNeededComposer.toUpperCase()
                  : l10n.groupRechargeNeededComposer,
              textAlign: TextAlign.center,
              style: t.dataMono.copyWith(color: t.action, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Time Wilt group member whose clock ran out: read-only until they meet the
  /// host again to renew their access.
  Widget _buildTimeWiltRenewComposer(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.budgetWilted.withValues(alpha: 0.06),
        border: Border.all(
          color: t.budgetWilted.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_bottom, size: 16, color: t.budgetWilted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              t.uppercaseLabels
                  ? l10n.groupTimeWiltRenewComposer.toUpperCase()
                  : l10n.groupTimeWiltRenewComposer,
              textAlign: TextAlign.center,
              style: t.dataMono.copyWith(
                color: t.budgetWilted,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Time Wilt group host once every member has wilted (the group archived):
  /// read-only until the host meets someone again, which revives the group.
  Widget _buildTimeWiltHostWiltedComposer(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.action.withValues(alpha: 0.06),
        border: Border.all(color: t.action.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined, size: 16, color: t.action),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              t.uppercaseLabels
                  ? l10n.groupTimeWiltHostAllWilted.toUpperCase()
                  : l10n.groupTimeWiltHostAllWilted,
              textAlign: TextAlign.center,
              style: t.dataMono.copyWith(color: t.action, letterSpacing: 0.4),
            ),
          ),
        ],
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
        if (_editingMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.radiusCard),
              border: Border.all(color: t.action.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 16, color: t.action),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.chatEditingBanner,
                        style: t.badgeLabel.copyWith(
                          color: t.action,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _editingMessage!.decryptedText ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySecondary.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: t.textTertiary,
                  onPressed: _cancelEditing,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  tooltip: l10n.chatCancelEdit,
                ),
              ],
            ),
          ),
        if (_replyingTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ReplyQuote(
              author: replyAuthorName(_replyingTo!, contact, _appState, l10n),
              preview: replyPreviewText(_replyingTo!, l10n),
              onClose: _cancelReply,
            ),
          ),
        MentionAutocompleteBar(
          controller: _messageController,
          candidates: _getMentionCandidates(contact),
        ),
        EmojiAutocompleteBar(
          controller: _messageController,
          emojiMap: CustomEmojiStore.cachedMap(contact.keyHash),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isRecordingVoice)
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
                  onPressed: () => _onGroupImageButton(contact),
                ),
              ),
            ],
            const SizedBox(width: 8),
            if (_charCount == 0 || isRecordingVoice)
              // Empty field or recording → hold-to-record mic / locked send button.
              buildVoiceButton(t, l10n)
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: AnimatedBuilder(
                  animation: _sendBloom,
                  builder: (context, child) {
                    final scale = 1.0 + 0.16 * sin(_sendBloom.value * pi);
                    return Transform.scale(scale: scale, child: child);
                  },
                  // Tap = normal send; long-press = wilting message. InkWell
                  // handles both natively (a tooltip's long-press would steal it).
                  child: Material(
                    color: overSize ? t.textTertiary : t.action,
                    borderRadius: BorderRadius.circular(t.radiusControl),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: overSize ? null : _handleSend,
                      onLongPress: overSize ? null : _handleSendWilting,
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
        // Time Wilt groups have no byte budget ("unlimited") — the lifetime lives
        // in the header/dashboard, so the composer only shows an over-size warning.
        if (!contact.isTimeWilt)
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
          )
        else if (overSize)
          Text(
            l10n.groupExceedsSizeLimit(contact.maxMessageSize!),
            style: t.dataMono.copyWith(color: t.danger),
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
                // Free the lane + drop from the delivery roster, but keep the
                // member's profile so old history still attributes to them
                // (they can only return via a fresh invite). See kickMember.
                _appState.kickMember(contact, memberKeyHash);
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
                    // Per-member byte gauges are meaningless for a Time Wilt group
                    // (unbounded budget), so the members sheet skips them there.
                    if (memberList.isNotEmpty && !contact.isTimeWilt)
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
                    // Host-only "recharge": start a fresh secure enclave when the
                    // group's budget is spent. Everyone keeps their history but
                    // must meet the host again to rejoin.
                    if (contact.isHost)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _confirmRechargeGroup(contact);
                          },
                          icon: const Icon(Icons.autorenew, size: 16),
                          label: Text(l10n.groupRechargeButton),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: t.action,
                            side: BorderSide(color: t.action, width: 1),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                t.radiusControl,
                              ),
                            ),
                          ),
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

  /// Confirm + run a host recharge (see [AppState.rechargeGroup]). Warns that
  /// every member must be re-met before the group is usable again.
  void _confirmRechargeGroup(Contact contact) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.action, width: 1.5),
        ),
        title: Text(
          t.uppercaseLabels
              ? l10n.groupRechargeTitle.toUpperCase()
              : l10n.groupRechargeTitle,
          style: t.screenTitle.copyWith(color: t.action, fontSize: 16),
        ),
        content: Text(l10n.groupRechargeBody, style: t.bodySecondary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: t.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dctx);
              await _appState.rechargeGroup(contact);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.groupRechargeDone),
                    backgroundColor: t.action,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.onAction,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
            child: Text(l10n.groupRechargeConfirm),
          ),
        ],
      ),
    );
  }

  /// Time Wilt roster readout for one member row: the host is ∞ (infinite);
  /// everyone else shows a compact countdown — our own row from our
  /// authoritative local clock ([Contact.wiltExpiresAt]), other members from the
  /// host-broadcast per-member expiry ([m]['twExpiresAt']). A null clock (an
  /// older host that never broadcast one) falls back to a neutral hourglass.
  Widget _twMemberTimeReadout(
    WiltkeyTokens t,
    AppLocalizations l10n,
    Contact contact,
    Map<String, dynamic> m,
    bool isSelf,
    bool isMemberHost,
  ) {
    if (isMemberHost) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.all_inclusive, size: 15, color: t.action),
          const SizedBox(width: 5),
          Text(
            l10n.groupTimeWiltHostInfinite,
            style: t.dataMono.copyWith(
              color: t.action,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    final String? iso = isSelf
        ? contact.wiltExpiresAt?.toIso8601String()
        : m['twExpiresAt'] as String?;
    final DateTime? expiry = iso != null ? DateTime.tryParse(iso) : null;
    if (expiry == null) {
      return Icon(Icons.hourglass_empty, size: 15, color: t.textTertiary);
    }
    final bool wilted = !expiry.isAfter(DateTime.now());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          wilted ? Icons.hourglass_disabled : Icons.hourglass_bottom,
          size: 15,
          color: wilted ? t.budgetWilted : t.action,
        ),
        const SizedBox(width: 5),
        Text(
          Contact.formatWiltCountdown(expiry),
          style: t.dataMono.copyWith(
            color: wilted ? t.budgetWilted : t.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
    final bool isSelf = m['isSelf'] ?? false;
    final bool isMemberHost = m['isHost'] ?? false;
    // Profile kept for attribution but no active lane (never joined this seed,
    // or awaiting a re-meet after the host recharged). Rendered greyed with an
    // Invite (re-meet) affordance rather than a byte readout.
    final bool notYetMet = m['notYetMet'] == true;
    final bool wilted = !notYetMet && remaining <= 0;

    final String? cachedImage =
        _appState.groupProfilesCache[contact.id]?[keyHash]?['profile_image'];
    final String avatarHex = isSelf
        ? (_appState.profileImageB64.isNotEmpty
              ? _appState.profileImageB64
              : PixelArtAvatar.generateIdenticon(_appState.userId))
        : (cachedImage != null && cachedImage.isNotEmpty
              ? cachedImage
              : PixelArtAvatar.generateIdenticon(keyHash));
    final String? avatarBorderId = isSelf
        ? AvatarBorderController.instance.borderId
        : _appState.groupProfilesCache[contact.id]?[keyHash]?['avatar_border'];

    // Tapping a member row offers to add them as a contact. The request is sent
    // directly to that one member over the AES meta channel — it is NOT fanned
    // to the rest of the group. Requires a direct 1:1 chat for the in-chat card.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isSelf
          ? null
          : () => _promptAddContactFor(keyHash, name),
      child: Container(
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
              PixelArtAvatar(
                hexString: avatarHex,
                size: 40,
                borderId: avatarBorderId,
              ),
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
              if (notYetMet)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_off_outlined,
                        size: 15,
                        color: t.textTertiary,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          t.uppercaseLabels
                              ? l10n.groupNotYetMet.toUpperCase()
                              : l10n.groupNotYetMet,
                          style: t.dataMono.copyWith(
                            color: t.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              // Time Wilt groups show a per-member countdown instead of a byte
              // budget: the host is ∞, our own row reads our authoritative local
              // clock, and other members read the host-broadcast expiry.
              else if (contact.isTimeWilt)
                _twMemberTimeReadout(t, l10n, contact, m, isSelf, isMemberHost)
              else ...[
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
            ],
          ),
          if (!isSelf) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // A not-yet-met member (post-recharge or never joined this seed)
                // has no lane to sync from — the host's lead action is to Invite
                // them back in person (the existing group-invite flow re-meets
                // them: fresh slot on the current seed, history preserved).
                if (notYetMet && contact.isHost)
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
                      icon: const Icon(Icons.person_add_alt, size: 16),
                      label: Text(l10n.groupInviteMember),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.identity,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(t.radiusControl),
                        ),
                      ),
                    ),
                  )
                else if (!notYetMet)
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
      ),
    );
  }

  /// Tapping a member row offers to add them as a contact. The request is sent
  /// directly to that one member over the AES meta channel (never fanned to the
  /// rest of the group). If a direct 1:1 chat with them already exists, the sent
  /// card lands in that chat; otherwise the request still goes out but has no
  /// in-chat card on this side.
  void _promptAddContactFor(String keyHash, String name) {
    Contact? direct;
    for (final c in _appState.contacts) {
      if (!c.isGroup && c.keyHash == keyHash) {
        direct = c;
        break;
      }
    }
    showAddContactFlow(
      context,
      appState: _appState,
      keyHash: keyHash,
      name: name,
      chatContact: direct,
    );
  }

  List<GroupMentionCandidate> _getMentionCandidates(Contact contact) {
    final list = <GroupMentionCandidate>[];
    final cached = _appState.groupProfilesCache[contact.id] ?? {};

    for (final entry in cached.entries) {
      final keyHash = entry.key;
      final p = entry.value;
      final name = p['name'] ?? '';
      if (name.isEmpty && keyHash == _appState.userId) continue;
      final shortCode = p['short_nick'] ??
          GroupMentionCandidate.deriveShortCode(name, keyHash);
      final isSelf = keyHash == _appState.userId;
      list.add(
        GroupMentionCandidate(
          keyHash: keyHash,
          name: isSelf
              ? '${_appState.effectiveDeviceName} (You)'
              : (name.isNotEmpty ? name : shortCode),
          shortCode: isSelf ? _appState.effectiveShortNick : shortCode,
          profileImage: isSelf
              ? _appState.profileImageB64
              : (p['profile_image'] ?? ''),
          avatarBorderId: isSelf
              ? AvatarBorderController.instance.borderId
              : p['avatar_border'],
          isMe: isSelf,
        ),
      );
    }

    if (contact.isHost) {
      if (!list.any((c) => c.keyHash == _appState.userId)) {
        list.add(
          GroupMentionCandidate(
            keyHash: _appState.userId,
            name: '${_appState.effectiveDeviceName} (Host/You)',
            shortCode: _appState.effectiveShortNick,
            profileImage: _appState.profileImageB64,
            avatarBorderId: AvatarBorderController.instance.borderId,
            isMe: true,
          ),
        );
      }
    } else if (contact.hostKeyHash != null) {
      if (!list.any((c) => c.keyHash == contact.hostKeyHash)) {
        final hostName = contact.hostName ?? 'Host';
        final hostShort = GroupMentionCandidate.deriveShortCode(
          hostName,
          contact.hostKeyHash!,
        );
        list.add(
          GroupMentionCandidate(
            keyHash: contact.hostKeyHash!,
            name: '$hostName (Host)',
            shortCode: hostShort,
          ),
        );
      }
    }
    return list;
  }
}


