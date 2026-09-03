import 'package:flutter/material.dart';
import '../theme/wk.dart';
import '../build_flavor.dart';
import '../../l10n/app_localizations.dart';
import 'update_models.dart';
import 'update_service.dart';

/// Fullscreen non-dismissible gate displayed when a mandatory / forced update is required.
class ForcedUpdateScreen extends StatefulWidget {
  final UpdateInfo info;

  const ForcedUpdateScreen({
    super.key,
    required this.info,
  });

  @override
  State<ForcedUpdateScreen> createState() => _ForcedUpdateScreenState();
}

class _ForcedUpdateScreenState extends State<ForcedUpdateScreen> {
  bool _isChecking = false;

  Future<void> _checkAgain() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    await UpdateService.instance.checkForUpdates(force: true);
    if (!mounted) return;
    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final targetRelease = widget.info.releases.isNotEmpty ? widget.info.releases.first : null;
    final currentBuild = UpdateService.instance.currentBuildNumber;
    final currentVersion = UpdateService.instance.currentVersionName;
    final targetBuild = widget.info.effectiveLatestBuild(isPlay: kPlayStore);
    final targetVersion = widget.info.latestVersion;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 1),

                // Glowing Shield / Update Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: t.action.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.action.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: t.action.withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.system_security_update_good,
                      color: t.action,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Titles
                Text(
                  t.uppercaseLabels
                      ? l10n.forcedUpdateTitle.toUpperCase()
                      : l10n.forcedUpdateTitle,
                  style: t.screenTitle.copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.forcedUpdateSubtitle,
                  style: t.bodySecondary.copyWith(fontSize: 13.5, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // Version Badge Comparison
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(t.radiusControl),
                      border: Border.all(color: t.border, width: t.borderWidth),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'v$currentVersion ($currentBuild)',
                          style: t.dataMono.copyWith(fontSize: 11, color: t.textTertiary),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 12, color: t.action),
                        ),
                        Text(
                          'v$targetVersion ($targetBuild)',
                          style: t.dataMono.copyWith(
                            fontSize: 11,
                            color: t.action,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // What's New & Highlights Card
                if (targetRelease != null && targetRelease.highlights.isNotEmpty)
                  Expanded(
                    flex: 6,
                    child: Container(
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
                              Icon(Icons.auto_awesome, size: 15, color: t.action),
                              const SizedBox(width: 8),
                              Text(
                                t.uppercaseLabels
                                    ? l10n.forcedUpdateWhatsNew.toUpperCase()
                                    : l10n.forcedUpdateWhatsNew,
                                style: t.sectionLabel.copyWith(color: t.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: t.border, height: 1),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: targetRelease.highlights.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3.0, right: 8),
                                      child: Icon(Icons.check_circle_outline, color: t.action, size: 15),
                                    ),
                                    Expanded(
                                      child: Text(
                                        targetRelease.highlights[i],
                                        style: t.body.copyWith(fontSize: 13, height: 1.35),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Spacer(flex: 3),

                const SizedBox(height: 16),

                // Security notice banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(t.radiusControl),
                    border: Border.all(
                      color: t.warning.withValues(alpha: 0.3),
                      width: t.borderWidth,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security, color: t.warning, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.forcedUpdateSecurityNotice,
                          style: t.bodySecondary.copyWith(
                            fontSize: 11.5,
                            color: t.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Primary "Update Now" Action Button
                ElevatedButton.icon(
                  onPressed: () => UpdateService.instance.openDownloadUrl(),
                  icon: Icon(Icons.download, color: t.onAction, size: 20),
                  label: Text(
                    t.uppercaseLabels
                        ? l10n.forcedUpdateAction.toUpperCase()
                        : l10n.forcedUpdateAction,
                    style: t.body.copyWith(
                      color: t.onAction,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.action,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Secondary "Check Again" Action Button
                TextButton(
                  onPressed: _isChecking ? null : _checkAgain,
                  child: _isChecking
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.action,
                          ),
                        )
                      : Text(
                          l10n.forcedUpdateCheckAgain,
                          style: t.bodySecondary.copyWith(
                            fontSize: 13,
                            color: t.action,
                          ),
                        ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
