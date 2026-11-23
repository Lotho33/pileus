import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/db/models/device_session.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/features/settings/data/profile_prefs.dart';
import 'package:pileus/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _blobKey = 'settings.profilePrefsBlob@p1';

/// Subtitle settings are per device AND profile, kept on the server in the
/// profile's blob under each device's id.
void main() {
  late SharedPreferences prefs;
  late List<String> pushed;

  Future<SettingsRepository> repoFor(String deviceId,
      {String blob = ''}) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await DeviceSession.writeTo(prefs, DeviceSession()..deviceId = deviceId);
    pushed = [];
    final repo = SettingsRepository(
        prefs,
        AuthInterceptor()..setCredentials('jwt', 'p1'),
        (_, json) async => pushed.add(json));
    if (blob.isNotEmpty) await repo.cacheProfilePrefsBlob('p1', blob);
    return repo;
  }

  const shared =
      '{"v":1,"subtitles":{"fontSize":32,"bgEnabled":true,"bottomPadding":80}}';

  test('a device starts from the profile-level values', () async {
    final repo = await repoFor('tv-1', blob: shared);
    expect(repo.getSubtitleFontSize(), 32);
    expect(repo.getSubtitleBottomPadding(), 80);
  });

  test("a change goes in this device's own block, not the profile's", () async {
    final repo = await repoFor('tv-1', blob: shared);
    await repo.setSubtitleFontSize(48);
    expect(repo.getSubtitleFontSize(), 48);
    final blob = ProfilePrefs.fromJson(prefs.getString(_blobKey)!);
    expect(blob.subtitlesFor('tv-1')['fontSize'], 48);
    expect(blob.subtitleFontSize, 32, reason: 'profile-level left as it was');
  });

  test("another device's block doesn't apply here, and survives a save",
      () async {
    final repo = await repoFor('phone-1',
        blob: jsonEncode({
          'v': 1,
          'subtitles': {'fontSize': 32},
          'deviceSubtitles': {
            'tv-1': {'fontSize': 48, 'bottomPadding': 120}
          },
        }));
    expect(repo.getSubtitleFontSize(), 32);
    await repo.setSubtitleBgEnabled(false);
    // Round-tripped, as the push to the server and the next read do.
    final blob = ProfilePrefs.fromJson(
        ProfilePrefs.fromJson(prefs.getString(_blobKey)!).toJson());
    expect(blob.subtitlesFor('tv-1'), {'fontSize': 48, 'bottomPadding': 120});
    expect(blob.subtitlesFor('phone-1'), {'bgEnabled': false});
  });
}
