import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/custom_emoji.dart';
import '../../../core/image_utils.dart';
import '../../../core/state.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';

/// Custom emoji creation flow: pick an image, crop it to a square (interactive
/// pan/zoom inside a fixed frame), then name it. The crop is captured directly
/// from the rendered frame via [RepaintBoundary] — no external crop dependency.
///
/// Returns the created [CustomEmoji] via `Navigator.pop` (or null if cancelled).
/// Persistence is handled by the caller through [CustomEmojiStore].
class EmojiCreatorScreen extends StatefulWidget {
  /// Stable chat key (contact/group `keyHash`) the emoji belongs to — used only
  /// to reject duplicate live names. Persistence is the caller's job.
  final String chatKey;
  const EmojiCreatorScreen({super.key, required this.chatKey});

  @override
  State<EmojiCreatorScreen> createState() => _EmojiCreatorScreenState();
}

enum _Stage { pick, crop, name }

class _EmojiCreatorScreenState extends State<EmojiCreatorScreen> {
  // Logical size of the square crop frame; capture is scaled then re-encoded to
  // a small ~150px WebP before storing.
  static const double _cropBox = 280.0;
  static const double _outputPx = 160.0;

  _Stage _stage = _Stage.pick;

  Uint8List? _sourceBytes; // original picked image
  Uint8List? _croppedBytes; // captured + WebP-compressed crop
  final GlobalKey _cropKey = GlobalKey();
  final TextEditingController _nameController = TextEditingController();
  final TransformationController _transformController =
      TransformationController();

  String? _nameError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    XFile? image;
    try {
      AppState().isPickingMedia = true;
      image = await picker.pickImage(source: ImageSource.gallery);
    } finally {
      AppState().isPickingMedia = false;
    }
    if (image == null) {
      if (_sourceBytes == null && mounted) Navigator.pop(context);
      return;
    }
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _sourceBytes = bytes;
      _croppedBytes = null;
      _transformController.value = Matrix4.identity();
      _stage = _Stage.crop;
    });
  }

  Future<void> _confirmCrop() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _busy = false);
        return;
      }
      final ui.Image image = await boundary.toImage(
        pixelRatio: _outputPx / _cropBox,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        setState(() => _busy = false);
        return;
      }
      final webp = await ImageUtils.prepareEmoji(byteData.buffer.asUint8List());
      if (!mounted) return;
      setState(() {
        _croppedBytes = webp;
        _stage = _Stage.name;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final name = _nameController.text.trim().toLowerCase();
    if (!CustomEmoji.isValidName(name)) {
      setState(() => _nameError = 'Use 2-32 chars: a-z, 0-9, _');
      return;
    }
    if (CustomEmojiStore.nameExists(widget.chatKey, name)) {
      setState(() => _nameError = ':$name: already exists in this chat');
      return;
    }
    if (_croppedBytes == null) return;

    final emoji = CustomEmoji(
      name: name,
      imageB64: base64Encode(_croppedBytes!),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    Navigator.pop(context, emoji);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
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
          (_stage == _Stage.name)
              ? (t.uppercaseLabels ? 'NAME EMOJI' : 'Name emoji')
              : (t.uppercaseLabels ? 'CREATE EMOJI' : 'Create emoji'),
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
      ),
      body: SafeArea(child: _buildStage(t)),
    );
  }

  Widget _buildStage(WiltkeyTokens t) {
    switch (_stage) {
      case _Stage.pick:
        return _buildPickStage(t);
      case _Stage.crop:
        return _buildCropStage(t);
      case _Stage.name:
        return _buildNameStage(t);
    }
  }

  Widget _buildPickStage(WiltkeyTokens t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_reaction_outlined, color: t.action, size: 56),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Pick an image to turn into a custom emoji.',
              textAlign: TextAlign.center,
              style: t.bodySecondary.copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Choose image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.onAction,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropStage(WiltkeyTokens t) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text('Pan & zoom to frame the emoji', style: t.bodySecondary),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: t.action.withValues(alpha: 0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radiusControl),
                child: RepaintBoundary(
                  key: _cropKey,
                  child: SizedBox(
                    width: _cropBox,
                    height: _cropBox,
                    child: Container(
                      color: t.surface,
                      child: _sourceBytes == null
                          ? const SizedBox()
                          : InteractiveViewer(
                              transformationController: _transformController,
                              minScale: 0.5,
                              maxScale: 5.0,
                              clipBehavior: Clip.none,
                              child: Image.memory(
                                _sourceBytes!,
                                width: _cropBox,
                                height: _cropBox,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickImage,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Replace'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.action,
                    side: BorderSide(color: t.action),
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _confirmCrop,
                  icon: _busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.onAction,
                          ),
                        )
                      : const Icon(Icons.crop, size: 16),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.action,
                    foregroundColor: t.onAction,
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNameStage(WiltkeyTokens t) {
    final name = _nameController.text.trim().toLowerCase();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.radiusCard),
                border: Border.all(color: t.border),
              ),
              child: Column(
                children: [
                  if (_croppedBytes != null)
                    Image.memory(
                      _croppedBytes!,
                      width: 96,
                      height: 96,
                      gaplessPlayback: true,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    name.isEmpty ? ':your_emoji:' : ':$name:',
                    style: t.dataMono.copyWith(
                      color: t.action,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t.uppercaseLabels ? 'EMOJI NAME' : 'Emoji name',
            style: t.sectionLabel.copyWith(color: t.action),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            autofocus: true,
            onChanged: (_) => setState(() => _nameError = null),
            style: t.body.copyWith(fontSize: 14),
            decoration: InputDecoration(
              prefixText: ':',
              suffixText: ':',
              prefixStyle: t.body.copyWith(color: t.textTertiary, fontSize: 14),
              suffixStyle: t.body.copyWith(color: t.textTertiary, fontSize: 14),
              hintText: 'party_parrot',
              hintStyle: t.body.copyWith(color: t.textTertiary),
              filled: true,
              fillColor: t.surface,
              errorText: _nameError,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.border),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.action),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Type it as :name: in chat to use it. Lowercase letters, numbers, and underscores only.',
            style: t.bodySecondary,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _stage = _Stage.crop),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.action,
                    side: BorderSide(color: t.action),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save emoji'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.action,
                    foregroundColor: t.onAction,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Emojis sync to everyone in this chat and count against its metadata budget.',
            textAlign: TextAlign.center,
            style: t.dataMono.copyWith(
              color: t.warning,
              fontSize: 9,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
