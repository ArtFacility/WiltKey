import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/entitlements/entitlement_service.dart';
import 'package:wiltkey_client/core/network/integrity_attestation_manager.dart';
import 'package:wiltkey_client/core/pixel_art_avatar.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/theme/widgets/client_integrity_badge.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/theme/wk.dart';

/// Dedicated settings view for WiltKey Social accounts, weekly byte quotas, and signed wipe actions.
class WiltkeySocialSettingsTab extends StatefulWidget {
  const WiltkeySocialSettingsTab({super.key});

  @override
  State<WiltkeySocialSettingsTab> createState() => _WiltkeySocialSettingsTabState();
}

class _WiltkeySocialSettingsTabState extends State<WiltkeySocialSettingsTab> {
  final AppState _appState = AppState();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _appState.refreshSocialBudget();
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatResetTime(int seconds) {
    if (seconds <= 0) return 'Resetting now';
    final days = seconds ~/ (24 * 3600);
    final hours = (seconds % (24 * 3600)) ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (days > 0) return '$days days $hours hrs';
    if (hours > 0) return '$hours hrs $mins mins';
    return '$mins mins';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final budget = _appState.socialBudget;
    final isPlus = EntitlementService.instance.plusActive;
    final attestation = IntegrityAttestationManager.instance.cachedCert;
    final badgeType = attestation != null
        ? (isPlus ? ClientBadgeType.playPlus : ClientBadgeType.playOfficial)
        : ClientBadgeType.tinkerer;

    return RefreshIndicator(
      color: t.action,
      backgroundColor: t.surface,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // 1. User Identity Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.radiusCard),
              border: Border.all(color: t.border, width: t.borderWidth),
            ),
            child: Row(
              children: [
                PixelArtAvatar(
                  hexString: _appState.profileImageB64,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _appState.effectiveDeviceName,
                              style: t.screenTitle.copyWith(fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ClientIntegrityBadge(
                            badgeType: badgeType,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${_appState.userId.length > 16 ? '${_appState.userId.substring(0, 8)}...${_appState.userId.substring(_appState.userId.length - 8)}' : _appState.userId}',
                        style: t.dataMono.copyWith(fontSize: 11, color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 18, color: t.action),
                  tooltip: 'Copy Public Identifier',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _appState.userId));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: t.surface,
                        content: Text('Identifier copied to clipboard', style: t.body),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Weekly Quota & Server Budget Gauge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.radiusCard),
              border: Border.all(color: t.border, width: t.borderWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage_outlined, size: 18, color: t.action),
                    const SizedBox(width: 8),
                    Text(
                      t.uppercaseLabels ? 'WEEKLY SOCIAL QUOTA' : 'Weekly Social Quota',
                      style: t.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPlus ? t.action.withValues(alpha: 0.15) : t.border.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(t.radiusPill),
                      ),
                      child: Text(
                        isPlus ? 'PLUS: 100 MB' : 'FREE: 10 MB',
                        style: t.badgeLabel.copyWith(
                          color: isPlus ? t.action : t.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Linear Progress Meter
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (budget != null && budget.bytesUsed > 0)
                        ? (budget.usedFraction < 0.015 ? 0.015 : budget.usedFraction)
                        : 0.0,
                    minHeight: 8,
                    backgroundColor: t.bg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      (budget?.usedFraction ?? 0.0) > 0.85 ? t.danger : t.action,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Used: ${AppState.formatBytes(budget?.bytesUsed ?? 0)}',
                      style: t.dataMono.copyWith(fontSize: 12, color: t.textSecondary),
                    ),
                    Text(
                      'Remaining: ${AppState.formatBytes(budget?.remainingBytes ?? (10 * 1024 * 1024))}',
                      style: t.dataMono.copyWith(
                        fontSize: 12,
                        color: (budget?.remainingBytes ?? 1) == 0 ? t.danger : t.positive,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: t.border.withValues(alpha: 0.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: t.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      'Quota auto-resets in: ${_formatResetTime(budget?.resetInSeconds ?? (7 * 24 * 3600))}',
                      style: t.dataMono.copyWith(fontSize: 11, color: t.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Social Feature Preferences
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.radiusCard),
              border: Border.all(color: t.border, width: t.borderWidth),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: t.action,
                  title: Text(
                    l10n.settingsSocialAccountTitle ?? 'WiltKey Social Account',
                    style: t.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n.settingsSocialAccountSubtitle ?? 'Allow server-assisted 24h stories and discovery',
                    style: t.bodySecondary.copyWith(fontSize: 12),
                  ),
                  value: _appState.socialAccountEnabled,
                  onChanged: (val) async {
                    await _appState.setSocialAccountEnabled(val);
                    setState(() {});
                  },
                ),
                Divider(color: t.border, height: 1),
                SwitchListTile(
                  activeColor: t.action,
                  title: Text(
                    l10n.settingsStoriesReelTitle ?? 'Dashboard Stories Reel',
                    style: t.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n.settingsStoriesReelSubtitle ?? 'Show 24-hour stories on top of the chats tab',
                    style: t.bodySecondary.copyWith(fontSize: 12),
                  ),
                  value: _appState.storiesEnabled,
                  onChanged: _appState.socialAccountEnabled
                      ? (val) async {
                          await _appState.setStoriesEnabled(val);
                          setState(() {});
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Zero-Knowledge Privacy Architecture Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.radiusCard),
              border: Border.all(color: t.border, width: t.borderWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, size: 18, color: t.positive),
                    const SizedBox(width: 8),
                    Text(
                      t.uppercaseLabels ? 'CONTACT-KEYED ENCRYPTION' : 'Contact-Keyed Encryption',
                      style: t.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Your 24-hour wilting stories are encrypted with symmetric keys wrapped only for your verified mutual contacts. The relay server is zero-knowledge and cannot decrypt or read your posts or reactions.',
                  style: t.bodySecondary.copyWith(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. Danger Zone: Signed Data Wipe
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.danger.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(t.radiusCard),
              border: Border.all(color: t.danger.withValues(alpha: 0.3), width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.delete_forever_outlined, size: 18, color: t.danger),
                    const SizedBox(width: 8),
                    Text(
                      'Wipe All Social Data',
                      style: t.body.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: t.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Immediately deletes all your published stories, story reactions, and relay quota records from the server and local disk.',
                  style: t.bodySecondary.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('PURGE & WIPE ALL STORIES'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: t.surface,
                        title: Text('Wipe All Social Data?', style: t.screenTitle.copyWith(fontSize: 16)),
                        content: Text(
                          'This will cryptographically sign a deletion request to purge all your active stories, reactions, and server records.',
                          style: t.body,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('CANCEL', style: t.bodySecondary),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: t.danger),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('CONFIRM WIPE'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await _appState.wipeAllSocialData();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: t.surface,
                              content: Text('All social data wiped successfully', style: t.body),
                            ),
                          );
                        }
                        _refresh();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: t.surface,
                              content: Text('Wipe failed: $e', style: t.body.copyWith(color: t.danger)),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
