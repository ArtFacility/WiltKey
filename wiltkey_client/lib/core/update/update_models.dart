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
  final int minSupportedBuild;
  final String updateType; // 'flexible' | 'immediate'
  final String? releaseDate;
  final String downloadUrlFoss;
  final String downloadUrlPlay;
  final String websiteUrl;
  final List<AppRelease> releases;

  const UpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.minSupportedBuild,
    this.updateType = 'flexible',
    this.releaseDate,
    required this.downloadUrlFoss,
    required this.downloadUrlPlay,
    this.websiteUrl = 'https://wiltkey.org',
    this.releases = const [],
  });

  bool isUpdateAvailable(int currentBuild) => latestBuild > currentBuild;

  bool isImmediateUpdate(int currentBuild) =>
      updateType == 'immediate' || currentBuild < minSupportedBuild;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latest_version'] as String? ?? '',
      latestBuild: json['latest_build'] as int? ?? 0,
      minSupportedBuild: json['min_supported_build'] as int? ?? 1,
      updateType: json['update_type'] as String? ?? 'flexible',
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
