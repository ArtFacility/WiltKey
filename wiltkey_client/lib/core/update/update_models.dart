/// Data models representing remote update information and release notes fetched
/// from https://wiltkey.org/patchnotes.json.
class AppRelease {
  final String version;
  final int build;
  final String? date;
  final String title;
  final List<String> highlights;

  const AppRelease({
    required this.version,
    required this.build,
    this.date,
    required this.title,
    required this.highlights,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    return AppRelease(
      version: json['version'] as String? ?? '',
      build: json['build'] as int? ?? 0,
      date: json['date'] as String?,
      title: json['title'] as String? ?? '',
      highlights: (json['highlights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'build': build,
        if (date != null) 'date': date,
        'title': title,
        'highlights': highlights,
      };
}

class UpdateInfo {
  final String latestVersion;
  final int latestBuild;
  final int? latestBuildPlay;
  final int? latestBuildFoss;
  final int minSupportedBuild;
  final int? minSupportedBuildPlay;
  final int? minSupportedBuildFoss;
  final String updateType; // 'flexible' | 'immediate' | 'forced'
  final String? releaseDate;
  final String downloadUrlFoss;
  final String downloadUrlPlay;
  final String websiteUrl;
  final List<AppRelease> releases;

  const UpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    this.latestBuildPlay,
    this.latestBuildFoss,
    required this.minSupportedBuild,
    this.minSupportedBuildPlay,
    this.minSupportedBuildFoss,
    this.updateType = 'flexible',
    this.releaseDate,
    required this.downloadUrlFoss,
    required this.downloadUrlPlay,
    this.websiteUrl = 'https://wiltkey.org',
    this.releases = const [],
  });

  /// Returns the target latest build number for the given flavor.
  int effectiveLatestBuild({bool isPlay = false}) {
    if (isPlay && latestBuildPlay != null && latestBuildPlay! > 0) {
      return latestBuildPlay!;
    }
    if (!isPlay && latestBuildFoss != null && latestBuildFoss! > 0) {
      return latestBuildFoss!;
    }
    return latestBuild;
  }

  /// Returns the minimum supported build number for the given flavor.
  int effectiveMinSupportedBuild({bool isPlay = false}) {
    if (isPlay && minSupportedBuildPlay != null && minSupportedBuildPlay! > 0) {
      return minSupportedBuildPlay!;
    }
    if (!isPlay && minSupportedBuildFoss != null && minSupportedBuildFoss! > 0) {
      return minSupportedBuildFoss!;
    }
    return minSupportedBuild;
  }

  /// Checks whether an update is available for the given current build.
  bool isUpdateAvailable(int currentBuild, {bool isPlay = false}) =>
      effectiveLatestBuild(isPlay: isPlay) > currentBuild;

  /// Checks whether an update is mandatory / forced / immediate.
  bool isImmediateUpdate(int currentBuild, {bool isPlay = false}) {
    if (!isUpdateAvailable(currentBuild, isPlay: isPlay)) return false;
    final isForcedType = updateType == 'immediate' || updateType == 'forced';
    final minBuild = effectiveMinSupportedBuild(isPlay: isPlay);
    final belowMin = minBuild > 0 && currentBuild < minBuild;
    return isForcedType || belowMin;
  }

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latest_version'] as String? ?? '',
      latestBuild: json['latest_build'] as int? ?? 0,
      latestBuildPlay: json['latest_build_play'] as int?,
      latestBuildFoss: json['latest_build_foss'] as int?,
      minSupportedBuild: json['min_supported_build'] as int? ?? 1,
      minSupportedBuildPlay: json['min_supported_build_play'] as int?,
      minSupportedBuildFoss: json['min_supported_build_foss'] as int?,
      updateType: (json['update_type'] as String? ?? 'flexible').toLowerCase(),
      releaseDate: json['release_date'] as String?,
      downloadUrlFoss: json['download_url_foss'] as String? ??
          'https://github.com/ArtFacility/WiltKey/releases/latest',
      downloadUrlPlay: json['download_url_play'] as String? ??
          'https://play.google.com/store/apps/details?id=xyz.artfacility.wiltkey',
      websiteUrl: json['website_url'] as String? ?? 'https://wiltkey.org',
      releases: (json['releases'] as List<dynamic>?)
              ?.map((e) => AppRelease.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
