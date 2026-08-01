import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/models.dart';
import '../../../../core/state.dart';
import '../../../../core/db/wiltkey_db.dart';
import '../../../../core/theme/wk.dart';
import 'image_viewer.dart';

/// A **fixed-size, lazily-loaded** image thumbnail for the chat.
///
/// Two problems it solves:
///  * **Freeze:** image bodies are no longer decrypted/decoded for every row at
///    page load (see `WiltkeyDatabase._rowToMessage`'s `deferImage`). This widget
///    only fetches its bytes when it actually builds — i.e. when it scrolls into
///    the `ListView.builder`'s viewport — so off-screen images cost nothing.
///  * **Layout pop:** the box is a fixed [width]×[height] and the image is
///    `BoxFit.cover`-cropped into it, so the list never reflows as images decode.
///    The full image is one tap away in the full-screen viewer.
///
/// Decoded bytes are cached back onto the [ChatMessage] so scrolling away and
/// back is instant and the full-screen viewer reuses them.
class ChatImageThumbnail extends StatefulWidget {
  final AppState appState;
  final Contact contact;
  final ChatMessage message;
  final double width;
  final double height;

  const ChatImageThumbnail({
    super.key,
    required this.appState,
    required this.contact,
    required this.message,
    this.width = 232,
    this.height = 260,
  });

  @override
  State<ChatImageThumbnail> createState() => _ChatImageThumbnailState();
}

class _ChatImageThumbnailState extends State<ChatImageThumbnail> {
  Uint8List? _bytes;
  bool _failed = false;

  // Serialize the (main-isolate) decrypt+decode across ALL thumbnails so several
  // images coming into view at once decode one-at-a-time instead of hitching the
  // frame together — the "load them one by one" behaviour. Because the chat is
  // bottom-anchored, the newest on-screen images build (and so enqueue) first.
  static Future<void> _decodeGate = Future.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ChatImageThumbnail old) {
    super.didUpdateWidget(old);
    // A recycled ListView element now showing a different message must reload.
    if (old.message.id != widget.message.id) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    // 1) Already decoded this session (cached on the message) — instant.
    final cached = widget.message.decodedImageBytes;
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    // 2) A non-deferred image (hidden/wilting, revealed) already carries its
    //    decrypted base64 in memory — decode without a DB round-trip. Guard
    //    against an empty/garbage body decoding to zero bytes (which would render
    //    as a broken image); fall through to the durable loader in that case.
    final dt = widget.message.decryptedText;
    if (dt != null && dt.isNotEmpty) {
      try {
        final b = base64Decode(dt);
        if (b.isNotEmpty) {
          widget.message.decodedImageBytes = b;
          if (mounted) setState(() => _bytes = b);
          return;
        }
      } catch (_) {}
    }
    // 3) Deferred plain image — fetch + decrypt + decode lazily, off page-load,
    //    and one at a time (the gate) so a burst of newly-visible images doesn't
    //    decode all on the same frame.
    final completer = Completer<void>();
    final prev = _decodeGate;
    _decodeGate = completer.future;
    try {
      await prev;
      if (!mounted) return;
      final b = await WiltkeyDatabase.instance.loadImageBytes(
        widget.contact.id,
        widget.message.id,
        masterKeyHex: widget.appState.masterKeyHex,
      );
      if (!mounted) return;
      if (b != null) {
        widget.message.decodedImageBytes = b;
        setState(() => _bytes = b);
      } else {
        setState(() => _failed = true);
      }
    } finally {
      completer.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusControl),
        child: _content(context, t),
      ),
    );
  }

  Widget _content(BuildContext context, t) {
    if (_bytes != null) {
      final bytes = _bytes!;
      return GestureDetector(
        onTap: () => ImageViewerScreen.open(
          context,
          imageBytes: bytes,
          // A wilting image is never downloadable, regardless of allowSave.
          allowSave: widget.message.allowSave && !widget.message.ephemeral,
        ),
        child: Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _error(context, t),
        ),
      );
    }
    if (_failed) return _error(context, t);
    // Loading placeholder — same footprint as the final image, so no reflow.
    return Container(
      color: t.surface,
      alignment: Alignment.center,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          valueColor: AlwaysStoppedAnimation<Color>(
            t.action.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _error(BuildContext context, t) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: t.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: t.textTertiary, size: 28),
          const SizedBox(height: 6),
          Text(
            l10n.groupImageFailedToLoad,
            style: t.dataMono.copyWith(color: t.textTertiary, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
