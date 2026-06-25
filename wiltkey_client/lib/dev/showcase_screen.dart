import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/theme_registry.dart';
import '../core/theme/wk.dart';
import '../core/theme/wiltkey_components.dart';
import '../features/auth/presentation/pin_lock_screen.dart';

/// DEV-ONLY. A gallery of the theme's widgets + animations with live controls,
/// for tuning visuals on desktop. Self-contained — touches no AppState/DB/models.
/// See `showcase_main.dart` for how to run and how to remove for release.
class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  String _themeId = 'garden';
  final Random _rng = Random();
  int _idCounter = 0;

  // BLE meadow state.
  final List<SyncBlip> _blips = [];
  static const _mockLog = [
    '[System] Bluetooth initializer active.',
    '[Scanner] Requesting BLE permissions…',
    '[Scanner] Listening for advertisers.',
  ];

  // Budget glyph state.
  double _ours = 0.7;
  double _theirs = 0.3;
  bool _wilted = false;

  // Pairing vine→bloom state.
  double _progress = 0.4;
  SyncVisualState _pairState = SyncVisualState.connecting;

  void _addBlip({
    required double strength,
    bool isWiltkey = false,
    bool isNear = false,
    bool isGroup = false,
  }) {
    setState(() {
      _blips.add(
        SyncBlip(
          id: 'd${_idCounter++}',
          strength: strength + (_rng.nextDouble() - 0.5) * 0.08,
          angle: _rng.nextDouble() * 2 * pi,
          isWiltkey: isWiltkey,
          isNear: isNear,
          isGroup: isGroup,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: WiltkeyThemeRegistry.byId(_themeId).build(),
      child: Builder(
        builder: (context) {
          final t = context.wk;
          return Scaffold(
            backgroundColor: t.bg,
            appBar: AppBar(
              backgroundColor: t.bg,
              elevation: 0,
              title: Text(
                'Dev · Style & Animation Showcase',
                style: t.screenTitle.copyWith(fontSize: 17),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _themeSwitcher(context),
                const SizedBox(height: 16),
                _bleScanSection(context),
                const SizedBox(height: 16),
                _budgetSection(context),
                const SizedBox(height: 16),
                _groupBudgetSection(context),
                const SizedBox(height: 16),
                _badgesSection(context),
                const SizedBox(height: 16),
                _pinSection(context),
                const SizedBox(height: 16),
                _nukeSection(context),
                const SizedBox(height: 16),
                _pairingProgressSection(context),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- sections ------------------------------------------------------------

  Widget _themeSwitcher(BuildContext context) {
    final t = context.wk;
    return Wrap(
      spacing: 8,
      children: [
        for (final d in WiltkeyThemeRegistry.all)
          ChoiceChip(
            label: Text(d.localizedName(context)),
            selected: _themeId == d.id,
            selectedColor: t.action.withValues(alpha: 0.2),
            onSelected: (_) => setState(() => _themeId = d.id),
          ),
      ],
    );
  }

  Widget _bleScanSection(BuildContext context) {
    final t = context.wk;
    return _card(
      context,
      'BLE scan  ·  syncVisual(scanning)',
      '${_blips.length} blip(s). Add devices to watch them grow in; remove to watch them wilt out.',
      [
        context.wkc.syncVisual(
          state: SyncVisualState.scanning,
          blips: _blips,
          log: _mockLog,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _miniBtn(
              context,
              '+ Near peer',
              () => _addBlip(strength: 0.9, isWiltkey: true, isNear: true),
            ),
            _miniBtn(
              context,
              '+ Far peer',
              () => _addBlip(strength: 0.35, isWiltkey: true),
            ),
            _miniBtn(context, '+ Generic BLE', () => _addBlip(strength: 0.5)),
            _miniBtn(
              context,
              '+ Group',
              () => _addBlip(
                strength: 0.7,
                isWiltkey: true,
                isNear: true,
                isGroup: true,
              ),
            ),
            _miniBtn(context, 'Remove', () {
              if (_blips.isNotEmpty) setState(() => _blips.removeLast());
            }, tone: t.danger),
            _miniBtn(
              context,
              'Clear',
              () => setState(_blips.clear),
              tone: t.danger,
            ),
          ],
        ),
      ],
    );
  }

  Widget _budgetSection(BuildContext context) {
    return _card(
      context,
      'Budget glyph  ·  budgetIndicator',
      'ours ${(_ours * 100).round()}%  ·  peer ${(_theirs * 100).round()}%',
      [
        Center(
          child: context.wkc.budgetIndicator(
            ourFraction: _ours,
            theirFraction: _theirs,
            isWilted: _wilted,
            variant: BudgetIndicatorVariant.detail,
          ),
        ),
        const SizedBox(height: 8),
        _labelledSlider(
          context,
          'ours',
          _ours,
          (v) => setState(() => _ours = v),
        ),
        _labelledSlider(
          context,
          'peer',
          _theirs,
          (v) => setState(() => _theirs = v),
        ),
        Row(
          children: [
            Text('wilted / locked', style: context.wk.body),
            const Spacer(),
            Switch(
              value: _wilted,
              onChanged: (v) => setState(() => _wilted = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _groupBudgetSection(BuildContext context) {
    return _card(
      context,
      'Group budget  ·  groupBudgetIndicator',
      'one slice per member + empty lane slots',
      [
        Center(
          child: context.wkc.groupBudgetIndicator(
            members: const [
              MemberBudget(fraction: 0.85, isSelf: true),
              MemberBudget(fraction: 0.5, isHost: true),
              MemberBudget(fraction: 0.3),
              MemberBudget(fraction: 0.0, isWilted: true),
            ],
            emptySlots: 2,
          ),
        ),
      ],
    );
  }

  Widget _badgesSection(BuildContext context) {
    return _card(context, 'Status badges  ·  statusBadge', null, [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final kind in StatusBadgeKind.values)
            context.wkc.statusBadge(context, kind),
        ],
      ),
    ]);
  }

  static const _demoPin = '123456';

  void _openPin(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: WiltkeyThemeRegistry.byId(_themeId).build(),
          child: PinLockScreen(
            onVerify: (pin) async {
              final ok = pin == _demoPin;
              if (ok) navigator.pop(); // unlock bloom plays over the showcase
              return ok;
            },
            onReset: () {
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Reset / self-destruct (no-op in showcase)'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _playUnlock(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final wkc = context.wkc;
    // The root overlay only sees MaterialApp.theme (unset here); carry the
    // selected theme onto the entry so the bloom resolves its tokens.
    final themeData = Theme.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Theme(
          data: themeData,
          child: wkc.unlockTransition(onDone: () => entry.remove()),
        ),
      ),
    );
    overlay.insert(entry);
  }

  void _playNuke(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final wkc = context.wkc;
    final themeData = Theme.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Theme(
          data: themeData,
          child: wkc.nukeOverlay(onDone: () => entry.remove()),
        ),
      ),
    );
    overlay.insert(entry);
  }

  Widget _pinSection(BuildContext context) {
    return _card(
      context,
      'PIN lock screen  ·  PinLockScreen',
      'Opens the real screen in the selected theme. Garden shows the entry flower '
          '(a petal per digit) + sap-green key pulse. Demo PIN $_demoPin unlocks '
          '(plays the unlock bloom over this screen); other digits shake; 5 misses '
          'fires the (stubbed) reset.',
      [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _miniBtn(context, 'Open PIN screen', () => _openPin(context)),
            _miniBtn(context, 'Play unlock bloom', () => _playUnlock(context)),
          ],
        ),
      ],
    );
  }

  Widget _nukeSection(BuildContext context) {
    return _card(
      context,
      'Nuke overlay  ·  nukeOverlay',
      'Self-destruct sequence. Garden rots to brown while a flower greys and sheds '
          'its petals; cyberpunk glitches to a "data purged" wipe. Plays full-screen.',
      [
        Align(
          alignment: Alignment.centerLeft,
          child: _miniBtn(
            context,
            'Play nuke overlay',
            () => _playNuke(context),
            tone: context.wk.danger,
          ),
        ),
      ],
    );
  }

  Widget _pairingProgressSection(BuildContext context) {
    final t = context.wk;
    final visual = context.wkc.syncVisual(
      state: _pairState,
      progress: _progress,
    );
    return _card(
      context,
      'Pairing vine→bloom  ·  syncVisual(connect/transfer/success)',
      'Garden: vines grow toward the centre as progress climbs, then bloom + burst '
          'on success. Try jumping the slider (10→33→60→90→100) to feel the '
          'smoothing. Cyberpunk keeps its card, so it shows empty here.',
      [
        Wrap(
          spacing: 8,
          children: [
            for (final s in const [
              SyncVisualState.connecting,
              SyncVisualState.transferring,
              SyncVisualState.success,
            ])
              ChoiceChip(
                label: Text(s.name),
                selected: _pairState == s,
                selectedColor: t.action.withValues(alpha: 0.2),
                onSelected: (_) => setState(() => _pairState = s),
              ),
          ],
        ),
        const SizedBox(height: 12),
        visual is SizedBox
            ? Container(
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
                child: Text(
                  '(empty — cyberpunk keeps its own card)',
                  style: t.bodySecondary,
                ),
              )
            : visual,
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in const [0.10, 0.33, 0.60, 0.90, 1.0])
              _miniBtn(
                context,
                '${(p * 100).round()}%',
                () => setState(() => _progress = p),
              ),
          ],
        ),
        _labelledSlider(
          context,
          'progress',
          _progress,
          (v) => setState(() => _progress = v),
        ),
      ],
    );
  }

  // ---- helpers -------------------------------------------------------------

  Widget _card(
    BuildContext context,
    String title,
    String? subtitle,
    List<Widget> children,
  ) {
    final t = context.wk;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: t.body.copyWith(fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: t.bodySecondary),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _miniBtn(
    BuildContext context,
    String label,
    VoidCallback onTap, {
    Color? tone,
  }) {
    final t = context.wk;
    final c = tone ?? t.action;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: c.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusControl),
        ),
      ),
      child: Text(label, style: t.body.copyWith(color: c, fontSize: 13)),
    );
  }

  Widget _labelledSlider(
    BuildContext context,
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final t = context.wk;
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label, style: t.bodySecondary)),
        Expanded(
          child: Slider(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
