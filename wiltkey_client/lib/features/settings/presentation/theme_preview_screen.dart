import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/entitlements/entitlement_service.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_registry.dart';
import '../../../core/theme/wiltkey_components.dart';
import '../../../core/theme/wk.dart';
import '../../shop/presentation/shop_screen.dart';

/// A full-screen, fully LIVE preview of one theme: sample chat-list rows, a
/// sample conversation, the status badges, the pin/sync components, and
/// buttons that play the theme's real unlock / self-destruct overlays.
///
/// Everything is rendered inside `Theme(data: descriptor.build())`, so it uses
/// the candidate theme's actual tokens + component factory — never screenshots
/// — and therefore can't go stale when a theme is tuned. Works for every
/// registered theme (base or premium); the bottom CTA adapts: apply it, buy it
/// in the Shop (Play), or the "Play exclusive" note (FOSS).
class ThemePreviewScreen extends StatefulWidget {
  final WiltkeyThemeDescriptor descriptor;
  const ThemePreviewScreen({super.key, required this.descriptor});

  @override
  State<ThemePreviewScreen> createState() => _ThemePreviewScreenState();
}

class _ThemePreviewScreenState extends State<ThemePreviewScreen> {
  OverlayEntry? _fx;

  @override
  void dispose() {
    _fx?.remove();
    _fx = null;
    super.dispose();
  }

  /// Plays the theme's unlock or nuke overlay in the ROOT overlay. The root
  /// overlay doesn't carry our candidate `Theme`, so it's captured and
  /// re-applied around the effect (see THEMING.md §3.1).
  void _playEffect(BuildContext themedContext, {required bool nuke}) {
    if (_fx != null) return; // one at a time
    final overlay = Overlay.of(themedContext, rootOverlay: true);
    final themeData = Theme.of(themedContext);
    final wkc = themedContext.wkc;
    void done() {
      _fx?.remove();
      _fx = null;
    }

    final entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Theme(
          data: themeData,
          child: Material(
            type: MaterialType.transparency,
            child: nuke
                ? wkc.nukeOverlay(onDone: done)
                : wkc.unlockTransition(onDone: done),
          ),
        ),
      ),
    );
    _fx = entry;
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.descriptor;
    return Theme(
      data: d.build(),
      child: Builder(
        builder: (context) {
          final t = context.wk;
          final l10n = AppLocalizations.of(context)!;
          final locked =
              d.premium &&
              !EntitlementService.instance.premiumThemeUnlocked(d.id);
          final canBuy = EntitlementService.instance.billingAvailable;

          return Scaffold(
            backgroundColor: t.bg,
            appBar: AppBar(
              backgroundColor: t.bg,
              elevation: 0,
              iconTheme: IconThemeData(color: t.textPrimary),
              title: Text(
                t.uppercaseLabels
                    ? d.localizedName(context).toUpperCase()
                    : d.localizedName(context),
              ),
            ),
            body: context.wkc.ambientBackground(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(d.localizedTagline(context), style: t.bodySecondary),
                  const SizedBox(height: 18),

                  // --- Sample chat list ---
                  context.wkc.screenTitle(
                    context,
                    l10n.themePreviewSectionDashboard,
                  ),
                  const SizedBox(height: 10),
                  _sampleRow(
                    context,
                    name: 'Mateusz',
                    last: l10n.themePreviewMsgThem2,
                    ours: 0.4,
                    theirs: 0.38,
                    unread: 2,
                  ),
                  _sampleRow(
                    context,
                    name: 'Réka',
                    last: l10n.themePreviewRowPhoto,
                    ours: 0.09,
                    theirs: 0.2,
                  ),
                  _sampleRow(
                    context,
                    name: 'Domi',
                    last: l10n.themePreviewRowLost,
                    ours: 0,
                    theirs: 0,
                    wilted: true,
                  ),
                  const SizedBox(height: 8),
                  // A whole-group budget readout + the badge set.
                  context.wkc.groupBudgetIndicator(
                    members: const [
                      MemberBudget(fraction: 0.8, isSelf: true, keyHash: 'k1'),
                      MemberBudget(fraction: 0.55, isHost: true, keyHash: 'k2'),
                      MemberBudget(fraction: 0.3, keyHash: 'k3'),
                    ],
                    emptySlots: 2,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      context.wkc.statusBadge(context, StatusBadgeKind.secured),
                      context.wkc.statusBadge(context, StatusBadgeKind.group),
                      context.wkc.statusBadge(context, StatusBadgeKind.wilted),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // --- Sample conversation ---
                  context.wkc.screenTitle(context, l10n.themePreviewSectionChat),
                  const SizedBox(height: 10),
                  _bubble(context, l10n.themePreviewMsgThem1, me: false),
                  _bubble(context, l10n.themePreviewMsgMe, me: true),
                  _bubble(context, l10n.themePreviewMsgThem2, me: false),
                  // A voice-message scrubber, mid-playback.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: t.bubbleThem,
                        border: Border.all(
                          color: t.bubbleThemBorder,
                          width: t.borderWidth,
                        ),
                        borderRadius: BorderRadius.circular(t.radiusCard),
                      ),
                      child: SizedBox(
                        width: 190,
                        height: 30,
                        child: context.wkc.voiceScrubber(
                          progress: 0.45,
                          isPlaying: false,
                          seed: 7,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // --- Special components + playable effects ---
                  context.wkc.screenTitle(
                    context,
                    l10n.themePreviewSectionEffects,
                  ),
                  const SizedBox(height: 12),
                  context.wkc.pinProgress(
                    context,
                    entered: 4,
                    length: 6,
                    error: false,
                  ),
                  const SizedBox(height: 14),
                  context.wkc.syncVisual(
                    state: SyncVisualState.scanning,
                    blips: const [
                      SyncBlip(
                        id: 'demo-near',
                        strength: 0.85,
                        angle: 0.7,
                        isWiltkey: true,
                        isNear: true,
                      ),
                      SyncBlip(
                        id: 'demo-far',
                        strength: 0.45,
                        angle: 2.4,
                        isWiltkey: true,
                      ),
                      SyncBlip(id: 'demo-noise', strength: 0.25, angle: 4.1),
                      SyncBlip(
                        id: 'demo-group',
                        strength: 0.6,
                        angle: 5.3,
                        isGroup: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _effectButton(
                          context,
                          icon: Icons.lock_open,
                          label: l10n.themePreviewPlayUnlock,
                          onPressed: () => _playEffect(context, nuke: false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _effectButton(
                          context,
                          icon: Icons.local_fire_department_outlined,
                          label: l10n.themePreviewPlayNuke,
                          onPressed: () => _playEffect(context, nuke: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _cta(context, l10n, locked: locked, canBuy: canBuy),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cta(
    BuildContext context,
    AppLocalizations l10n, {
    required bool locked,
    required bool canBuy,
  }) {
    final t = context.wk;
    if (!locked) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.action,
          foregroundColor: t.onAction,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusControl),
          ),
        ),
        onPressed: () {
          ThemeController().setTheme(widget.descriptor.id);
          Navigator.pop(context);
        },
        child: Text(
          t.uppercaseLabels
              ? l10n.themePreviewApply.toUpperCase()
              : l10n.themePreviewApply,
        ),
      );
    }
    if (canBuy) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.action,
          foregroundColor: t.onAction,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusControl),
          ),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        ),
        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
        label: Text(
          t.uppercaseLabels
              ? l10n.themePreviewGetInShop.toUpperCase()
              : l10n.themePreviewGetInShop,
        ),
      );
    }
    // FOSS: a permanent Play-exclusive preview.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: t.border, width: t.borderWidth),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 14, color: t.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l10n.themePickerPlayExclusive,
              style: t.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _effectButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final t = context.wk;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.action,
        side: BorderSide(color: t.action, width: t.borderWidth),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusControl),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        t.uppercaseLabels ? label.toUpperCase() : label,
        textAlign: TextAlign.center,
        style: t.dataMono.copyWith(color: t.action, fontSize: 9),
      ),
    );
  }

  Widget _sampleRow(
    BuildContext context, {
    required String name,
    required String last,
    required double ours,
    required double theirs,
    int unread = 0,
    bool wilted = false,
  }) {
    final t = context.wk;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: wilted ? Colors.transparent : t.surface,
        border: Border.all(
          color: wilted ? t.budgetWilted.withValues(alpha: 0.4) : t.border,
          width: t.borderWidth,
        ),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Row(
        children: [
          PixelArtAvatar(
            hexString: PixelArtAvatar.generateIdenticon('preview-$name'),
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: t.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySecondary.copyWith(
                    color: wilted ? t.budgetWilted : null,
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.action,
                borderRadius: BorderRadius.circular(t.radiusPill),
              ),
              child: Text(
                '$unread',
                style: t.dataMono.copyWith(
                  color: t.onAction,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          context.wkc.budgetIndicator(
            ourFraction: ours,
            theirFraction: theirs,
            isWilted: wilted,
            split: true,
            variant: BudgetIndicatorVariant.listRow,
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, String text, {required bool me}) {
    final t = context.wk;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 270),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: me ? t.bubbleMe : t.bubbleThem,
          border: Border.all(
            color: me ? t.bubbleMeBorder : t.bubbleThemBorder,
            width: t.borderWidth,
          ),
          borderRadius: BorderRadius.circular(t.radiusCard),
        ),
        child: Text(
          text,
          style: t.body.copyWith(color: me ? t.bubbleMeText : t.textPrimary),
        ),
      ),
    );
  }
}
