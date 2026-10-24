import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/media_client.dart' show StreamSource;
import 'package:pileus/features/player/source_preference.dart';
import 'package:pileus/features/settings/data/profile_prefs.dart';
import 'package:pileus/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

StreamSource _s(String id, String label) => StreamSource(id: id, label: label);

// The labels the plugins really send.
final _vix = [_s('1:it', 'Italiano'), _s('1:en', 'Inglese')];
final _vixEnOnly = [_s('1:en', 'Inglese')];
final _anime = [
  _s('ep::ita', 'Italiano (Doppiato)'),
  _s('ep::jp', 'Giapponese (Sub ITA)'),
];
final _live = [_s('n1', 'Nodo 1'), _s('n2', 'Server B')];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('languageOfLabel', () {
    test('real plugin labels', () {
      expect(languageOfLabel('Italiano'), PreferredLanguage.italian);
      expect(languageOfLabel('Inglese'), PreferredLanguage.original);
      expect(languageOfLabel('Italiano (Doppiato)'), PreferredLanguage.italian);
      // "Sub" wins over the ITA in it: original audio with subtitles.
      expect(
          languageOfLabel('Giapponese (Sub ITA)'), PreferredLanguage.original);
      expect(languageOfLabel('SUB ITA'), PreferredLanguage.original);
      expect(languageOfLabel('ITA'), PreferredLanguage.italian);
    });
    test('not a language: live nodes, empty', () {
      expect(languageOfLabel('Nodo 1'), isNull);
      expect(languageOfLabel('Server B'), isNull);
      expect(languageOfLabel(''), isNull);
    });
  });

  group('chooseSource', () {
    test('preferred language, either order', () {
      expect(chooseSource(_vix).source!.id, '1:it');
      expect(
          chooseSource(_vix, language: PreferredLanguage.original).source!.id,
          '1:en');
      expect(
          chooseSource(_anime, language: PreferredLanguage.original).source!.id,
          'ep::jp');
    });

    test('explicit label beats memory beats preference', () {
      expect(
          chooseSource(_vix, explicitLabel: 'inglese', rememberedLabel: 'X')
              .source!
              .id,
          '1:en');
      expect(chooseSource(_vix, rememberedLabel: 'Inglese').source!.id, '1:en');
      // A remembered label this title doesn't have falls through.
      expect(
          chooseSource(_vix, rememberedLabel: 'Giapponese (Sub ITA)')
              .source!
              .id,
          '1:it');
    });

    test('preferred language missing: first one, flagged', () {
      final r = chooseSource(_vixEnOnly);
      expect(r.source!.id, '1:en');
      expect(r.usedFallback, isTrue);
    });

    test('live nodes: first one, never a fallback', () {
      final r = chooseSource(_live, language: PreferredLanguage.original);
      expect(r.source!.id, 'n1');
      expect(r.usedFallback, isFalse);
    });

    test('no sources', () {
      expect(chooseSource(const []).source, isNull);
    });
  });

  group('with the profile (DI)', () {
    late SettingsRepository settings;
    late AuthInterceptor interceptor;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      interceptor = AuthInterceptor()..setCredentials('jwt', 'anna');
      settings = SettingsRepository(prefs, interceptor, (_, __) async {});
      getIt.registerSingleton<SharedPreferences>(prefs);
      getIt.registerSingleton<AuthInterceptor>(interceptor);
      getIt.registerSingleton<SettingsRepository>(settings);
    });

    tearDown(() async => getIt.reset());

    test('profile preference drives the Play choice and the notice', () async {
      expect(choosePlaySource(_anime)!.id, 'ep::ita');
      await settings.setPreferredLanguage(PreferredLanguage.original.id);
      expect(choosePlaySource(_anime)!.id, 'ep::jp');
      expect(languageNotice(_anime, choosePlaySource(_anime)), '');

      await settings.setPreferredLanguage(PreferredLanguage.italian.id);
      final en = choosePlaySource(_vixEnOnly);
      expect(languageNotice(_vixEnOnly, en), 'Disponibile solo in inglese');
      expect(languageNotice(_live, choosePlaySource(_live)), '');
    });

    test('per series memory, per profile; only language labels', () {
      SourceMemory.remember('vix', 'show9', 'Inglese');
      SourceMemory.remember('vix', 'show9', 'Nodo 1'); // ignored
      expect(choosePlaySource(_vix, pluginId: 'vix', seriesId: 'show9')!.id,
          '1:en');
      expect(choosePlaySource(_vix, pluginId: 'vix', seriesId: 'other')!.id,
          '1:it');
      interceptor.setCredentials('jwt', 'luca');
      expect(choosePlaySource(_vix, pluginId: 'vix', seriesId: 'show9')!.id,
          '1:it');
    });

    test('preferredFirst puts the rule\'s pick first, keeps the rest', () {
      SourceMemory.remember('au', 's', 'Giapponese (Sub ITA)');
      final ordered = preferredFirst(_anime, pluginId: 'au', seriesId: 's');
      expect(ordered.map((s) => s.id), ['ep::jp', 'ep::ita']);
      expect(identical(preferredFirst(_vix), _vix), isTrue);
    });
  });

  test('ProfilePrefs keeps the playback block (and old blobs still parse)', () {
    final p = ProfilePrefs.fromJson(
        '{"v":1,"playback":{"language":"original"},"x":{"y":1}}');
    expect(p.preferredLanguage, 'original');
    final round = ProfilePrefs.fromJson(p.toJson());
    expect(round.preferredLanguage, 'original');
    expect(round.toJson(), contains('"x"'));
    expect(
        ProfilePrefs.fromJson('{"v":1,"subtitles":{"fontSize":30}}')
            .preferredLanguage,
        isNull);
    expect(const ProfilePrefs(preferredLanguage: 'it').isEmpty, isFalse);
  });

  group('playerLanguageOptions ("Lingua" in the player)', () {
    test('anime: separate streams, one audio track each → offered', () {
      expect(playerLanguageOptions(_anime, audioTracks: 1).map((s) => s.id),
          ['ep::ita', 'ep::jp']);
    });
    test('vix with both languages in one stream → the Audio menu does it', () {
      expect(playerLanguageOptions(_vix, audioTracks: 2), isEmpty);
    });
    test('a single version, or live nodes → nothing', () {
      expect(playerLanguageOptions(_vixEnOnly, audioTracks: 1), isEmpty);
      expect(playerLanguageOptions(_live, audioTracks: 0), isEmpty);
    });
  });

  test('languageDescription (the episode language sheet)', () {
    expect(languageDescription('Giapponese (Sub ITA)'),
        'giapponese (sottotitolato)');
    expect(languageDescription('Italiano (Doppiato)'), 'italiano');
    expect(languageDescription('Inglese'), 'inglese');
    expect(languageDescription('Sub ITA'), 'originale (sottotitolato)');
  });
}
