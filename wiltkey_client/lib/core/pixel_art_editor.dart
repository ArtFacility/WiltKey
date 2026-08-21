import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import 'theme/wk.dart';
import 'theme/wiltkey_tokens.dart';
import 'pixel_art_avatar.dart';
import 'pixel_palette.dart';
import 'persistence.dart';

/// Reusable 10x10 pixel-art editor used for personal avatars (settings,
/// onboarding) and group icons (create group). Self-contained drawing/colour
/// state; emits the current grid string via [onChanged] in whichever encoding
/// [PixelGrid.encode] chooses (legacy hex when only classic colours are used,
/// otherwise `v2:`). Present it as a modal with [showPixelArtEditor].
///
/// The drawing canvas is fixed at the top of the dialog to prevent any gesture
/// arena conflict with outer scrolling. Palettes are organized by active set,
/// with a dedicated palette switcher popup.
class PixelArtEditor extends StatefulWidget {
  final String initialHex;

  /// Seed for the "identicon" shortcut chip; when null the chip is hidden
  /// (groups have no identity hash to derive one from).
  final String? identiconSeed;
  final int defaultColorIndex;
  final double previewSize;
  final ValueChanged<String> onChanged;

  const PixelArtEditor({
    super.key,
    required this.initialHex,
    required this.onChanged,
    this.identiconSeed,
    this.defaultColorIndex = 1,
    this.previewSize = 200,
  });

  /// True for any valid grid string (either encoding).
  static bool isValidHex(String hex) => PixelGrid.isValid(hex);

  /// A 2–3 colour, horizontally-symmetric retro sprite drawn from the current
  /// authoring palette (retired/legacy colours are excluded). Used by the Random
  /// chip and as a fallback when no valid initial grid (and no identicon seed) is
  /// supplied.
  static String randomSymmetricGrid() {
    final rand = Random();
    final authoring = <int>[];
    for (final s in WkPalette.authoringSets) {
      for (int i = s.start; i < s.end && i < WkPalette.length; i++) {
        authoring.add(i);
      }
    }
    if (authoring.isEmpty) authoring.add(0);

    final numColors = rand.nextInt(2) + 2; // 2 or 3 colours
    final chosen = <int>[0]; // always keep the dark background available
    var guard = 0;
    while (chosen.length < numColors && guard++ < 64) {
      final c = authoring[rand.nextInt(authoring.length)];
      if (!chosen.contains(c)) chosen.add(c);
    }
    final grid = List<int>.filled(PixelGrid.cells, 0);
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 5; x++) {
        final ch = chosen[rand.nextInt(chosen.length)];
        grid[y * 10 + x] = ch;
        grid[y * 10 + (9 - x)] = ch; // mirror for symmetry
      }
    }
    return PixelGrid.encode(grid);
  }

  /// Normalises [initialHex] to a drawable grid string: keeps a valid grid,
  /// otherwise falls back to an identicon (when [identiconSeed] is given) or a
  /// random one.
  static String normalize(String initialHex, {String? identiconSeed}) {
    if (PixelGrid.isValid(initialHex)) return initialHex;
    if (identiconSeed != null && identiconSeed.isNotEmpty) {
      return PixelArtAvatar.generateIdenticon(identiconSeed);
    }
    return randomSymmetricGrid();
  }

  @override
  State<PixelArtEditor> createState() => _PixelArtEditorState();
}

class _PixelArtEditorState extends State<PixelArtEditor> {
  late List<int> _grid;
  late int _selColor;
  late WkPaletteSet _currentSet;

  @override
  void initState() {
    super.initState();
    _grid = PixelGrid.parseOrBlank(
      PixelArtEditor.normalize(
        widget.initialHex,
        identiconSeed: widget.identiconSeed,
      ),
    );
    // Callers may still request a legacy default (e.g. a classic index); if it
    // isn't drawable, fall back to the first colour of the authoring palette.
    _selColor = WkPalette.isAuthoringIndex(widget.defaultColorIndex)
        ? widget.defaultColorIndex
        : WkPalette.firstAuthoringIndex;

    // Find the authoring set containing _selColor, or default to the first authoring set
    _currentSet = WkPalette.authoringSets.firstWhere(
      (s) => s.contains(_selColor),
      orElse: () => WkPalette.authoringSets.first,
    );
  }

  void _emit() => widget.onChanged(PixelGrid.encode(_grid));

  void _draw(Offset pos, double w, double h) {
    final x = (pos.dx / (w / 10)).floor();
    final y = (pos.dy / (h / 10)).floor();
    if (x < 0 || x >= 10 || y < 0 || y >= 10) return;
    final idx = y * 10 + x;
    if (_grid[idx] == _selColor) return;
    setState(() => _grid[idx] = _selColor);
    _emit();
  }

  void _setGrid(String gridStr) {
    setState(() => _grid = PixelGrid.parseOrBlank(gridStr));
    _emit();
  }

  void _openPalettePicker(BuildContext context) {
    final t = context.wk;
    showDialog<void>(
      context: context,
      builder: (pickerCtx) {
        return AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusCard),
            side: BorderSide(color: t.border),
          ),
          title: Text(
            t.uppercaseLabels ? 'SELECT PALETTE' : 'Select Palette',
            style: t.screenTitle.copyWith(fontSize: 16),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final set in WkPalette.authoringSets) ...[
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
    final isSelected = _currentSet.id == set.id;

    return InkWell(
      onTap: locked
          ? null
          : () {
              setState(() {
                _currentSet = set;
                if (!set.contains(_selColor)) {
                  _selColor = set.start;
                }
              });
              Navigator.pop(pickerCtx);
            },
      borderRadius: BorderRadius.circular(t.radiusControl),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? t.action.withValues(alpha: 0.12)
              : t.bgRaised,
          borderRadius: BorderRadius.circular(t.radiusControl),
          border: Border.all(
            color: isSelected ? t.action : t.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  t.uppercaseLabels ? set.name.toUpperCase() : set.name,
                  style: t.dataMono.copyWith(
                    color: isSelected ? t.action : t.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (locked) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.lock, size: 13, color: t.textSecondary),
                ],
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, size: 16, color: t.action),
              ],
            ),
            const SizedBox(height: 8),
            // Mini color swatch preview strip
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  for (int i = set.start; i < set.end && i < WkPalette.length; i++)
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: WkPalette.colorAt(i),
                        shape: BoxShape.circle,
                        border: Border.all(color: t.border, width: 0.5),
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

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final locked = !WkPalette.canAuthor(_currentSet);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Fixed Pixel Art Drawing Canvas (Zero Scroll/Gesture Conflict)
        Container(
          width: widget.previewSize,
          height: widget.previewSize,
          decoration: BoxDecoration(
            border: Border.all(color: t.positive, width: 2),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) =>
                    _draw(e.localPosition, c.maxWidth, c.maxHeight),
                onPointerMove: (e) =>
                    _draw(e.localPosition, c.maxWidth, c.maxHeight),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 100,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        crossAxisSpacing: 0.5,
                        mainAxisSpacing: 0.5,
                      ),
                  itemBuilder: (context, i) {
                    return Container(color: WkPalette.colorAt(_grid[i]));
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // 2. Brush Preview & Palette Selector Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.settingsProfileBrushColor,
                  style: t.dataMono.copyWith(
                    color: t.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: WkPalette.colorAt(_selColor),
                    border: Border.all(color: t.textPrimary, width: 1.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            // Switch Palette Button
            InkWell(
              onTap: () => _openPalettePicker(context),
              borderRadius: BorderRadius.circular(t.radiusControl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.bgRaised,
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.uppercaseLabels
                          ? _currentSet.name.toUpperCase()
                          : _currentSet.name,
                      style: t.dataMono.copyWith(
                        color: t.action,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 16, color: t.action),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. Swatches of the Active Palette Set
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (int i = _currentSet.start;
                i < _currentSet.end && i < WkPalette.length;
                i++)
              _swatch(t, i, locked),
          ],
        ),
        const SizedBox(height: 10),

        // 4. Action Chips (Identicon, Clear, Random, Add to templates)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            if (widget.identiconSeed != null &&
                widget.identiconSeed!.isNotEmpty)
              _chip(
                t,
                l10n.settingsProfileChipIdenticon,
                () => _setGrid(
                  PixelArtAvatar.generateIdenticon(widget.identiconSeed!),
                ),
              ),
            _chip(
              t,
              l10n.settingsProfileChipClear,
              () => _setGrid(PixelGrid.blank),
            ),
            _chip(
              t,
              l10n.settingsProfileChipRandom,
              () => _setGrid(PixelArtEditor.randomSymmetricGrid()),
            ),
            _chip(
              t,
              l10n.settingsProfileChipTemplateSave,
              () async {
                final encoded = PixelGrid.encode(_grid);
                await WiltkeyPersistence().saveAvatarTemplate(encoded);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.settingsProfileTemplateSaved),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: Icons.bookmark_add_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _swatch(WiltkeyTokens t, int i, bool locked) {
    final sel = _selColor == i;
    return GestureDetector(
      onTap: locked ? null : () => setState(() => _selColor = i),
      child: Opacity(
        opacity: locked ? 0.45 : 1.0,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: WkPalette.colorAt(i),
            border: Border.all(
              color: sel ? t.action : t.border,
              width: sel ? 2.0 : 1.0,
            ),
            shape: BoxShape.circle,
          ),
          child: locked
              ? Icon(Icons.lock, size: 11, color: t.textPrimary)
              : null,
        ),
      ),
    );
  }

  Widget _chip(WiltkeyTokens t, String label, VoidCallback onTap, {IconData? icon}) => ActionChip(
    avatar: icon != null ? Icon(icon, size: 14, color: t.action) : null,
    label: Text(
      t.uppercaseLabels ? label.toUpperCase() : label,
      style: t.dataMono.copyWith(color: t.action, fontSize: 11),
    ),
    backgroundColor: t.surface,
    side: BorderSide(color: t.border),
    onPressed: onTap,
  );
}

/// Presents the [PixelArtEditor] as a Save/Cancel modal. Returns the resulting
/// grid string, or null if the user cancelled.
Future<String?> showPixelArtEditor(
  BuildContext context, {
  required String initialHex,
  required String title,
  String? identiconSeed,
  int defaultColorIndex = 1,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final t = ctx.wk;
      final l10n = AppLocalizations.of(ctx)!;
      // Seed with the normalised grid so a Save without any edit still returns a
      // valid grid (identicon/random) rather than the invalid initial value.
      String current = PixelArtEditor.normalize(
        initialHex,
        identiconSeed: identiconSeed,
      );
      return AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border),
        ),
        title: Text(
          t.uppercaseLabels ? title.toUpperCase() : title,
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        content: PixelArtEditor(
          initialHex: initialHex,
          identiconSeed: identiconSeed,
          defaultColorIndex: defaultColorIndex,
          onChanged: (hex) => current = hex,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              t.uppercaseLabels
                  ? l10n.commonCancel.toUpperCase()
                  : l10n.commonCancel,
              style: t.body.copyWith(color: t.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, current),
            child: Text(
              t.uppercaseLabels
                  ? l10n.commonSave.toUpperCase()
                  : l10n.commonSave,
              style: t.body.copyWith(
                color: t.action,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}
