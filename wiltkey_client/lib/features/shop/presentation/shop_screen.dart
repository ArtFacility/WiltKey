import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

import '../../../core/cosmetics/avatar_border_registry.dart';
import '../../../core/state.dart';
import '../../../core/entitlements/billing_models.dart';
import '../../../core/entitlements/entitlement_service.dart';
import '../../../core/entitlements/product_ids.dart';
import '../../../core/pixel_palette.dart';
import '../../../core/theme/theme_registry.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';

/// Where the FOSS "Support the project" button points. Not a purchase — just an
/// external funding/info page. Update to the real donate/sponsor URL when it's live.
const String kSupportUrl = 'https://wiltkey.org';

/// Google Play's promo-code redemption entry point. Play validates the code and
/// grants the SKU to the signed-in account; the entitlement then arrives through
/// the normal Billing query (there is no in-app redeem API).
const String kPlayRedeemUrl = 'https://play.google.com/redeem?code=';

/// The shop / support screen.
///
/// Two faces, driven by [EntitlementService.billingAvailable] (i.e. [kPlayStore]):
///  - **Play build:** a tabbed storefront — palettes, themes, borders, Plus, promo.
///  - **FOSS build:** a "Support the project" page. No Google, no purchases; every
///    cosmetic is already free there, so there's nothing to sell.
///
/// The catalog is built from the **local registries** ([WkPalette.sets],
/// [WiltkeyThemeRegistry.premium]) rather than from whatever Play returns, so the
/// shop always shows its goods (with real previews) even before the SKUs exist in
/// the Play Console. Play only supplies the localized price and the purchase flow.
class ShopScreen extends StatefulWidget {
  /// Optional tab to open on (see [ShopTab]).
  final ShopTab initialTab;

  const ShopScreen({super.key, this.initialTab = ShopTab.palettes});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

/// Storefront sections, in tab order.
enum ShopTab { palettes, themes, borders, plus, promo }

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  final EntitlementService _ent = EntitlementService.instance;

  TabController? _tabController;
  bool _loading = true;
  bool _restoring = false;

  /// Play product details by product id (price/title). Empty until Play answers,
  /// and stays empty if the SKUs aren't configured yet.
  Map<String, BillingProduct> _products = const {};

  final TextEditingController _promoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ent.addListener(_onEntitlementsChanged);
    if (_ent.billingAvailable) {
      _tabController = TabController(
        length: ShopTab.values.length,
        vsync: this,
        initialIndex: widget.initialTab.index,
      );
      _loadProducts();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _ent.removeListener(_onEntitlementsChanged);
    _tabController?.dispose();
    _promoController.dispose();
    super.dispose();
  }

  void _onEntitlementsChanged() {
    if (mounted) setState(() {});
  }

  /// Every product id the shop can sell: the Plus subscription (which also
  /// carries the larger pad sizes), one per premium palette pack, one per
  /// premium theme.
  List<String> _catalogIds() => <String>[
        WkProducts.plusSubscription,
        for (final s in WkPalette.sets)
          if (s.premium && s.sku != null) s.sku!,
        for (final t in WiltkeyThemeRegistry.premium) t.sku,
      ];

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final list = await _ent.productDetails(_catalogIds());
    if (!mounted) return;
    setState(() {
      _products = {for (final p in list) p.id: p};
      _loading = false;
    });
  }

  Future<void> _buy(String productId, {required bool subscription}) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await _ent.buy(productId, subscription: subscription);
    if (!mounted) return;
    switch (result.outcome) {
      case PurchaseOutcome.pending:
        _snack(l10n.shopPurchasePendingSnack);
      case PurchaseOutcome.error:
      case PurchaseOutcome.unavailable:
        _snack(l10n.shopPurchaseFailedSnack);
      case PurchaseOutcome.purchased:
      case PurchaseOutcome.alreadyOwned:
        // Buying Plus grants server-side perks — push the token to the relay now
        // rather than waiting for the next reconnect. No-op for other SKUs / FOSS.
        if (productId == WkProducts.plusSubscription) {
          // ignore: unawaited_futures
          AppState().syncPlusEntitlement();
        }
      case PurchaseOutcome.cancelled:
        break; // Entitlement refresh drives the UI; cancel is silent.
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _restoring = true);
    await _ent.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    _snack(l10n.shopRestoredSnack);
  }

  Future<void> _redeemPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    await launchUrl(
      Uri.parse('$kPlayRedeemUrl${Uri.encodeComponent(code)}'),
      mode: LaunchMode.externalApplication,
    );
    // Play grants the SKU out-of-app; pick it up when we're focused again.
    await _ent.refresh();
  }

  Future<void> _openSupport() async {
    await launchUrl(Uri.parse(kSupportUrl), mode: LaunchMode.externalApplication);
  }

  void _snack(String message) {
    final t = context.wk;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: t.surface,
        content: Text(message, style: TextStyle(color: t.textPrimary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final isPlay = _ent.billingAvailable;
    final title = isPlay ? l10n.shopTitle : l10n.supportTitle;

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
          t.uppercaseLabels ? title.toUpperCase() : title,
          style: t.screenTitle.copyWith(fontSize: 18),
        ),
        actions: [
          if (isPlay)
            IconButton(
              tooltip: l10n.shopRestoreButton,
              icon: _restoring
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.action,
                      ),
                    )
                  : Icon(Icons.restore, color: t.action),
              onPressed: _restoring ? null : _restore,
            ),
        ],
        bottom: isPlay
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: t.action,
                labelColor: t.action,
                unselectedLabelColor: t.textTertiary,
                labelStyle: t.sectionLabel.copyWith(fontSize: 11),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    text: _tabLabel(t, l10n.shopTabPalettes),
                  ),
                  Tab(
                    icon: const Icon(Icons.color_lens_outlined, size: 18),
                    text: _tabLabel(t, l10n.shopTabThemes),
                  ),
                  Tab(
                    icon: const Icon(Icons.filter_frames_outlined, size: 18),
                    text: _tabLabel(t, l10n.shopTabBorders),
                  ),
                  Tab(
                    icon: const Icon(Icons.star_outline, size: 18),
                    text: _tabLabel(t, l10n.shopTabPlus),
                  ),
                  Tab(
                    icon: const Icon(Icons.redeem_outlined, size: 18),
                    text: _tabLabel(t, l10n.shopTabPromo),
                  ),
                ],
              )
            : null,
      ),
      body: isPlay ? _buildTabs(t, l10n) : _buildSupportPage(t, l10n),
    );
  }

  String _tabLabel(WiltkeyTokens t, String s) =>
      t.uppercaseLabels ? s.toUpperCase() : s;

  Widget _buildTabs(WiltkeyTokens t, AppLocalizations l10n) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: t.action));
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildPalettesTab(t, l10n),
        _buildThemesTab(t, l10n),
        _buildBordersTab(t, l10n),
        _buildPlusTab(t, l10n),
        _buildPromoTab(t, l10n),
      ],
    );
  }

  // --- Tab 1: colour palettes ---

  Widget _buildPalettesTab(WiltkeyTokens t, AppLocalizations l10n) {
    final packs =
        WkPalette.sets.where((s) => s.premium && s.sku != null).toList();
    if (packs.isEmpty) return _emptyState(t, l10n.shopEmptyTitle, l10n.shopEmptyBody);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(l10n.shopPalettesIntro, style: t.bodySecondary),
        const SizedBox(height: 14),
        for (final pack in packs) _paletteCard(t, l10n, pack),
      ],
    );
  }

  Widget _paletteCard(WiltkeyTokens t, AppLocalizations l10n, WkPaletteSet pack) {
    final owned = _ent.palettePackUnlocked(pack.id);
    return _productShell(
      t: t,
      l10n: l10n,
      title: pack.name,
      subtitle: l10n.shopPaletteColorCount(pack.count),
      productId: pack.sku!,
      owned: owned,
      subscription: false,
      preview: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (int i = pack.start; i < pack.end && i < WkPalette.length; i++)
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: WkPalette.colorAt(i),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: t.border, width: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Tab 2: themes ---

  Widget _buildThemesTab(WiltkeyTokens t, AppLocalizations l10n) {
    final themes = WiltkeyThemeRegistry.premium;
    if (themes.isEmpty) {
      return _emptyState(t, l10n.shopThemesEmptyTitle, l10n.shopThemesEmptyBody);
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        for (final theme in themes)
          _productShell(
            t: t,
            l10n: l10n,
            title: theme.localizedName(context),
            subtitle: theme.localizedTagline(context),
            productId: theme.sku,
            owned: _ent.premiumThemeUnlocked(theme.id),
            subscription: false,
            preview: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  _swatch(t, theme.previewSwatchA),
                  const SizedBox(width: 6),
                  _swatch(t, theme.previewSwatchB),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _swatch(WiltkeyTokens t, Color c) => Container(
        width: 34,
        height: 20,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: t.border, width: 0.5),
        ),
      );

  // --- Tab 3: avatar borders ---

  Widget _buildBordersTab(WiltkeyTokens t, AppLocalizations l10n) {
    final borders = WkAvatarBorderRegistry.all
        .where((b) => b.id != WkAvatarBorderRegistry.noneId)
        .toList();
    if (borders.isEmpty) {
      return _emptyState(t, l10n.shopBordersSoonTitle, l10n.shopBordersSoonBody);
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(l10n.shopBordersIntro, style: t.bodySecondary),
        const SizedBox(height: 14),
        for (final b in borders)
          if (b.premium)
            _productShell(
              t: t,
              l10n: l10n,
              title: b.name,
              subtitle: l10n.shopBorderSubtitle,
              productId: b.sku,
              owned: _ent.premiumBorderUnlocked(b.id),
              subscription: false,
              preview: _borderRow(t, b),
            )
          else
            _freeBorderCard(t, l10n, b),
      ],
    );
  }

  Widget _borderRow(WiltkeyTokens t, WkAvatarBorder b) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SvgPicture.asset(
          b.assetPath!,
          width: 56,
          height: 56,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const SizedBox(width: 56, height: 56),
        ),
      );

  Widget _freeBorderCard(WiltkeyTokens t, AppLocalizations l10n, WkAvatarBorder b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.positive),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b.assetPath != null)
            SvgPicture.asset(
              b.assetPath!,
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => const SizedBox(width: 44, height: 44),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name,
                    style: t.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(l10n.shopBorderSubtitle, style: t.bodySecondary),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.bg,
              border: Border.all(color: t.positive),
              borderRadius: BorderRadius.circular(t.radiusPill),
            ),
            child: Text(
              t.uppercaseLabels
                  ? l10n.shopFreeLabel.toUpperCase()
                  : l10n.shopFreeLabel,
              style: t.dataMono.copyWith(
                color: t.positive,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 4: WiltKey Plus ---

  Widget _buildPlusTab(WiltkeyTokens t, AppLocalizations l10n) {
    final product = _products[WkProducts.plusSubscription];
    final active = _ent.plusActive;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Icon(Icons.star, color: t.action, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'WiltKey Plus',
                style: t.screenTitle.copyWith(fontSize: 18),
              ),
            ),
            if (active) _ownedBadge(t, l10n, true),
          ],
        ),
        const SizedBox(height: 6),
        Text(l10n.shopPlusTagline, style: t.bodySecondary),
        const SizedBox(height: 20),
        _section(t, l10n.shopPlusBenefitsSection),
        const SizedBox(height: 10),
        _benefit(t, Icons.schedule, l10n.shopPlusBenefitHold),
        _benefit(t, Icons.cloud_upload_outlined, l10n.shopPlusBenefitFiles),
        _benefit(t, Icons.sd_storage_outlined, l10n.shopPlusBenefitPads),
        _benefit(t, Icons.favorite_outline, l10n.shopPlusBenefitSupport),
        const SizedBox(height: 24),
        if (active) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.positive),
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
            child: Row(
              children: [
                Icon(Icons.open_in_new, size: 14, color: t.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.shopManageNote, style: t.bodySecondary),
                ),
              ],
            ),
          ),
        ] else
          ElevatedButton(
            onPressed: product == null
                ? null
                : () => _buy(WkProducts.plusSubscription, subscription: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.onAction,
              disabledBackgroundColor: t.surfacePressed,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
            child: Text(
              product == null
                  ? l10n.shopPriceUnavailable
                  : '${l10n.shopSubscribeButton} · ${product.formattedPrice}',
              style: t.body.copyWith(
                color: product == null ? t.textTertiary : t.onAction,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _benefit(WiltkeyTokens t, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: t.positive),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: t.body.copyWith(height: 1.4))),
          ],
        ),
      );

  // --- Tab 5: promo code ---

  Widget _buildPromoTab(WiltkeyTokens t, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Icon(Icons.redeem, color: t.action, size: 40),
        const SizedBox(height: 16),
        Text(
          l10n.shopPromoIntro,
          style: t.body.copyWith(height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _promoController,
          textCapitalization: TextCapitalization.characters,
          style: t.dataMono.copyWith(color: t.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: l10n.shopPromoHint,
            hintStyle: t.dataMono.copyWith(color: t.textTertiary),
            filled: true,
            fillColor: t.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: t.border),
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: t.action),
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
          ),
          onSubmitted: (_) => _redeemPromo(),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _redeemPromo,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(l10n.shopPromoRedeemButton),
          style: ElevatedButton.styleFrom(
            backgroundColor: t.action,
            foregroundColor: t.onAction,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 14, color: t.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.shopPromoNote,
                style: t.bodySecondary.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- shared pieces ---

  /// One purchasable card: title, subtitle, an optional visual preview, and
  /// either an Owned badge or a Buy button carrying Play's localized price.
  Widget _productShell({
    required WiltkeyTokens t,
    required AppLocalizations l10n,
    required String title,
    required String subtitle,
    required String productId,
    required bool owned,
    required bool subscription,
    Widget? preview,
  }) {
    final product = _products[productId];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: owned ? t.positive : t.border),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: t.bodySecondary),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (owned)
                _ownedBadge(t, l10n, subscription)
              else
                ElevatedButton(
                  onPressed: product == null
                      ? null
                      : () => _buy(productId, subscription: subscription),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.action,
                    foregroundColor: t.onAction,
                    disabledBackgroundColor: t.surfacePressed,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                    ),
                  ),
                  child: Text(
                    product?.formattedPrice ?? l10n.shopPriceUnavailable,
                    style: t.dataMono.copyWith(
                      color: product == null ? t.textTertiary : t.onAction,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          ?preview,
        ],
      ),
    );
  }

  Widget _ownedBadge(
    WiltkeyTokens t,
    AppLocalizations l10n,
    bool isSubscription,
  ) {
    final label = isSubscription ? l10n.shopActiveLabel : l10n.shopOwnedLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border.all(color: t.positive),
        borderRadius: BorderRadius.circular(t.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 12, color: t.positive),
          const SizedBox(width: 4),
          Text(
            t.uppercaseLabels ? label.toUpperCase() : label,
            style: t.dataMono.copyWith(
              color: t.positive,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(WiltkeyTokens t, String title, String body) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storefront_outlined, color: t.textTertiary, size: 44),
              const SizedBox(height: 16),
              Text(
                title,
                style: t.screenTitle.copyWith(fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(body, style: t.bodySecondary, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _section(WiltkeyTokens t, String text) => Text(
        t.uppercaseLabels ? text.toUpperCase() : text,
        style: t.sectionLabel.copyWith(color: t.action),
      );

  // --- FOSS build: the support page ---

  Widget _buildSupportPage(WiltkeyTokens t, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Icon(Icons.volunteer_activism_outlined, color: t.action, size: 56),
          const SizedBox(height: 20),
          Text(
            l10n.supportIntro,
            style: t.body.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openSupport,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l10n.supportOpenButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.onAction,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_open, color: t.positive, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.supportFreeNote,
                  style: t.bodySecondary.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
