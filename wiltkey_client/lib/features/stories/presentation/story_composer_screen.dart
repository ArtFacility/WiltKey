import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wiltkey_client/core/persistence.dart';
import 'package:wiltkey_client/core/pixel_art_avatar.dart';
import 'package:wiltkey_client/core/pixel_art_editor.dart';
import 'package:wiltkey_client/core/pixel_palette.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/stories/story_model.dart';
import 'package:wiltkey_client/core/theme/theme_controller.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import 'widgets/themed_story_text_tag.dart';

/// A single freehand drawing stroke with color, width, and points.
class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  DrawingStroke clone() {
    return DrawingStroke(
      points: List<Offset>.from(points),
      color: color,
      strokeWidth: strokeWidth,
    );
  }
}

/// Custom painter for rendering freehand drawing strokes on top of the story canvas.
class StoryDrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? activeStroke;

  StoryDrawingPainter({required this.strokes, this.activeStroke});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _drawStroke(canvas, s);
    }
    if (activeStroke != null) {
      _drawStroke(canvas, activeStroke!);
    }
  }

  void _drawStroke(Canvas canvas, DrawingStroke s) {
    if (s.points.isEmpty) return;
    final paint = Paint()
      ..color = s.color
      ..strokeWidth = s.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (s.points.length == 1) {
      canvas.drawCircle(s.points.first, s.strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(s.points.first.dx, s.points.first.dy);
    for (int i = 1; i < s.points.length; i++) {
      path.lineTo(s.points[i].dx, s.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StoryDrawingPainter oldDelegate) => true;
}

/// A draggable, customizable text tag placed directly onto a photo or pixel art story.
class StoryTextTag {
  final String id;
  String text;
  Offset normalizedPos; // (0.0 to 1.0)
  String borderStyleId; // See StoryTextStyles
  Color textColor;
  double fontSize;
  final TextEditingController textController;
  final FocusNode focusNode;

  StoryTextTag({
    required this.id,
    required this.text,
    this.normalizedPos = const Offset(0.3, 0.45),
    this.borderStyleId = StoryTextStyles.cyberpunk,
    this.textColor = Colors.white,
    this.fontSize = 18.0,
  })  : textController = TextEditingController(text: text),
        focusNode = FocusNode();

  void dispose() {
    textController.dispose();
    focusNode.dispose();
  }
}

/// Full-screen Story Composer Studio with vertical 9:16 ratio, movable in-place text placers,
/// rich themed text backgrounds, freehand brush with palette packs, and WebP flattening.
class StoryComposerScreen extends StatefulWidget {
  final String initialMode; // 'photo', 'pixel_art', 'text'
  final Uint8List? initialPhotoBytes;
  final String? initialPixelArtHex;

  const StoryComposerScreen({
    super.key,
    this.initialMode = 'photo',
    this.initialPhotoBytes,
    this.initialPixelArtHex,
  });

  static Future<void> open(
    BuildContext context, {
    String initialMode = 'photo',
    Uint8List? initialPhotoBytes,
    String? initialPixelArtHex,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StoryComposerScreen(
          initialMode: initialMode,
          initialPhotoBytes: initialPhotoBytes,
          initialPixelArtHex: initialPixelArtHex,
        ),
      ),
    );
  }

  @override
  State<StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends State<StoryComposerScreen> {
  final AppState _appState = AppState();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _canvasKey = GlobalKey();
  final TextEditingController _mainTextController = TextEditingController();

  late String _mode;
  Uint8List? _photoBytes;
  String _pixelArtHex = '';
  int _rotationSteps = 0; // 0, 1, 2, 3 -> (steps * pi / 2)

  // Drawing Brush State
  bool _isDrawingMode = false;
  late WkPaletteSet _currentBrushSet;
  late Color _selectedBrushColor;
  double _selectedBrushSize = 5.0;
  final List<DrawingStroke> _strokes = [];
  DrawingStroke? _activeStroke;

  // Text Tags State & In-Place Selection
  final List<StoryTextTag> _textTags = [];
  String? _selectedTagId;
  bool _isPublishing = false;
  bool _isExporting = false;
  String? _errorMessage;

  // Text Backdrop styles
  int _textBackdropIndex = 0;
  static const List<List<Color>> _backdropGradients = [
    [Color(0xFF0A0F1D), Color(0xFF020617)], // Cyber Dark
    [Color(0xFF002B1B), Color(0xFF00110A)], // Matrix Emerald
    [Color(0xFF2E001F), Color(0xFF13000C)], // Cyber Magenta
    [Color(0xFF261800), Color(0xFF100A00)], // Amber Phosphor
    [Color(0xFF2D0505), Color(0xFF100101)], // Crimson Blood
  ];

  StoryTextTag? get _selectedTag {
    if (_selectedTagId == null) return null;
    for (final tag in _textTags) {
      if (tag.id == _selectedTagId) return tag;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _photoBytes = widget.initialPhotoBytes;
    _pixelArtHex = widget.initialPixelArtHex ?? '';
    _appState.refreshSocialBudget();

    // Default to Saturated (if unlocked) or Classic/Pastel
    _currentBrushSet = WkPalette.sets.firstWhere(
      (s) => s.id == 'saturated' && WkPalette.canAuthor(s),
      orElse: () => WkPalette.sets.firstWhere(
        (s) => s.id == 'classic',
        orElse: () => WkPalette.sets.first,
      ),
    );
    _selectedBrushColor = WkPalette.colorAt(_currentBrushSet.start);

    if (_photoBytes == null && _mode == 'photo') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickPhoto(ImageSource.gallery);
      });
    }
  }

  @override
  void dispose() {
    _mainTextController.dispose();
    for (final tag in _textTags) {
      tag.dispose();
    }
    super.dispose();
  }

  void _rotate90() {
    HapticFeedback.selectionClick();
    setState(() {
      _rotationSteps = (_rotationSteps + 1) % 4;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1400, maxHeight: 2000);
      if (file == null) return;

      final rawBytes = await file.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        format: CompressFormat.webp,
        quality: 85,
      );

      setState(() {
        _photoBytes = Uint8List.fromList(compressed);
        _mode = 'photo';
        _rotationSteps = 0;
        _deselectActiveTag();
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load photo: $e');
    }
  }

  Future<void> _openPixelArtPicker() async {
    final templates = await WiltkeyPersistence().loadAvatarTemplates();
    if (!mounted) return;
    final t = context.wk;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Choose Pixel Art', style: t.screenTitle.copyWith(fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.draw, color: t.action),
                  title: Text('Draw New Pixel Art', style: t.body),
                  tileColor: t.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusControl),
                    side: BorderSide(color: t.border),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final result = await showPixelArtEditor(
                      context,
                      initialHex: _pixelArtHex.isNotEmpty ? _pixelArtHex : PixelGrid.blank,
                      title: 'Draw Story Pixel Art',
                    );
                    if (result != null && result.isNotEmpty) {
                      setState(() {
                        _pixelArtHex = result;
                        _mode = 'pixel_art';
                        _rotationSteps = 0;
                        _deselectActiveTag();
                      });
                    }
                  },
                ),
                if (templates.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Saved Avatar Templates', style: t.sectionLabel.copyWith(fontSize: 11)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: templates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (ctx, i) {
                        final hexStr = templates[i];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _pixelArtHex = hexStr;
                              _mode = 'pixel_art';
                              _rotationSteps = 0;
                              _deselectActiveTag();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: t.bg,
                              borderRadius: BorderRadius.circular(t.radiusControl),
                              border: Border.all(color: t.border),
                            ),
                            child: PixelArtAvatar(hexString: hexStr, size: 68),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Adds a new text tag onto the canvas and immediately focuses it for editing.
  void _addNewTextTag() {
    HapticFeedback.lightImpact();
    final newTag = StoryTextTag(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: '',
      normalizedPos: Offset(0.25 + (_textTags.length * 0.05), 0.35 + (_textTags.length * 0.06)),
      borderStyleId: StoryTextStyles.cyberpunk,
      textColor: Colors.white,
      fontSize: 18.0,
    );

    setState(() {
      _textTags.add(newTag);
      _selectedTagId = newTag.id;
      _isDrawingMode = false; // Auto-deselect drawing mode!
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) newTag.focusNode.requestFocus();
    });
  }

  void _selectTag(StoryTextTag tag) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTagId = tag.id;
      _isDrawingMode = false; // Auto-deselect drawing mode!
    });
    tag.focusNode.requestFocus();
  }

  void _deselectActiveTag() {
    if (_selectedTagId != null) {
      _selectedTag?.focusNode.unfocus();
      setState(() => _selectedTagId = null);
    }
  }

  void _deleteTag(String tagId) {
    HapticFeedback.mediumImpact();
    setState(() {
      final idx = _textTags.indexWhere((t) => t.id == tagId);
      if (idx != -1) {
        _textTags[idx].dispose();
        _textTags.removeAt(idx);
      }
      if (_selectedTagId == tagId) {
        _selectedTagId = null;
      }
    });
  }

  void _undoStroke() {
    if (_strokes.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  void _clearStrokes() {
    if (_strokes.isNotEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _strokes.clear();
      });
    }
  }

  int get _estimatedBytes {
    switch (_mode) {
      case 'text':
        return _textTags.isNotEmpty ? 45000 : utf8.encode(_mainTextController.text).length + 400;
      case 'photo':
        return (_photoBytes?.lengthInBytes ?? 0) + 2000;
      case 'pixel_art':
        return _textTags.isNotEmpty || _strokes.isNotEmpty ? 40000 : _pixelArtHex.length + 300;
      default:
        return 300;
    }
  }

  Future<void> _publishStory() async {
    final budget = _appState.socialBudget;
    if (budget != null && budget.remainingBytes < _estimatedBytes) {
      setState(() => _errorMessage = 'Weekly social budget quota exceeded (${AppState.formatBytes(budget.remainingBytes)} left)');
      return;
    }

    _deselectActiveTag();

    setState(() {
      _isPublishing = true;
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      String finalStoryType = _mode;
      String finalContent = '';
      String? finalCaption;

      // Flatten entire 9:16 canvas if photo, pixel art with decorations, or styled text
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final pngBytes = byteData.buffer.asUint8List();
          final webpBytes = await FlutterImageCompress.compressWithList(
            pngBytes,
            format: CompressFormat.webp,
            quality: 85,
          );
          finalContent = base64Encode(webpBytes);
          finalStoryType = 'photo';
        }
      }

      if (finalContent.isEmpty) {
        if (_mode == 'text') {
          finalContent = _mainTextController.text.trim();
        } else if (_mode == 'pixel_art') {
          finalContent = _pixelArtHex;
        } else if (_mode == 'photo' && _photoBytes != null) {
          finalContent = base64Encode(_photoBytes!);
        }
      }

      if (finalContent.isEmpty) {
        throw Exception('Story content cannot be empty');
      }

      await _appState.postNewStory(
        storyType: finalStoryType,
        content: finalContent,
        themeId: ThemeController().themeId,
        caption: finalCaption,
        textBorderId: _selectedTag?.borderStyleId ?? StoryTextStyles.cyberpunk,
      );

      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.wk.surface,
            content: Text('Story published to mutual contacts (24h)', style: context.wk.body),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to publish story: $e';
          _isPublishing = false;
          _isExporting = false;
        });
      }
    }
  }

  void _openPaletteSetPicker(BuildContext context) {
    final t = context.wk;

    showDialog(
      context: context,
      builder: (pickerCtx) {
        return AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusCard),
            side: BorderSide(color: t.border),
          ),
          title: Text(
            t.uppercaseLabels ? 'COLOR PALETTES' : 'Color Palettes',
            style: t.screenTitle.copyWith(fontSize: 16),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final set in WkPalette.sets) ...[
                  _paletteSetOption(pickerCtx, t, set),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(pickerCtx),
              child: Text(
                t.uppercaseLabels ? 'CLOSE' : 'Close',
                style: t.body.copyWith(color: t.action),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _paletteSetOption(BuildContext pickerCtx, WiltkeyTokens t, WkPaletteSet set) {
    final locked = !WkPalette.canAuthor(set);
    final isSelected = _currentBrushSet.id == set.id;

    return InkWell(
      onTap: locked
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: t.surface,
                  content: Text('${set.name} palette is locked. Available with WiltKey Plus or palette pack.', style: t.body),
                ),
              );
            }
          : () {
              HapticFeedback.selectionClick();
              setState(() {
                _currentBrushSet = set;
                _selectedBrushColor = WkPalette.colorAt(set.start);
                if (_selectedTag != null) {
                  _selectedTag!.textColor = _selectedBrushColor;
                }
              });
              Navigator.pop(pickerCtx);
            },
      borderRadius: BorderRadius.circular(t.radiusControl),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? t.action.withValues(alpha: 0.15) : t.bg,
          borderRadius: BorderRadius.circular(t.radiusControl),
          border: Border.all(
            color: isSelected ? t.action : t.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  set.name,
                  style: t.body.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? t.action : t.textPrimary,
                  ),
                ),
                if (set.premium) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: t.action.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(t.radiusPill),
                    ),
                    child: Text(
                      'PACK',
                      style: t.badgeLabel.copyWith(fontSize: 8, color: t.action, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const Spacer(),
                if (locked)
                  Icon(Icons.lock, size: 16, color: t.textSecondary)
                else if (isSelected)
                  Icon(Icons.check, size: 16, color: t.action),
              ],
            ),
            const SizedBox(height: 8),
            // Swatch preview strip
            SizedBox(
              height: 18,
              child: Row(
                children: [
                  for (int i = set.start; i < set.end && i < WkPalette.length; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: WkPalette.colorAt(i),
                          borderRadius: BorderRadius.circular(2),
                        ),
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

  Widget _buildDraggableTag(StoryTextTag tag, BoxConstraints constraints, WiltkeyTokens t, double bottomInset) {
    final double posX = (tag.normalizedPos.dx * constraints.maxWidth).clamp(6.0, max(6.0, constraints.maxWidth - 60.0));
    final double naturalPosY = (tag.normalizedPos.dy * constraints.maxHeight).clamp(6.0, max(6.0, constraints.maxHeight - 40.0));
    final isSelected = _selectedTagId == tag.id;

    // When actively editing with keyboard open, ensure the text box shifts up only if it would otherwise be occluded by the floating toolbar
    final double maxSafeY = max(10.0, constraints.maxHeight * 0.45);
    final double posY = (isSelected && bottomInset > 0)
        ? min(naturalPosY, maxSafeY)
        : naturalPosY;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      left: posX,
      top: posY,
      child: GestureDetector(
        onPanUpdate: (details) {
          if (_isDrawingMode) return;
          setState(() {
            final newDx = ((posX + details.delta.dx) / constraints.maxWidth).clamp(0.01, 0.90);
            final newDy = ((naturalPosY + details.delta.dy) / constraints.maxHeight).clamp(0.01, 0.92);
            tag.normalizedPos = Offset(newDx, newDy);
          });
        },
        child: ThemedStoryTextTag(
          text: tag.text,
          styleId: tag.borderStyleId,
          textColor: tag.textColor,
          fontSize: tag.fontSize,
          isSelected: isSelected,
          isEditing: isSelected && !_isExporting,
          textController: tag.textController,
          focusNode: tag.focusNode,
          tokens: t,
          onChanged: (val) => setState(() => tag.text = val),
          onTap: () => _selectTag(tag),
          onDelete: () => _deleteTag(tag.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final budget = _appState.socialBudget;
    final activeTag = _selectedTag;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _deselectActiveTag,
          child: Stack(
            children: [
              Column(
                children: [
              // Top Studio Toolbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    // Rotate 90°
                    if (_mode == 'photo' || _mode == 'pixel_art')
                      IconButton(
                        icon: const Icon(Icons.rotate_right, color: Colors.white, size: 24),
                        tooltip: 'Rotate 90°',
                        onPressed: _rotate90,
                      ),
                    // Drawing Brush Toggle
                    IconButton(
                      icon: Icon(
                        Icons.brush,
                        color: _isDrawingMode ? t.action : Colors.white,
                        size: 24,
                      ),
                      tooltip: 'Freehand Draw',
                      onPressed: () {
                        _deselectActiveTag();
                        setState(() => _isDrawingMode = !_isDrawingMode);
                      },
                    ),
                    // Add Text Sticker Tag
                    IconButton(
                      icon: Icon(
                        Icons.title,
                        color: activeTag != null ? t.action : Colors.white,
                        size: 24,
                      ),
                      tooltip: 'Add Text Tag',
                      onPressed: _addNewTextTag,
                    ),
                    const SizedBox(width: 6),
                    // Publish Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.action,
                        foregroundColor: t.onAction,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusPill)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: _isPublishing ? null : _publishStory,
                      child: _isPublishing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Share 24h',
                              style: t.badgeLabel.copyWith(color: t.onAction, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: t.danger.withValues(alpha: 0.25),
                  child: Text(
                    _errorMessage!,
                    style: t.dataMono.copyWith(color: t.danger, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Main 9:16 Vertical Story Canvas
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: RepaintBoundary(
                        key: _canvasKey,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(t.radiusCard),
                            border: Border.all(color: t.border.withValues(alpha: 0.4), width: 1.0),
                            boxShadow: const [
                              BoxShadow(color: Colors.black87, blurRadius: 16, spreadRadius: 4),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(t.radiusCard),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // 1. Layer 0: Background (Photo, Pixel Art, or Text Backdrop)
                                if (_mode == 'photo' && _photoBytes != null)
                                  Transform.rotate(
                                    angle: _rotationSteps * (pi / 2),
                                    child: InteractiveViewer(
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      panEnabled: !_isDrawingMode && activeTag == null,
                                      scaleEnabled: !_isDrawingMode && activeTag == null,
                                      child: Center(
                                        child: Image.memory(
                                          _photoBytes!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      ),
                                    ),
                                  )
                                else if (_mode == 'pixel_art' && _pixelArtHex.isNotEmpty)
                                  Transform.rotate(
                                    angle: _rotationSteps * (pi / 2),
                                    child: InteractiveViewer(
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      panEnabled: !_isDrawingMode && activeTag == null,
                                      scaleEnabled: !_isDrawingMode && activeTag == null,
                                      child: Center(
                                        child: PixelArtAvatar(
                                          hexString: _pixelArtHex,
                                          size: 220,
                                        ),
                                      ),
                                    ),
                                  )
                                else ...[
                                  // Text Mode Gradient Backdrop
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: _backdropGradients[_textBackdropIndex % _backdropGradients.length],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(24),
                                    child: Center(
                                      child: TextField(
                                        controller: _mainTextController,
                                        maxLines: null,
                                        textAlign: TextAlign.center,
                                        style: t.screenTitle.copyWith(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          shadows: const [
                                            Shadow(color: Colors.black87, blurRadius: 8),
                                          ],
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Tap to type story...',
                                          hintStyle: t.bodySecondary.copyWith(color: Colors.white54, fontSize: 20),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                // 2. Layer 1: Freehand Drawing Layer
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: StoryDrawingPainter(
                                      strokes: _strokes,
                                      activeStroke: _activeStroke,
                                    ),
                                  ),
                                ),

                                // Gesture detector for drawing strokes
                                if (_isDrawingMode)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onPanStart: (details) {
                                        setState(() {
                                          _activeStroke = DrawingStroke(
                                            points: [details.localPosition],
                                            color: _selectedBrushColor,
                                            strokeWidth: _selectedBrushSize,
                                          );
                                        });
                                      },
                                      onPanUpdate: (details) {
                                        if (_activeStroke != null) {
                                          setState(() {
                                            _activeStroke!.points.add(details.localPosition);
                                          });
                                        }
                                      },
                                      onPanEnd: (_) {
                                        if (_activeStroke != null) {
                                          setState(() {
                                            _strokes.add(_activeStroke!.clone());
                                            _activeStroke = null;
                                          });
                                        }
                                      },
                                    ),
                                  ),

                                // 3. Layer 2: Draggable Themed Text Tags
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        for (final tag in _textTags)
                                          _buildDraggableTag(tag, constraints, t, bottomInset),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Base Bottom Controls (Media Picker or Drawing Controls)
              // Kept in the Column at constant size so the canvas NEVER resizes or distorts when entering text edit mode!
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.black87,
                child: _isDrawingMode
                    ? _buildDrawingControls(t)
                    : _buildMediaPickerControls(t, budget),
              ),
            ],
          ),

          // Floating Text Tag Editing Toolbar (independent overlay, stays attached to the keyboard)
          if (activeTag != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: bottomInset,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.95),
                    border: Border(
                      top: BorderSide(color: t.border.withValues(alpha: 0.5), width: 1.0),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black87, blurRadius: 16, spreadRadius: 4),
                    ],
                  ),
                  child: _buildTextTagEditingControls(t, activeTag),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);
  }

  /// Contextual bottom controls for when a Text Tag is selected on canvas.
  Widget _buildTextTagEditingControls(WiltkeyTokens t, StoryTextTag tag) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: Background / Border Style Chips
        Row(
          children: [
            Text('STYLE', style: t.sectionLabel.copyWith(fontSize: 10, color: t.action)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white70),
              tooltip: 'Delete tag',
              onPressed: () => _deleteTag(tag.id),
            ),
            TextButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: Text('Done', style: t.badgeLabel.copyWith(color: t.action, fontWeight: FontWeight.bold)),
              onPressed: _deselectActiveTag,
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Style Options Horizontal List
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: StoryTextStyles.options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final opt = StoryTextStyles.options[i];
              final isSel = tag.borderStyleId == opt['id'];
              return ChoiceChip(
                label: Text(
                  opt['name']!,
                  style: t.badgeLabel.copyWith(
                    color: isSel ? t.onAction : Colors.white70,
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSel,
                selectedColor: t.action,
                backgroundColor: Colors.white12,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => tag.borderStyleId = opt['id']!);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Bottom row: Text Color Swatches & Size Options
        Row(
          children: [
            // Palette Selector Chip
            InkWell(
              onTap: () => _openPaletteSetPicker(context),
              borderRadius: BorderRadius.circular(t.radiusPill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.action.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(t.radiusPill),
                  border: Border.all(color: t.action.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.palette_outlined, size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _currentBrushSet.name,
                      style: t.badgeLabel.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white70),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Color Swatches
            Expanded(
              child: SizedBox(
                height: 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _currentBrushSet.count,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final colorIdx = _currentBrushSet.start + i;
                    final col = WkPalette.colorAt(colorIdx);
                    final isSel = tag.textColor == col;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => tag.textColor = col);
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? Colors.white : Colors.white24,
                            width: isSel ? 2.0 : 1.0,
                          ),
                          boxShadow: isSel
                              ? [BoxShadow(color: col.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Font Size Selector
            _textSizeOption(tag, 14.0, 'S', t),
            const SizedBox(width: 4),
            _textSizeOption(tag, 18.0, 'M', t),
            const SizedBox(width: 4),
            _textSizeOption(tag, 24.0, 'L', t),
          ],
        ),
      ],
    );
  }

  Widget _textSizeOption(StoryTextTag tag, double size, String label, WiltkeyTokens t) {
    final isSel = tag.fontSize == size;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => tag.fontSize = size);
      },
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSel ? t.action : Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: t.badgeLabel.copyWith(
            fontSize: 10,
            color: isSel ? t.onAction : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawingControls(WiltkeyTokens t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Palette Selector Chip
            InkWell(
              onTap: () => _openPaletteSetPicker(context),
              borderRadius: BorderRadius.circular(t.radiusPill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.action.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(t.radiusPill),
                  border: Border.all(color: t.action.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.palette_outlined, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _currentBrushSet.name,
                      style: t.badgeLabel.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white70),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Brush Size Pills
            _brushSizeOption(3.0, 'S', t),
            const SizedBox(width: 4),
            _brushSizeOption(6.0, 'M', t),
            const SizedBox(width: 4),
            _brushSizeOption(12.0, 'L', t),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.undo, size: 20, color: Colors.white),
              tooltip: 'Undo stroke',
              onPressed: _undoStroke,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white70),
              tooltip: 'Clear drawings',
              onPressed: _clearStrokes,
            ),
            TextButton(
              onPressed: () => setState(() => _isDrawingMode = false),
              child: Text('Done', style: t.badgeLabel.copyWith(color: t.action, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Swatches from current palette set
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _currentBrushSet.count,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final colorIdx = _currentBrushSet.start + i;
              final col = WkPalette.colorAt(colorIdx);
              final isSel = _selectedBrushColor == col;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedBrushColor = col);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? Colors.white : Colors.white24,
                      width: isSel ? 2.5 : 1.0,
                    ),
                    boxShadow: isSel
                        ? [BoxShadow(color: col.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)]
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _brushSizeOption(double size, String label, WiltkeyTokens t) {
    final isSel = _selectedBrushSize == size;
    return GestureDetector(
      onTap: () => setState(() => _selectedBrushSize = size),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSel ? t.action : Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: t.badgeLabel.copyWith(
            fontSize: 10,
            color: isSel ? t.onAction : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPickerControls(WiltkeyTokens t, SocialBudgetInfo? budget) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Gallery
            _studioActionButton(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              active: _mode == 'photo',
              onTap: () => _pickPhoto(ImageSource.gallery),
              t: t,
            ),
            // Camera
            _studioActionButton(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              active: false,
              onTap: () => _pickPhoto(ImageSource.camera),
              t: t,
            ),
            // Pixel Art
            _studioActionButton(
              icon: Icons.grid_on,
              label: 'Pixel Art',
              active: _mode == 'pixel_art',
              onTap: _openPixelArtPicker,
              t: t,
            ),
            // Typography / Background
            _studioActionButton(
              icon: Icons.text_fields,
              label: 'Text',
              active: _mode == 'text',
              onTap: () {
                setState(() {
                  _mode = 'text';
                  _textBackdropIndex = (_textBackdropIndex + 1) % _backdropGradients.length;
                  _deselectActiveTag();
                });
              },
              t: t,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Est: ~${AppState.formatBytes(_estimatedBytes)}',
              style: t.dataMono.copyWith(fontSize: 10, color: t.textTertiary),
            ),
            Text(
              'Weekly Quota Left: ${AppState.formatBytes(budget?.remainingBytes ?? (10 * 1024 * 1024))}',
              style: t.dataMono.copyWith(fontSize: 10, color: t.textTertiary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _studioActionButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required WiltkeyTokens t,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: active ? t.action : Colors.white70),
            const SizedBox(height: 2),
            Text(
              label,
              style: t.badgeLabel.copyWith(
                fontSize: 11,
                color: active ? t.action : Colors.white70,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
