import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../build_flavor.dart';
import '../state.dart';
import '../models.dart';
import '../theme/wk.dart';
import '../../l10n/app_localizations.dart';
import 'update_models.dart';

/// Service managing remote version checks, patchnotes loading, and in-app update prompts.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String kPatchnotesUrl = 'https://wiltkey.org/patchnotes.json';
  static const String _kPrefLastCheckTime = 'wk_last_update_check_ms';
  static const String _kPrefLastLoggedBuild = 'wk_last_logged_update_build';

  UpdateInfo? _cachedInfo;
  int _currentBuildNumber = 0;
  String _currentVersionName = '';
  bool _isChecking = false;

  UpdateInfo? get cachedInfo => _cachedInfo;
  int get currentBuildNumber => _currentBuildNumber;
  String get currentVersionName => _currentVersionName;
  bool get isChecking => _isChecking;

  /// Initializes local build metadata from package_info_plus.
  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersionName = info.version;
      _currentBuildNumber = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {}
  }

  /// Checks whether an update is available based on cached or freshly fetched info.
  bool get isUpdateAvailable {
    if (_cachedInfo == null || _currentBuildNumber <= 0) return false;
    return _cachedInfo!.isUpdateAvailable(_currentBuildNumber);
  }

  /// Checks whether an update is mandatory / immediate.
  bool get isImmediateUpdate {
    if (_cachedInfo == null || _currentBuildNumber <= 0) return false;
    return _cachedInfo!.isImmediateUpdate(_currentBuildNumber);
  }

  /// Fetches update info from https://wiltkey.org/patchnotes.json.
  /// If [force] is false, throttles requests to at most once every 12 hours.
  Future<UpdateInfo?> checkForUpdates({bool force = false}) async {
    if (_isChecking) return _cachedInfo;
    if (_currentBuildNumber <= 0) await init();

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastCheck = prefs.getInt(_kPrefLastCheckTime) ?? 0;

    // Throttle to 12 hours unless forced
    if (!force && (now - lastCheck) < const Duration(hours: 12).inMilliseconds && _cachedInfo != null) {
      return _cachedInfo;
    }

    _isChecking = true;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);

    try {
      UpdateInfo? updateInfo;

      // 1. Primary: check wiltkey.org/patchnotes.json
      try {
        final uri = Uri.parse(kPatchnotesUrl);
        final request = await client.getUrl(uri);
        final response = await request.close();

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          updateInfo = UpdateInfo.fromJson(json);
        }
      } catch (_) {
        // Fall through to GitHub releases
      }

      // 2. Secondary / FOSS fallback: check GitHub Releases API (ignoring server tags)
      if (updateInfo == null || !updateInfo.isUpdateAvailable(_currentBuildNumber)) {
        final ghInfo = await _checkGitHubReleases(client);
        if (ghInfo != null &&
            (updateInfo == null || ghInfo.latestBuild > updateInfo.latestBuild)) {
          updateInfo = ghInfo;
        }
      }

      if (updateInfo != null) {
        _cachedInfo = updateInfo;
        await prefs.setInt(_kPrefLastCheckTime, now);

        // Check if an update event should be logged to Dashboard Events
        if (updateInfo.isUpdateAvailable(_currentBuildNumber)) {
          final lastLogged = prefs.getInt(_kPrefLastLoggedBuild) ?? 0;
          if (lastLogged < updateInfo.latestBuild) {
            _logUpdateEvent(updateInfo);
            await prefs.setInt(_kPrefLastLoggedBuild, updateInfo.latestBuild);
          }
        }
        return updateInfo;
      }
    } catch (_) {
      // Network failure / offline: fail gracefully without crashing
    } finally {
      client.close();
      _isChecking = false;
    }
    return _cachedInfo;
  }

  /// Parses GitHub releases, filtering out `-server` tags and extracting build numbers.
  Future<UpdateInfo?> _checkGitHubReleases(HttpClient client) async {
    try {
      final uri = Uri.parse('https://api.github.com/repos/ArtFacility/WiltKey/releases?per_page=10');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'WiltKey-Android-Client');
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List<dynamic>;
        return parseGitHubReleases(list);
      }
    } catch (_) {}
    return null;
  }

  /// Extracted pure parser for GitHub releases (public for testing).
  static UpdateInfo? parseGitHubReleases(List<dynamic> releases) {
    // Regex matches e.g. "v1.0.1-10", "v1.3.5-12", "v1.3.5+12", or "v1.3.5"
    final tagRegex = RegExp(r'^v?(\d+\.\d+\.\d+)(?:[-+](\d+))?$');

    for (final item in releases) {
      if (item is! Map<String, dynamic>) continue;
      final tagName = (item['tag_name'] as String? ?? '').trim();
      final isDraft = item['draft'] as bool? ?? false;
      final isPrerelease = item['prerelease'] as bool? ?? false;

      // Filter out server releases (e.g. "v1.3.5-server") and drafts
      if (isDraft || tagName.endsWith('-server') || tagName.contains('server')) {
        continue;
      }

      final match = tagRegex.firstMatch(tagName);
      if (match != null) {
        final versionStr = match.group(1)!;
        final buildStr = match.group(2);
        final buildNum = buildStr != null ? (int.tryParse(buildStr) ?? 0) : 0;

        String? downloadUrl;
        final assets = item['assets'] as List<dynamic>?;
        if (assets != null) {
          for (final asset in assets) {
            if (asset is Map<String, dynamic>) {
              final name = asset['name'] as String? ?? '';
              if (name.endsWith('.apk')) {
                downloadUrl = asset['browser_download_url'] as String?;
                break;
              }
            }
          }
        }
        downloadUrl ??= item['html_url'] as String? ?? 'https://github.com/ArtFacility/WiltKey/releases/latest';

        final releaseTitle = (item['name'] as String?)?.isNotEmpty == true
            ? item['name'] as String
            : 'WiltKey v$versionStr';
        final releaseBody = item['body'] as String? ?? '';
        final highlights = releaseBody
            .split('\n')
            .map((l) => l.trim().replaceAll(RegExp(r'^[-*]\s*'), ''))
            .where((l) => l.isNotEmpty && !l.startsWith('#'))
            .take(6)
            .toList();

        return UpdateInfo(
          latestVersion: versionStr,
          latestBuild: buildNum,
          minSupportedBuild: 1,
          downloadUrlFoss: downloadUrl,
          downloadUrlPlay: 'https://play.google.com/store/apps/details?id=xyz.artfacility.wiltkey',
          releases: [
            AppRelease(
              version: versionStr,
              build: buildNum,
              date: item['published_at'] as String?,
              title: releaseTitle,
              highlights: highlights,
            ),
          ],
        );
      }
    }
    return null;
  }

  void _logUpdateEvent(UpdateInfo info) {
    final appState = AppState();
    final eventId = 'update_v${info.latestBuild}';

    appState.logEvent(
      id: eventId,
      type: 'update_available',
      title: 'WiltKey ${info.latestVersion}',
      body: info.releases.isNotEmpty
          ? info.releases.first.title
          : 'A new version of WiltKey is available to download.',
    );
  }

  /// Opens the download URL (Google Play on Play builds, GitHub on FOSS builds).
  Future<bool> openDownloadUrl() async {
    final urlStr = kPlayStore
        ? (_cachedInfo?.downloadUrlPlay ?? 'https://play.google.com/store/apps/details?id=xyz.artfacility.wiltkey')
        : (_cachedInfo?.downloadUrlFoss ?? 'https://github.com/ArtFacility/WiltKey/releases/latest');

    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Displays the "What's New in WiltKey" bottom sheet modal.
  static void showWhatsNewSheet(BuildContext context, {AppRelease? release}) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final info = instance._cachedInfo;
    final targetRelease = release ??
        (info != null && info.releases.isNotEmpty ? info.releases.first : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard * 1.5)),
        side: BorderSide(color: t.border, width: t.borderWidth),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header with icon and version tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: t.action.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                      child: Icon(Icons.auto_awesome, color: t.action, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            targetRelease != null
                                ? 'WiltKey ${targetRelease.version}'
                                : 'WiltKey Updates',
                            style: t.screenTitle.copyWith(fontSize: 18),
                          ),
                          if (targetRelease != null && targetRelease.title.isNotEmpty)
                            Text(
                              targetRelease.title,
                              style: t.bodySecondary.copyWith(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    if (targetRelease != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.surface,
                          border: Border.all(color: t.border, width: t.borderWidth),
                          borderRadius: BorderRadius.circular(t.radiusPill),
                        ),
                        child: Text(
                          'v${targetRelease.version}',
                          style: t.dataMono.copyWith(fontSize: 11, color: t.action),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: t.border, height: 1),
                const SizedBox(height: 16),

                // Highlights list
                if (targetRelease != null && targetRelease.highlights.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: targetRelease.highlights.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final item = targetRelease.highlights[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0, right: 10),
                              child: Icon(Icons.check_circle_outline, color: t.action, size: 16),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: t.body.copyWith(fontSize: 13, height: 1.35),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No release notes available offline. Check wiltkey.org/patchnotes.html for details.',
                      style: t.bodySecondary,
                    ),
                  ),

                const SizedBox(height: 20),

                // Download / Update Action Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    instance.openDownloadUrl();
                  },
                  icon: Icon(Icons.download, color: t.onAction, size: 18),
                  label: Text(
                    t.uppercaseLabels ? 'DOWNLOAD UPDATE' : 'Download Update',
                    style: t.body.copyWith(
                      color: t.onAction,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.action,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
