import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/features/player/audio_lang_pref.dart';
import 'package:pileus/features/player/engine/media_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ita = MediaTrack(id: '0', label: 'ITA · Italiano');
const _jpn = MediaTrack(id: '1', label: 'JPN · Japanese');
const _tracks = [_ita, _jpn];

void main() {
  late AuthInterceptor auth;
  var scope = (pluginId: 'p', seriesId: 'anime');

  AudioLangPref pref() => AudioLangPref(() => scope);

  Future<void> setUpWith(Map<String, Object> prefs, {String? profile}) async {
    SharedPreferences.setMockInitialValues(prefs);
    auth = AuthInterceptor();
    if (profile != null) auth.setCredentials('jwt', profile);
    getIt.registerSingleton<SharedPreferences>(
        await SharedPreferences.getInstance());
    getIt.registerSingleton<AuthInterceptor>(auth);
    scope = (pluginId: 'p', seriesId: 'anime');
  }

  tearDown(() async => getIt.reset());

  test('a pick sticks to its series; others fall back to the last pick',
      () async {
    await setUpWith({}, profile: 'anna');
    pref().remember(_jpn.label); // Japanese on the anime
    expect(pref().pick(_tracks, _ita), _jpn);

    scope = (pluginId: 'p', seriesId: 'drama');
    pref().remember(_ita.label); // Italian on another series
    expect(pref().pick(_tracks, _jpn), _ita);

    scope = (pluginId: 'p', seriesId: 'anime');
    expect(pref().pick(_tracks, _ita), _jpn, reason: 'anime keeps its own');

    scope = (pluginId: 'p', seriesId: '');
    expect(pref().pick(_tracks, _jpn), _ita, reason: 'film: last pick');
  });

  test('first stream of a series anchors it against later drift', () async {
    await setUpWith({}, profile: 'anna');
    expect(pref().pick(_tracks, _jpn), isNull); // nothing yet: leave it
    expect(pref().pick(_tracks, _ita), _jpn); // next episode, other order
  });

  test('once per stream, and only with more than one track', () async {
    await setUpWith({}, profile: 'anna');
    pref().remember(_jpn.label);
    final p = pref();
    expect(p.pick(const [_ita], _ita), isNull);
    expect(p.pick(_tracks, _ita), _jpn);
    expect(p.pick(_tracks, _ita), isNull);
    p.reset();
    expect(p.pick(_tracks, _ita), _jpn);
  });

  test('per profile; without one nothing is kept', () async {
    await setUpWith({}, profile: 'anna');
    pref().remember(_jpn.label);
    auth.setCredentials('jwt', 'luca');
    expect(pref().pick(_tracks, _ita), isNull);
    expect(pref().pick(_tracks, _ita), isNull, reason: 'anchored to ITA');
    auth.setCredentials('jwt', 'anna');
    expect(pref().pick(_tracks, _ita), _jpn);
  });

  test('no profile: nothing read or written', () async {
    await setUpWith({'player.preferredAudioLang': _jpn.label});
    pref().remember(_jpn.label);
    expect(pref().pick(_tracks, _ita), isNull);
    expect(getIt<SharedPreferences>().getKeys(), {'player.preferredAudioLang'});
  });

  test('the old device-wide value is dropped', () async {
    await setUpWith({'player.preferredAudioLang': _jpn.label}, profile: 'anna');
    expect(pref().pick(_tracks, _ita), isNull);
    expect(getIt<SharedPreferences>().getString('player.preferredAudioLang'),
        isNull);
  });
}
