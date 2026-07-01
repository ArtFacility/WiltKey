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
  ui.Image? _sourceImage; // Decoded source image for custom painting
  Uint8List? _croppedBytes; // captured + WebP-compressed crop
  final GlobalKey _cropKey = GlobalKey();
  final TextEditingController _nameController = TextEditingController();
  final TransformationController _transformController =
      TransformationController();

  String? _nameError;
  bool _busy = false;

  // History stack for undo step-by-step
  final List<EditStep> _history = [];
  List<EraseStroke>? _activeStrokes;
  double _brushSize = 15.0;
  bool _isEraseMode = false;
  double? _tempRotation; // Temporary rotation value during slider drag

  // Drives the erase painter to repaint as points are appended mid-stroke,
  // WITHOUT rebuilding the whole crop stage on every pointer move (the source of
  // the drawing lag). Points are mutated in place on the active stroke and this
  // ticker bumps to trigger a paint-only invalidation.
  final ValueNotifier<int> _repaintTick = ValueNotifier<int>(0);

  EditStep get _currentStep => _history.isNotEmpty
      ? _history.last
      : EditStep(rotationRadians: 0.0, strokes: []);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _transformController.dispose();
    _sourceImage?.dispose();
    _repaintTick.dispose();
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

    setState(() => _busy = true);
    ui.Image? decodedImage;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      decodedImage = frame.image;
    } catch (e) {
      debugPrint("Failed to decode image: $e");
    }

    if (!mounted) {
      decodedImage?.dispose();
      return;
    }

    setState(() {
      _sourceBytes = bytes;
      _sourceImage?.dispose();
      _sourceImage = decodedImage;
      _croppedBytes = null;
      _transformController.value = Matrix4.identity();
      _history.clear();
      _history.add(EditStep(rotationRadians: 0.0, strokes: []));
      _isEraseMode = false;
      _tempRotation = null;
      _stage = _Stage.crop;
      _busy = false;
    });
  }

  void _rotateImage() {
    final nextRotation = _currentStep.rotationRadians + (3.141592653589793 / 2);
    final clonedStrokes = _currentStep.strokes.map((s) => s.clone()).toList();
    setState(() {
      _history.add(EditStep(
        rotationRadians: nextRotation,
        strokes: clonedStrokes,
      ));
    });
  }

  void _undo() {
    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _activeStrokes = null; // safety reset
        _tempRotation = null;
      });
    }
  }

  void _onEraseStart(Offset localPos) {
    final newStrokes = _currentStep.strokes.map((s) => s.clone()).toList();
    newStrokes.add(EraseStroke(
      points: [localPos],
      width: _brushSize,
    ));
    setState(() {
      _activeStrokes = newStrokes;
    });
  }

  void _onEraseUpdate(Offset localPos) {
    final active = _activeStrokes;
    if (active == null || active.isEmpty) return;
    // Mutate the live stroke and repaint the painter only — no setState, so the
    // sliders/buttons/InteractiveViewer don't rebuild on every pointer move.
    active.last.points.add(localPos);
    _repaintTick.value++;
  }

  void _onEraseEnd() {
    if (_activeStrokes == null) return;
    setState(() {
      _history.add(EditStep(
        rotationRadians: _currentStep.rotationRadians,
        strokes: _activeStrokes!,
      ));
      _activeStrokes = null;
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
    final currentStrokes = _activeStrokes ?? _currentStep.strokes;
    final canUndo = _history.length > 1;
    final activeRotation = _tempRotation ?? _currentStep.rotationRadians;

    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          _isEraseMode
              ? 'Drag to erase the background'
              : 'Pan & zoom to frame the emoji',
          style: t.bodySecondary,
        ),
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
                child: Stack(
                  children: [
                    // Checkerboard background underneath the repaint boundary
                    Positioned.fill(
                      child: CustomPaint(
                        painter: CheckerboardPainter(
                          colorLight: t.bg,
                          colorDark: t.bgRaised,
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      key: _cropKey,
                      child: SizedBox(
                        width: _cropBox,
                        height: _cropBox,
                        child: Container(
                          color: Colors.transparent,
                          child: _sourceImage == null
                              ? const SizedBox()
                              : InteractiveViewer(
                                  transformationController: _transformController,
                                  minScale: 0.5,
                                  maxScale: 5.0,
                                  clipBehavior: Clip.none,
                                  panEnabled: !_isEraseMode,
                                  scaleEnabled: !_isEraseMode,
                                  child: Transform.rotate(
                                    angle: activeRotation,
                                    child: SizedBox(
                                      width: _cropBox,
                                      height: _cropBox,
                                      child: IgnorePointer(
                                        ignoring: !_isEraseMode,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onPanStart: (details) =>
                                              _onEraseStart(details.localPosition),
                                          onPanUpdate: (details) =>
                                              _onEraseUpdate(details.localPosition),
                                          onPanEnd: (details) => _onEraseEnd(),
                                          child: CustomPaint(
                                            painter: ErasePainter(
                                              image: _sourceImage!,
                                              strokes: currentStrokes,
                                              repaint: _repaintTick,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Edit control panel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Brush size slider (only visible in Erase mode)
              AnimatedOpacity(
                opacity: _isEraseMode ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Visibility(
                  visible: _isEraseMode,
                  maintainState: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.brush, size: 16, color: t.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: t.action,
                              inactiveTrackColor: t.border,
                              thumbColor: t.action,
                              overlayColor: t.action.withValues(alpha: 0.2),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _brushSize,
                              min: 5.0,
                              max: 40.0,
                              onChanged: (val) {
                                setState(() => _brushSize = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_brushSize.round()}px',
                          style: t.dataMono.copyWith(fontSize: 12, color: t.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Rotation slider (visible in both modes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.rotate_left, size: 16, color: t.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: t.action,
                          inactiveTrackColor: t.border,
                          thumbColor: t.action,
                          overlayColor: t.action.withValues(alpha: 0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: (activeRotation * 180 / 3.141592653589793)
                              .clamp(-180.0, 180.0),
                          min: -180.0,
                          max: 180.0,
                          onChanged: (val) {
                            setState(() {
                              _tempRotation = val * 3.141592653589793 / 180.0;
                            });
                          },
                          onChangeEnd: (val) {
                            final finalRad = val * 3.141592653589793 / 180.0;
                            final clonedStrokes =
                                _currentStep.strokes.map((s) => s.clone()).toList();
                            setState(() {
                              _history.add(EditStep(
                                rotationRadians: finalRad,
                                strokes: clonedStrokes,
                              ));
                              _tempRotation = null;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 45,
                      child: Text(
                        '${(activeRotation * 180 / 3.141592653589793).round()}°',
                        style: t.dataMono.copyWith(fontSize: 12, color: t.textSecondary),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
              // Tools row: Mode Toggle (Pan/Zoom vs Erase), Rotate, Undo.
              // A Wrap (not a Row) so the controls flow onto a second line on
              // narrow screens instead of overflowing with a RenderFlex error.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Mode: Pan/Zoom
                  _buildToolButton(
                    icon: Icons.zoom_out_map,
                    label: 'Pan & Zoom',
                    selected: !_isEraseMode,
                    theme: t,
                    onTap: () => setState(() => _isEraseMode = false),
                  ),
                  // Mode: Erase
                  _buildToolButton(
                    icon: Icons.auto_fix_normal,
                    label: 'Erase BG',
                    selected: _isEraseMode,
                    theme: t,
                    onTap: () => setState(() => _isEraseMode = true),
                  ),
                  // Rotate
                  IconButton(
                    onPressed: _rotateImage,
                    icon: Icon(Icons.rotate_right, color: t.action),
                    tooltip: 'Rotate 90°',
                    style: IconButton.styleFrom(
                      backgroundColor: t.bgRaised,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                        side: BorderSide(color: t.border),
                      ),
                    ),
                  ),
                  // Undo
                  IconButton(
                    onPressed: canUndo ? _undo : null,
                    icon: Icon(Icons.undo, color: canUndo ? t.action : t.textTertiary),
                    tooltip: 'Undo',
                    style: IconButton.styleFrom(
                      backgroundColor: t.bgRaised,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                        side: BorderSide(color: t.border),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool selected,
    required WiltkeyTokens theme,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: theme.body.copyWith(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? theme.onAction : theme.textPrimary,
      )),
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? theme.action : theme.bgRaised,
        foregroundColor: selected ? theme.onAction : theme.textSecondary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radiusControl),
          side: BorderSide(
            color: selected ? Colors.transparent : theme.border,
          ),
        ),
      ),
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

class EraseStroke {
  final List<Offset> points;
  final double width;

  EraseStroke({
    required this.points,
    required this.width,
  });

  EraseStroke clone() {
    return EraseStroke(
      points: List<Offset>.from(points),
      width: width,
    );
  }
}

class EditStep {
  final double rotationRadians;
  final List<EraseStroke> strokes;

  EditStep({
    required this.rotationRadians,
    required this.strokes,
  });
}

class ErasePainter extends CustomPainter {
  final ui.Image image;
  final List<EraseStroke> strokes;

  ErasePainter({
    required this.image,
    required this.strokes,
    Listenable? repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.width, size.height),
      image: image,
      fit: BoxFit.contain,
    );

    final erasePaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      erasePaint.strokeWidth = stroke.width;
      final path = Path();
      if (stroke.points.isNotEmpty) {
        path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
      }
      canvas.drawPath(path, erasePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ErasePainter oldDelegate) {
    // Repaints during an active stroke are driven by the [repaint] Listenable
    // (points are mutated in place, so a reference compare would miss them).
    // On a full rebuild we always repaint: the painter only exists while the
    // user is actively cropping/erasing, so the redraw cost is irrelevant and
    // this guarantees committed strokes/rotation are never left stale.
    return true;
  }
}

class CheckerboardPainter extends CustomPainter {
  final Color colorLight;
  final Color colorDark;

  const CheckerboardPainter({
    required this.colorLight,
    required this.colorDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLight = Paint()..color = colorLight;
    final paintDark = Paint()..color = colorDark;
    const double squareSize = 8.0;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isDark = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 1;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isDark ? paintDark : paintLight,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) {
    return oldDelegate.colorLight != colorLight || oldDelegate.colorDark != colorDark;
  }
}
