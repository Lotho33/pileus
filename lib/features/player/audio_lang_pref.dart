import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/auth_interceptor.dart';
import 'engine/player_engine.dart';

/// Remembered audio-track choice for streams that carry several audio
/// renditions in one HLS manifest — shared by every [PlayerEngine] screen
/// (TV, mobile, desktop). Without it the engine picks audio by the device
/// locale, so a show started in Japanese resumed in Italian.
///
/// Scoped per profile (two people sharing a device keep their own choice).
/// Device-local on purpose — see ProfilePrefs' doc; on Pileus' plugins the
/// language usually lives in the *source* instead (see
/// source_continuity.dart), which already follows the profile across
/// devices through the Continue Watching stream id.
///
/// One instance per opened stream: [maybeApply] acts once, the first time
/// the engine reports more than one audio track.
class AudioLangPref {
  static const _legacyKey = 'player.preferredAudioLang';

  bool _applied = false;

  static String get _key {
    final pid = getIt<AuthInterceptor>().profileId ?? '';
    return pid.isEmpty ? _legacyKey : '$_legacyKey@$pid';
  }

  static String? _read(SharedPreferences prefs) =>
      prefs.getString(_key) ??
      // Pre-scoping builds stored one device-wide value — keep honouring it
      // until this profile makes its own choice.
      prefs.getString(_legacyKey);

  /// A new stream URL was opened — re-arm [maybeApply].
  void reset() => _applied = false;

  /// The user explicitly picked [label] — remember it and stop auto-applying
  /// for this stream.
  void remember(String label) {
    _applied = true;
    getIt<SharedPreferences>().setString(_key, label);
  }

  /// Once tracks are known: if a remembered language exists and the
  /// auto-picked track isn't it, switch. With nothing remembered yet, anchor
  /// on whatever the engine picked for this first stream so later episodes
  /// don't drift with each file's own track order.
  void maybeApply(PlayerEngine engine) {
    if (_applied) return;
    final tracks = engine.audioTracks;
    if (tracks.length < 2) return;
    _applied = true;
    final prefs = getIt<SharedPreferences>();
    final want = _read(prefs);
    if (want == null || want.isEmpty) {
      final active = engine.activeAudioTrack;
      if (active != null && active.label.isNotEmpty) {
        prefs.setString(_key, active.label);
      }
      return;
    }
    final match = matchAudioTrack(tracks, want);
    if (match != null && match.id != engine.activeAudioTrack?.id) {
      engine.selectAudioTrack(match);
    }
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
