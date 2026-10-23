import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/auth_interceptor.dart';
import '../../core/grpc/clients/media_client.dart' show StreamSource;
import '../settings/data/settings_repository.dart';

/// Which source a Play picks when the user doesn't choose one — the
/// language is a preference, not a question asked at every Play.
///
/// On a VOD title the sources of a plugin are its language versions
/// ("Italiano" / "Inglese", "Italiano (Doppiato)" / "Giapponese (Sub ITA)");
/// on a live event they are the nodes serving it, where none of this
/// applies (no label matches a language → the first one, as before).
///
/// The rule, in order:
///  1. an explicit label — the source of the episode being continued
///     (binge, Continue Watching), see source_continuity.dart;
///  2. the label last played for this series, on this profile;
///  3. the profile's preferred language version (Preferenze → "Lingua
///     preferita", server-synced);
///  4. the first source.
///
/// Every Play entry point and the stream warm-up go through
/// [choosePlaySource], so the stream id prepared ahead of Play is the one
/// the Play then asks for.

/// The profile setting: dubbed Italian, or the original version (usually
/// with Italian subtitles).
enum PreferredLanguage {
  italian('it', 'Italiano'),
  original('original', 'Originale sottotitolato');

  const PreferredLanguage(this.id, this.label);
  final String id;
  final String label;

  static PreferredLanguage fromId(String id) =>
      id == original.id ? original : italian;
}

/// The language version a source label stands for, or null when the label
/// says nothing about language (a live node, an unlabelled source).
/// "Sub" anywhere means the original audio with subtitles — "Giapponese
/// (Sub ITA)" is original even though it says ITA.
PreferredLanguage? languageOfLabel(String label) {
  final l = label.toLowerCase();
  if (l.isEmpty) return null;
  if (l.contains('sub')) return PreferredLanguage.original;
  if (l.contains('ital') ||
      RegExp(r'\bita\b').hasMatch(l) ||
      l.contains('doppiat')) {
    return PreferredLanguage.italian;
  }
  const originals = [
    'ingl',
    'engl',
    'eng',
    'giappon',
    'japan',
    'jap',
    'orig',
    'spagn',
    'franc',
    'tedes',
    'corean',
    'korean',
  ];
  if (originals.any(l.contains)) return PreferredLanguage.original;
  return null;
}

/// The pure rule — see the library doc. [usedFallback] is true when the
/// preferred language was asked for but none of [sources] has it (the
/// player then says "Disponibile solo in …").
({StreamSource? source, bool usedFallback}) chooseSource(
  List<StreamSource> sources, {
  String explicitLabel = '',
  String rememberedLabel = '',
  PreferredLanguage language = PreferredLanguage.italian,
}) {
  if (sources.isEmpty) return (source: null, usedFallback: false);
  for (final label in [explicitLabel, rememberedLabel]) {
    if (label.isEmpty) continue;
    final l = label.toLowerCase();
    for (final s in sources) {
      if (s.label.toLowerCase() == l) {
        return (source: s, usedFallback: false);
      }
    }
  }
  final languages = [for (final s in sources) languageOfLabel(s.label)];
  // Not language versions at all (live nodes): first one, nothing to say.
  if (languages.every((l) => l == null)) {
    return (source: sources.first, usedFallback: false);
  }
  final i = languages.indexOf(language);
  if (i >= 0) return (source: sources[i], usedFallback: false);
  return (source: sources.first, usedFallback: true);
}

/// The rule with the profile's own inputs filled in: its preferred
/// language and what it last played of [seriesId]. Safe without DI (tests):
/// then Italian and no memory.
StreamSource? choosePlaySource(
  List<StreamSource> sources, {
  String explicitLabel = '',
  String pluginId = '',
  String seriesId = '',
}) =>
    chooseSource(
      sources,
      explicitLabel: explicitLabel,
      rememberedLabel: SourceMemory.labelFor(pluginId, seriesId),
      language: currentPreferredLanguage(),
    ).source;

/// [sources] with the one choosePlaySource would pick moved to the front —
/// for the TV language buttons: the first button is the auto-focused one,
/// so OK plays what the rule (and the stream warm-up) chose.
List<StreamSource> preferredFirst(
  List<StreamSource> sources, {
  String pluginId = '',
  String seriesId = '',
}) {
  final chosen =
      choosePlaySource(sources, pluginId: pluginId, seriesId: seriesId);
  if (chosen == null || identical(chosen, sources.first)) return sources;
  return [
    chosen,
    for (final s in sources)
      if (!identical(s, chosen)) s
  ];
}

PreferredLanguage currentPreferredLanguage() {
  try {
    return PreferredLanguage.fromId(
        getIt<SettingsRepository>().getPreferredLanguage());
  } catch (_) {
    return PreferredLanguage.italian;
  }
}

/// "Disponibile solo in inglese" when [chosen] isn't the preferred language
/// and no source offers it — shown while the player loads, so a version
/// the user didn't ask for is never a surprise. Empty otherwise.
String languageNotice(List<StreamSource> sources, StreamSource? chosen) {
  if (chosen == null) return '';
  final pref = currentPreferredLanguage();
  final langs = [for (final s in sources) languageOfLabel(s.label)];
  if (langs.contains(pref) || languageOfLabel(chosen.label) == null) return '';
  return 'Disponibile solo in ${chosen.label.trim().toLowerCase()}';
}

/// The language version last played per series, per profile — step 2 of
/// the rule. Written when a player reaches its first frame. Device-local:
/// on other devices Continue Watching (which stores the stream id) and the
/// plugin's own ordering carry the same choice.
class SourceMemory {
  SourceMemory._();

  static String _key(String pluginId, String seriesId) {
    String pid;
    try {
      pid = getIt<AuthInterceptor>().profileId ?? '';
    } catch (_) {
      pid = '';
    }
    return 'source_lang:$pid:$pluginId:$seriesId';
  }

  static String labelFor(String pluginId, String seriesId) {
    if (pluginId.isEmpty || seriesId.isEmpty) return '';
    try {
      return getIt<SharedPreferences>().getString(_key(pluginId, seriesId)) ??
          '';
    } catch (_) {
      return '';
    }
  }

  /// Only language labels are remembered — never a live node.
  static void remember(String pluginId, String seriesId, String label) {
    if (pluginId.isEmpty || seriesId.isEmpty) return;
    if (languageOfLabel(label) == null) return;
    try {
      getIt<SharedPreferences>().setString(_key(pluginId, seriesId), label);
    } catch (_) {}
  }
}

/// The language versions the player offers under "Lingua" — only when they
/// are separate streams: more than one source with a language label, and
/// the stream playing carries a single audio track. When the stream already
/// has several audio tracks (vix: Italian and English in one master), its
/// own "Audio" menu is the language switch and a second one would just
/// confuse. Empty = no "Lingua" entry.
List<StreamSource> playerLanguageOptions(
  List<StreamSource> sources, {
  required int audioTracks,
}) {
  final versions = [
    for (final s in sources)
      if (languageOfLabel(s.label) != null) s
  ];
  if (versions.length < 2 || audioTracks >= 2) return const [];
  return versions;
}
