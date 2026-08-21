import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/custom_emoji.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';

/// A compact emoji picker shown in place of the keyboard. A tap inserts the
/// standard unicode emoji at the cursor (or the chat's custom `:name:` token);
/// press-and-hold *charges* the emoji — it swells, throws off sparks, and once
/// fully charged bursts into a big, bubble-less sticker via [onSendSticker].
/// Releasing before the burst cancels it. Stateless about visibility — the
/// parent shows/hides it.
class EmojiPickerPanel extends StatefulWidget {
  final TextEditingController controller;

  /// The chat's live custom-emoji pool (name -> emoji); shown as a first tab.
  final Map<String, CustomEmoji> emojiMap;
  final double height;

  /// Charge-complete handler: sends the given emoji/`:name:` payload as a
  /// sticker. When null, press-and-hold does nothing (sticker sending disabled)
  /// and cells behave as tap-to-insert only.
  final void Function(String payload)? onSendSticker;

  const EmojiPickerPanel({
    super.key,
    required this.controller,
    this.emojiMap = const {},
    this.height = 252,
    this.onSendSticker,
  });

  // Curated unicode sets — enough for everyday use without bundling a full DB.
  static const List<String> _smileys = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '😂',
    '🤣',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '😘',
    '😗',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '😌',
    '😔',
    '😪',
    '😴',
    '😷',
    '🤒',
    '🤕',
    '🤢',
    '🤮',
    '🥵',
    '🥶',
    '🥴',
    '😵',
    '🤯',
    '🤠',
    '🥳',
    '😎',
    '🤓',
    '🧐',
    '😕',
    '😟',
    '🙁',
    '☹️',
    '😮',
    '😲',
    '😳',
    '🥺',
    '😦',
    '😨',
    '😰',
    '😥',
    '😢',
    '😭',
    '😱',
    '😖',
    '😣',
    '😞',
    '😓',
    '😩',
    '😫',
    '🥱',
    '😤',
    '😡',
    '😠',
    '🤬',
  ];
  static const List<String> _gestures = [
    '👍',
    '👎',
    '👌',
    '🤌',
    '🤏',
    '✌️',
    '🤞',
    '🤟',
    '🤘',
    '🤙',
    '👈',
    '👉',
    '👆',
    '👇',
    '☝️',
    '✋',
    '🤚',
    '🖐️',
    '🖖',
    '👋',
    '🤝',
    '🙏',
    '💪',
    '🦾',
    '👏',
    '🙌',
    '👐',
    '🤲',
    '🫶',
    '🤜',
    '🤛',
    '✊',
    '👊',
    '🫵',
    '👀',
    '👁️',
    '🧠',
    '🫀',
    '👅',
    '👄',
    '🦴',
    '🦷',
    '👂',
    '👃',
    '🫦',
    '🤳',
    '💅',
    '🦵',
  ];
  static const List<String> _hearts = [
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '💔',
    '❣️',
    '💕',
    '💞',
    '💓',
    '💗',
    '💖',
    '💘',
    '💝',
    '💟',
    '💌',
    '💋',
    '✨',
    '⭐',
    '🌟',
    '💫',
    '⚡',
    '🔥',
    '💥',
    '💯',
    '✅',
    '❌',
    '⭕',
    '❗',
    '❓',
    '‼️',
    '⁉️',
    '💤',
    '🎉',
    '🎊',
    '🎁',
    '🏆',
    '🥇',
    '🌈',
    '☀️',
    '🌙',
    '⛅',
    '☔',
    '❄️',
  ];
  static const List<String> _animals = [
    '🐶',
    '🐱',
    '🐭',
    '🐹',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
    '🙈',
    '🙉',
    '🙊',
    '🐔',
    '🐧',
    '🐦',
    '🦆',
    '🦉',
    '🦄',
    '🐝',
    '🦋',
    '🐌',
    '🐞',
    '🐢',
    '🐍',
    '🐙',
    '🦀',
    '🐳',
    '🐬',
    '🐟',
    '🦓',
    '🦒',
    '🐘',
    '🐪',
    '🌸',
    '🌺',
    '🌻',
    '🌹',
    '🌷',
    '🌼',
    '🌲',
    '🌴',
    '🍀',
  ];
  static const List<String> _food = [
    '🍎',
    '🍐',
    '🍊',
    '🍋',
    '🍌',
    '🍉',
    '🍇',
    '🍓',
    '🫐',
    '🍒',
    '🍑',
    '🥭',
    '🍍',
    '🥥',
    '🥝',
    '🍅',
    '🥑',
    '🌽',
    '🥕',
    '🍔',
    '🍟',
    '🍕',
    '🌭',
    '🥪',
    '🌮',
    '🌯',
    '🥗',
    '🍝',
    '🍜',
    '🍣',
    '🍱',
    '🍤',
    '🍙',
    '🍚',
    '🍦',
    '🍰',
    '🎂',
    '🧁',
    '🍩',
    '🍪',
    '🍫',
    '🍬',
    '🍭',
    '🍿',
    '☕',
    '🍵',
    '🍺',
    '🍷',
  ];
  static const List<String> _activities = [
    '⚽',
    '🏀',
    '🏈',
    '⚾',
    '🎾',
    '🏐',
    '🎱',
    '🏓',
    '🏸',
    '🥅',
    '⛳',
    '🎮',
    '🕹️',
    '🎲',
    '🎯',
    '🎸',
    '🎺',
    '🎻',
    '🥁',
    '🎤',
    '🎧',
    '🎬',
    '🎨',
    '♟️',
    '🚗',
    '🚕',
    '🚙',
    '🚌',
    '🏎️',
    '🚓',
    '✈️',
    '🚀',
    '🚲',
    '🛵',
    '🏠',
    '🏖️',
    '🗻',
    '🗼',
    '🎆',
    '🎇',
    '🧭',
    '⏰',
    '💡',
    '🔋',
    '📱',
    '💻',
    '📷',
    '🔒',
  ];

  /// The curated categories, exposed (as `[label, emojis...]`-free flat lists) so
  /// the reaction picker's "+" can offer the same full set without duplicating it.
  static const List<List<String>> categories = [
    _smileys,
    _gestures,
    _hearts,
    _animals,
    _food,
    _activities,
  ];

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  void _insert(String text) {
    final c = widget.controller;
    final sel = c.selection;
    final base = c.text;
    if (sel.isValid && sel.start >= 0 && sel.end >= sel.start) {
      final newText = base.replaceRange(sel.start, sel.end, text);
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + text.length),
      );
    } else {
      final newText = base + text;
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final custom = widget.emojiMap.values.where((e) => !e.deleted).toList();
    final hasCustom = custom.isNotEmpty;

    final tabs = <Widget>[
      if (hasCustom) const Tab(icon: Icon(Icons.star_outline, size: 20)),
      const Tab(icon: Icon(Icons.emoji_emotions_outlined, size: 20)),
      const Tab(icon: Icon(Icons.back_hand_outlined, size: 20)),
      const Tab(icon: Icon(Icons.favorite_border, size: 20)),
      const Tab(icon: Icon(Icons.pets_outlined, size: 20)),
      const Tab(icon: Icon(Icons.restaurant_outlined, size: 20)),
      const Tab(icon: Icon(Icons.sports_esports_outlined, size: 20)),
    ];

    final views = <Widget>[
      if (hasCustom) _customGrid(t, custom),
      _emojiGrid(EmojiPickerPanel._smileys),
      _emojiGrid(EmojiPickerPanel._gestures),
      _emojiGrid(EmojiPickerPanel._hearts),
      _emojiGrid(EmojiPickerPanel._animals),
      _emojiGrid(EmojiPickerPanel._food),
      _emojiGrid(EmojiPickerPanel._activities),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(
            top: BorderSide(color: t.border, width: t.borderWidth),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                indicatorColor: t.action,
                labelColor: t.action,
                unselectedLabelColor: t.textTertiary,
                dividerColor: t.border,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                tabs: tabs,
              ),
            ),
            Expanded(child: TabBarView(children: views)),
            if (widget.onSendSticker != null) _stickerHint(t, context),
          ],
        ),
      ),
    );
  }

  /// Thin footer hint telling the user that a long-press sends a big sticker.
  Widget _stickerHint(WiltkeyTokens t, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border, width: t.borderWidth)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 12, color: t.textTertiary),
          const SizedBox(width: 5),
          Text(
            t.uppercaseLabels
                ? l10n.chatStickerHint.toUpperCase()
                : l10n.chatStickerHint,
            style: t.dataMono.copyWith(color: t.textTertiary, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _emojiGrid(List<String> emojis) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const maxExtent = 44.0;
        final cols = (constraints.maxWidth / maxExtent).floor().clamp(1, 12);
        final cell = (constraints.maxWidth - 16 - 2 * (cols - 1)) / cols;
        final fontSize = cell * 0.55;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: emojis.length,
          itemBuilder: (context, i) {
            final e = emojis[i];
            return _ChargeSticker(
              tokens: context.wk,
              onInsert: () => _insert(e),
              onSend: widget.onSendSticker == null
                  ? null
                  : () => widget.onSendSticker!(e),
              big: (box) => Center(
                child: Text(e, style: TextStyle(fontSize: box * 0.82)),
              ),
              child: Center(child: Text(e, style: TextStyle(fontSize: fontSize))),
            );
          },
        );
      },
    );
  }

  Widget _customGrid(WiltkeyTokens t, List<CustomEmoji> custom) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 48,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: custom.length,
      itemBuilder: (context, i) {
        final e = custom[i];
        return _ChargeSticker(
          tokens: t,
          onInsert: () => _insert(e.token),
          onSend: widget.onSendSticker == null
              ? null
              : () => widget.onSendSticker!(e.token),
          big: (box) => Padding(
            padding: EdgeInsets.all(box * 0.08),
            child: Image.memory(
              e.bytes,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Text(e.token, style: t.dataMono),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Image.memory(
              e.bytes,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Text(e.token, style: t.dataMono),
            ),
          ),
        );
      },
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// A single glowing spark thrown off a charging sticker. Positions are in the
/// global (overlay) coordinate space; [vel] is in logical px/second.
class _Spark {
  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  final double radius;
  final double drag;
  final Color color;

  _Spark({
    required this.pos,
    required this.vel,
    required this.life,
    required this.maxLife,
    required this.radius,
    required this.drag,
    required this.color,
  });
}

/// Wraps one emoji cell. A tap inserts the emoji; a press-and-hold *charges* it:
/// a copy of the emoji lifts off into an overlay, swells while spitting sparks
/// and filling a ring gauge, then — once the ring completes — bursts, fires
/// [onSend], and rains particles. Releasing before the burst cancels cleanly.
///
/// The whole effect is self-contained: it drives a single [Ticker], paints into
/// the root [Overlay] (so sparks fly over the keyboard/panel), and never touches
/// the send path beyond the [onSend] callback.
class _ChargeSticker extends StatefulWidget {
  /// Small in-grid content (the tappable cell).
  final Widget child;

  /// Builds the enlarged emoji drawn in the overlay, sized to fit [box] px.
  final Widget Function(double box) big;

  /// Tap (or an early, barely-charged release) → insert at the cursor.
  final VoidCallback onInsert;

  /// Charge completed → send as a sticker. When null, hold does nothing and the
  /// cell is tap-to-insert only.
  final VoidCallback? onSend;

  final WiltkeyTokens tokens;

  const _ChargeSticker({
    required this.child,
    required this.big,
    required this.onInsert,
    required this.onSend,
    required this.tokens,
  });

  @override
  State<_ChargeSticker> createState() => _ChargeStickerState();
}

class _ChargeStickerState extends State<_ChargeSticker>
    with SingleTickerProviderStateMixin {
  static const int _chargeMs = 720;
  static const int _burstMs = 360;

  /// Release with charge above this fraction → treat as a deliberate abort
  /// (swallow the tap-insert). Below it, a quick press still inserts.
  static const double _abortInsert = 0.28;

  final _cellKey = GlobalKey();
  final _rng = math.Random();

  Ticker? _ticker;
  OverlayEntry? _entry;

  bool _charging = false; // cell is dimmed / lifted
  bool _bursting = false;
  bool _consumed = false; // suppress the follow-up tap-insert

  double _progress = 0; // 0..1 charge
  double _burst = 0; // 0..1 burst
  double _spawnAcc = 0;
  int _hapticStep = 0;
  Duration _lastTick = Duration.zero;
  double _burstElapsed = 0;

  Offset _center = Offset.zero;
  double _startBox = 34;
  double _endBox = 108;

  final List<_Spark> _sparks = [];
  late final List<Color> _palette = [
    widget.tokens.action,
    widget.tokens.positive,
    widget.tokens.identity,
    widget.tokens.warning,
    Colors.white,
  ];

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  double _curveBox() =>
      _lerp(_startBox, _endBox, Curves.easeOutCubic.transform(_progress));

  void _start(TapDownDetails _) {
    if (widget.onSend == null) return;
    _teardown(); // drop any stale run

    final ctx = _cellKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    _startBox = size.shortestSide * 0.86;
    _center = box.localToGlobal(size.center(Offset.zero));

    final screen = MediaQuery.of(context).size;
    _endBox = math.min(screen.shortestSide * 0.42, 132);
    if (_endBox < _startBox * 2.4) _endBox = _startBox * 2.4;

    _progress = 0;
    _burst = 0;
    _burstElapsed = 0;
    _spawnAcc = 0;
    _hapticStep = 0;
    _bursting = false;
    _consumed = false;
    _lastTick = Duration.zero;
    _sparks.clear();

    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(builder: (_) => _buildOverlay());
    overlay.insert(_entry!);

    _ticker = createTicker(_tick)..start();
    HapticFeedback.lightImpact();
    setState(() => _charging = true);
  }

  void _tick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    if (!_bursting) {
      _progress = (elapsed.inMicroseconds / (_chargeMs * 1000)).clamp(0.0, 1.0);
      _hapticMilestones();
      if (_progress >= 1.0) _beginBurst();
    }
    if (_bursting) {
      _burstElapsed += dt;
      _burst = (_burstElapsed / (_burstMs / 1000)).clamp(0.0, 1.0);
    }

    _stepSparks(dt);
    if (!_bursting) _spawnCharge(dt);
    _entry?.markNeedsBuild();

    if (_bursting && _burst >= 1.0) _finishBurst();
  }

  void _hapticMilestones() {
    const steps = [0.4, 0.7, 0.92];
    if (_hapticStep < steps.length && _progress >= steps[_hapticStep]) {
      _hapticStep++;
      HapticFeedback.selectionClick();
    }
  }

  void _beginBurst() {
    _bursting = true;
    _burstElapsed = 0;
    _consumed = true; // the emoji is on its way — no tap-insert on release
    HapticFeedback.heavyImpact();
    _spawnBurst();
    widget.onSend?.call();
  }

  void _finishBurst() {
    // Keep [_consumed] so the finger-lift doesn't also insert.
    _stopEffect();
    if (mounted) setState(() => _charging = false);
  }

  /// Pointer lifted (tap up) before the burst — cancel the charge. A meaningful
  /// amount of charge counts as a deliberate abort, so we also swallow the tap.
  void _release() {
    if (_bursting) return; // already sending; let the burst finish
    if (_progress > _abortInsert) _consumed = true;
    _cancel();
  }

  void _cancel() {
    _stopEffect();
    if (mounted) setState(() => _charging = false);
  }

  /// Stop the ticker and pull the overlay, but leave [_consumed] untouched.
  void _stopEffect() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _entry?.remove();
    _entry = null;
    _sparks.clear();
    _bursting = false;
    _progress = 0;
    _burst = 0;
  }

  /// Full reset used on dispose.
  void _teardown() {
    _stopEffect();
    _charging = false;
  }

  void _handleTap() {
    if (_consumed) {
      _consumed = false;
      return;
    }
    widget.onInsert();
  }

  // ---- particle simulation -------------------------------------------------

  void _stepSparks(double dt) {
    if (dt <= 0) return;
    for (final s in _sparks) {
      s.pos += s.vel * dt;
      s.vel *= (1 - (s.drag * dt)).clamp(0.0, 1.0);
      s.life -= dt;
    }
    _sparks.removeWhere((s) => s.life <= 0);
  }

  void _spawnCharge(double dt) {
    final rate = _lerp(5, 30, _progress);
    _spawnAcc += rate * dt;
    final radius = _curveBox() * 0.5;
    while (_spawnAcc >= 1) {
      _spawnAcc -= 1;
      final ang = _rng.nextDouble() * math.pi * 2;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final tang = Offset(-dir.dy, dir.dx) * ((_rng.nextDouble() * 2 - 1) * 22);
      final speed = _lerp(24, 78, _progress) * (0.6 + _rng.nextDouble() * 0.9);
      _sparks.add(_Spark(
        pos: _center + dir * (radius * (0.85 + _rng.nextDouble() * 0.3)),
        vel: dir * speed + tang,
        life: 0.35 + _rng.nextDouble() * 0.5,
        maxLife: 0.85,
        radius: 1.1 + _rng.nextDouble() * 2.0,
        drag: 2.0 + _rng.nextDouble() * 1.5,
        color: _palette[_rng.nextInt(_palette.length)],
      ));
    }
  }

  void _spawnBurst() {
    const n = 28;
    final radius = _curveBox() * 0.42;
    for (int i = 0; i < n; i++) {
      final ang = i / n * math.pi * 2 + _rng.nextDouble() * 0.35;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final speed = 150 + _rng.nextDouble() * 230;
      _sparks.add(_Spark(
        pos: _center + dir * radius,
        vel: dir * speed,
        life: 0.34 + _rng.nextDouble() * 0.42,
        maxLife: 0.76,
        radius: 1.8 + _rng.nextDouble() * 3.0,
        drag: 1.6 + _rng.nextDouble() * 1.2,
        color: _palette[_rng.nextInt(_palette.length)],
      ));
    }
  }

  // ---- overlay -------------------------------------------------------------

  Widget _buildOverlay() {
    final box = _curveBox();
    final drawBox =
        _bursting ? box * (1 + 0.30 * Curves.easeOut.transform(_burst)) : box;

    // Nervous shake as the charge nears completion.
    Offset jitter = Offset.zero;
    if (!_bursting && _progress > 0.55) {
      final amp = (_progress - 0.55) / 0.45 * 3.2;
      jitter = Offset(
        (_rng.nextDouble() * 2 - 1) * amp,
        (_rng.nextDouble() * 2 - 1) * amp,
      );
    }

    final emojiOpacity =
        _bursting ? (1 - Curves.easeIn.transform(_burst)) : 1.0;

    return Positioned.fill(
      child: IgnorePointer(
        // A transparent Material gives the overlay a real DefaultTextStyle.
        // Without it, the emoji Text sits directly under WidgetsApp's fallback
        // style and picks up its debug double-yellow-underline.
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _ChargePainter(
                center: _center,
                box: drawBox,
                progress: _progress,
                bursting: _bursting,
                burst: _burst,
                sparks: _sparks,
                ring: widget.tokens.action,
              ),
            ),
            Positioned(
              left: _center.dx - drawBox / 2 + jitter.dx,
              top: _center.dy - drawBox / 2 + jitter.dy,
              width: drawBox,
              height: drawBox,
              child: Opacity(
                opacity: emojiOpacity.clamp(0.0, 1.0),
                child: widget.big(drawBox),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tapOnly = widget.onSend == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: tapOnly ? null : _start,
      onTapUp: tapOnly ? null : (_) => _release(),
      onTapCancel: tapOnly ? null : _cancel,
      onTap: _handleTap,
      child: SizedBox.expand(
        key: _cellKey,
        child: AnimatedScale(
          scale: _charging ? 0.78 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _charging ? 0.22 : 1.0,
            duration: const Duration(milliseconds: 130),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Paints the charge glow, the ring gauge (or burst shockwave), and every live
/// spark. Repaints every frame — the owning ticker calls `markNeedsBuild`.
class _ChargePainter extends CustomPainter {
  final Offset center;
  final double box;
  final double progress;
  final bool bursting;
  final double burst;
  final List<_Spark> sparks;
  final Color ring;

  _ChargePainter({
    required this.center,
    required this.box,
    required this.progress,
    required this.bursting,
    required this.burst,
    required this.sparks,
    required this.ring,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Soft glow behind the emoji.
    final glowR = box * 0.95;
    final glowA = (bursting ? (1 - burst) : progress) * 0.5;
    if (glowA > 0.01) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [ring.withValues(alpha: glowA), ring.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: glowR));
      canvas.drawCircle(center, glowR, glow);
    }

    if (!bursting) {
      // Ring gauge: faint track + bright sweep showing hold progress.
      final ringR = box * 0.60;
      canvas.drawCircle(
        center,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = ring.withValues(alpha: 0.15),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringR),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round
          ..color = ring.withValues(alpha: 0.9),
      );
    } else {
      // Expanding shockwave ring on burst.
      final ringR = box * 0.6 + burst * (box * 1.4);
      canvas.drawCircle(
        center,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - burst) + 0.5
          ..color = ring.withValues(alpha: (1 - burst) * 0.6),
      );
    }

    // Sparks.
    for (final s in sparks) {
      final o = (s.life / s.maxLife).clamp(0.0, 1.0);
      if (o <= 0) continue;
      canvas.drawCircle(
        s.pos,
        s.radius * (0.4 + 0.6 * o),
        Paint()..color = s.color.withValues(alpha: o),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChargePainter old) => true;
}
