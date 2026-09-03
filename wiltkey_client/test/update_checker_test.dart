import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/update/update_models.dart';
import 'package:wiltkey_client/core/update/update_service.dart';

void main() {
  group('UpdateService GitHub Releases Tag Parsing Tests', () {
    test('Correctly parses client tag with build number v1.0.1-10', () {
      final sampleReleases = [
        {
          'tag_name': 'v1.0.1-10',
          'draft': false,
          'prerelease': false,
          'name': 'WiltKey 1.0.1 Release',
          'body': '- Bug fixes\n- Performance improvements',
          'html_url': 'https://github.com/ArtFacility/WiltKey/releases/tag/v1.0.1-10',
          'published_at': '2026-08-24T00:00:00Z',
          'assets': [
            {
              'name': 'app-foss-release.apk',
              'browser_download_url': 'https://github.com/ArtFacility/WiltKey/releases/download/v1.0.1-10/app-foss-release.apk',
            }
          ],
        }
      ];

      final result = UpdateService.parseGitHubReleases(sampleReleases);
      expect(result, isNotNull);
      expect(result!.latestVersion, '1.0.1');
      expect(result.latestBuild, 10);
      expect(result.downloadUrlFoss, 'https://github.com/ArtFacility/WiltKey/releases/download/v1.0.1-10/app-foss-release.apk');
      expect(result.releases.first.highlights, contains('Bug fixes'));
    });

    test('Strictly filters out and ignores server releases with -server tag', () {
      final sampleReleases = [
        {
          'tag_name': 'v1.3.5-server',
          'draft': false,
          'prerelease': false,
          'name': 'Relay Server Update',
          'body': 'Server improvements',
        },
        {
          'tag_name': 'v1.0.1-10-server',
          'draft': false,
          'prerelease': false,
          'name': 'Server Patch',
        },
        {
          'tag_name': 'v1.3.5-12',
          'draft': false,
          'prerelease': false,
          'name': 'Client 1.3.5',
          'body': '- Moai emoji\n- History pruning',
          'html_url': 'https://github.com/ArtFacility/WiltKey/releases/tag/v1.3.5-12',
        }
      ];

      final result = UpdateService.parseGitHubReleases(sampleReleases);
      expect(result, isNotNull);
      expect(result!.latestVersion, '1.3.5');
      expect(result.latestBuild, 12);
    });

    test('Handles plus build format v1.3.5+12 and plain v1.3.5', () {
      final plusFormat = [
        {
          'tag_name': 'v1.3.5+12',
          'draft': false,
          'prerelease': false,
          'name': 'Client 1.3.5+12',
        }
      ];
      final plusResult = UpdateService.parseGitHubReleases(plusFormat);
      expect(plusResult?.latestBuild, 12);
      expect(plusResult?.latestVersion, '1.3.5');

      final plainFormat = [
        {
          'tag_name': 'v1.3.5',
          'draft': false,
          'prerelease': false,
          'name': 'Client 1.3.5',
        }
      ];
      final plainResult = UpdateService.parseGitHubReleases(plainFormat);
      expect(plainResult?.latestBuild, 0);
      expect(plainResult?.latestVersion, '1.3.5');
    });
  });

  group('UpdateInfo Flavor-Awareness and Forced Updates Tests', () {
    test('Correctly identifies forced update from update_type: "forced"', () {
      final json = {
        'latest_version': '1.4.0',
        'latest_build': 30,
        'min_supported_build': 28,
        'update_type': 'forced',
        'download_url_foss': 'https://github.com/ArtFacility/WiltKey/releases/latest',
        'download_url_play': 'https://play.google.com/store/apps/details?id=xyz.artfacility.wiltkey',
      };

      final info = UpdateInfo.fromJson(json);
      expect(info.isUpdateAvailable(29), isTrue);
      expect(info.isImmediateUpdate(29), isTrue);
      expect(info.isImmediateUpdate(30), isFalse); // Already on latest build
    });

    test('Correctly identifies immediate update from update_type: "immediate"', () {
      final json = {
        'latest_version': '1.4.0',
        'latest_build': 30,
        'min_supported_build': 28,
        'update_type': 'immediate',
      };

      final info = UpdateInfo.fromJson(json);
      expect(info.isUpdateAvailable(29), isTrue);
      expect(info.isImmediateUpdate(29), isTrue);
    });

    test('Correctly enforces min_supported_build deprecation even on flexible update_type', () {
      final json = {
        'latest_version': '1.4.0',
        'latest_build': 30,
        'min_supported_build': 28,
        'update_type': 'flexible',
      };

      final info = UpdateInfo.fromJson(json);
      // Build 27 is below min_supported_build 28 -> immediate/forced
      expect(info.isImmediateUpdate(27), isTrue);
      // Build 29 is above min_supported_build 28 -> flexible (not immediate)
      expect(info.isImmediateUpdate(29), isFalse);
      expect(info.isUpdateAvailable(29), isTrue);
    });

    test('Flavor-specific build numbers prevent premature Play Store notifications', () {
      final json = {
        'latest_version': '1.4.5',
        'latest_build': 32, // FOSS build 32 is on GitHub
        'latest_build_play': 30, // Play Store is still on build 30 (under review)
        'latest_build_foss': 32,
        'min_supported_build': 28,
        'min_supported_build_play': 28,
        'min_supported_build_foss': 30,
        'update_type': 'flexible',
      };

      final info = UpdateInfo.fromJson(json);

      // A user on Play Store running build 30:
      expect(info.isUpdateAvailable(30, isPlay: true), isFalse);
      expect(info.isImmediateUpdate(30, isPlay: true), isFalse);

      // A user on FOSS running build 30:
      expect(info.isUpdateAvailable(30, isPlay: false), isTrue);
      expect(info.effectiveLatestBuild(isPlay: false), 32);
    });
  });
}
