import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/auth_interceptor.dart';
import 'engine/media_track.dart';

/// Which series a stream belongs to, for [AudioLangPref]: the plugin and
/// the same series id `SourceMemory` uses. Empty series id = a movie or an
/// unknown series.
typedef AudioLangScope = ({String pluginId, String seriesId});

/// Remembered audio-track choice for streams that carry several audio
/// renditions in one HLS manifest — shared by every player screen (TV,
/// mobile, desktop, and the browser player through plain tracks). Without
/// it the engine picks audio by the device locale, so a show started in
/// Japanese resumed in Italian.
///
/// Per series first, then the profile's last explicit pick: Japanese on an
/// anime no longer carries over to a film with an Italian track. Per profile
/// only — with no profile nothing is read or written (no device-wide value
/// two people would share). Device-local on purpose — see ProfilePrefs' doc;
/// on Pileus' plugins the language usually lives in the *source* instead
/// (see source_continuity.dart), which already follows the profile across
/// devices through the Continue Watching stream id.
///
/// One instance per player screen, asked for [scope] each time (it changes
/// across an episode switch); [pick] acts once per opened stream.
class AudioLangPref {
  // Before per-profile scoping: one device-wide value, dropped on first use.
  static const _legacyKey = 'player.preferredAudioLang';

  final AudioLangScope Function() scope;
  bool _applied = false;

  AudioLangPref(this.scope);

  static String? get _profile {
    try {
      final pid = getIt<AuthInterceptor>().profileId ?? '';
      return pid.isEmpty ? null : pid;
    } catch (_) {
      return null;
    }
  }

  /// The profile's last explicit pick, whatever the title.
  static String _globalKey(String profile) => '$_legacyKey@$profile';

  static String? _seriesKey(String profile, AudioLangScope s) =>
      s.pluginId.isEmpty || s.seriesId.isEmpty
          ? null
          : 'audio_lang:$profile:${s.pluginId}:${s.seriesId}';

  /// A new stream URL was opened — re-arm [pick].
  void reset() => _applied = false;

  /// The user explicitly picked [label] — remember it for this series and
  /// as the profile's default, and stop auto-applying for this stream.
  void remember(String label) {
    _applied = true;
    final profile = _profile;
    if (profile == null || label.isEmpty) return;
    final prefs = getIt<SharedPreferences>();
    final series = _seriesKey(profile, scope());
    if (series != null) prefs.setString(series, label);
    prefs.setString(_globalKey(profile), label);
  }

  /// Once tracks are known: if a remembered language exists (this series',
  /// else the profile's) and the auto-picked track isn't it, the track to
  /// switch to. With nothing remembered for the series yet, anchor it on
  /// whatever plays first so later episodes don't drift with each file's own
  /// track order. Null = leave it. Takes plain tracks, not an engine, so the
  /// browser player (hls.js, no PlayerEngine) shares it too.
  MediaTrack? pick(List<MediaTrack> tracks, MediaTrack? active) {
    if (_applied) return null;
    if (tracks.length < 2) return null;
    _applied = true;
    final profile = _profile;
    if (profile == null) return null;
    final prefs = getIt<SharedPreferences>();
    prefs.remove(_legacyKey);
    final series = _seriesKey(profile, scope());
    final want = (series == null ? null : prefs.getString(series)) ??
        prefs.getString(_globalKey(profile));
    final match =
        want == null || want.isEmpty ? null : matchAudioTrack(tracks, want);
    final playing = match ?? active;
    if (series != null &&
        prefs.getString(series) == null &&
        playing != null &&
        playing.label.isNotEmpty) {
      prefs.setString(series, playing.label);
    }
    if (match != null && match.id != active?.id) return match;
    return null;
  }
}

/// Exact label first; then the language token alone (the part before " · "
/// in the ExoPlayer labels, e.g. "JPN" out of "JPN · Japanese") compared as a
/// whole word — never a loose substring (a `contains` once picked
/// "Slovenian" for a stored "en"). Visible for tests.
MediaTrack? matchAudioTrack(List<MediaTrack> tracks, String want) {
  final w = want.toLowerCase().trim();
  for (final t in tracks) {
    if (t.label.toLowerCase().trim() == w) return t;
  }
  String lang(String l) => l.split('·').first.trim().toLowerCase();
  final wl = lang(want);
  if (wl.isEmpty) return null;
  for (final t in tracks) {
    if (lang(t.label) == wl) return t;
  }
  return null;
}
