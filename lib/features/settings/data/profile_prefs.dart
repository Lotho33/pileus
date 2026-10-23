import 'dart:convert';

import '../../media/data/plugin_prefs.dart';

/// The person-scoped preferences blob that mycelium stores per profile
/// (`preferences_json` on `ProfileResponse`) and echoes back on every
/// `ListProfiles`. Opaque to the server — this class is the whole schema.
///
/// Wire shape (a `v` version key so the schema can evolve; settings grouped
/// so audio/player/ui blocks could slot in as siblings later without a
/// migration):
///
/// ```json
/// { "v": 1, "subtitles": { "fontSize": 32.0, "colorArgb": 4294967295,
///                          "bgEnabled": true, "bottomPadding": 80.0 },
///   "plugins": { "order": ["pluginA","pluginB"],
///                "hiddenPlugins": ["pluginC"],
///                "catalogs": { "pluginA": {"order":[...], "hidden":[...]} } },
///   "playback": { "language": "it" } }
/// ```
///
/// Every field is nullable/defaults-to-unset: absent means "not set on this
/// profile, fall back to the local value / app default". Person-scoped only
/// — volume (desktop-only headroom above 100%), the audio *track* picked
/// inside a stream (AudioLangPref, device-local) and any parental gate are
/// all deliberately NOT settings here. The preferred *language version*
/// ("playback.language": dubbed Italian or original — which source a Play
/// picks, see source_preference.dart) is: it follows the person. Device/
/// hardware settings (overscan, low-power, buffers, diagnostics) stay local
/// by design. Plugin order/visibility (the "plugins" block) IS
/// person-scoped, unlike those device settings: it's a browsing preference
/// that should follow the profile to every paired device, same as it does
/// for subtitles.
///
/// Top-level keys this build doesn't recognise are preserved verbatim
/// (round-tripped through [_unknownBlocks]) rather than dropped on the next
/// save — without this, an older build saving a subtitle tweak would
/// silently erase a "plugins" block written by a newer build on another
/// device mid-rollout (or vice versa for a future block this build doesn't
/// know about yet).
class ProfilePrefs {
  static const schemaVersion = 1;

  final double? subtitleFontSize;
  final int? subtitleColorArgb;
  final bool? subtitleBgEnabled;
  final double? subtitleBottomPadding;
  final List<String> pluginOrder;
  final PluginPrefs pluginPrefs;
  // "it" | "original" — see PreferredLanguage in source_preference.dart.
  final String? preferredLanguage;
  final Map<String, dynamic> _unknownBlocks;

  const ProfilePrefs({
    this.subtitleFontSize,
    this.subtitleColorArgb,
    this.subtitleBgEnabled,
    this.subtitleBottomPadding,
    this.pluginOrder = const [],
    this.pluginPrefs = const PluginPrefs(),
    this.preferredLanguage,
    Map<String, dynamic> unknownBlocks = const {},
  }) : _unknownBlocks = unknownBlocks;

  static const empty = ProfilePrefs();

  bool get isEmpty =>
      subtitleFontSize == null &&
      subtitleColorArgb == null &&
      subtitleBgEnabled == null &&
      subtitleBottomPadding == null &&
      pluginOrder.isEmpty &&
      pluginPrefs.isEmpty &&
      preferredLanguage == null;

  /// Tolerant: "", "{}", `{"v":1}`, malformed JSON, or an unexpected shape
  /// all yield [empty] rather than throwing.
  factory ProfilePrefs.fromJson(String json) {
    if (json.trim().isEmpty) return empty;
    try {
      final root = jsonDecode(json);
      if (root is! Map) return empty;
      final sub = root['subtitles'];
      final s = sub is Map ? sub : const <dynamic, dynamic>{};
      final plugins = root['plugins'];
      final p = plugins is Map
          ? plugins.cast<String, dynamic>()
          : const <String, dynamic>{};
      final playback = root['playback'];
      final pb = playback is Map ? playback : const <dynamic, dynamic>{};
      final unknown = <String, dynamic>{
        for (final e in root.entries)
          if (e.key != 'v' &&
              e.key != 'subtitles' &&
              e.key != 'plugins' &&
              e.key != 'playback')
            e.key.toString(): e.value,
      };
      return ProfilePrefs(
        subtitleFontSize: (s['fontSize'] as num?)?.toDouble(),
        subtitleColorArgb: (s['colorArgb'] as num?)?.toInt(),
        subtitleBgEnabled: s['bgEnabled'] as bool?,
        subtitleBottomPadding: (s['bottomPadding'] as num?)?.toDouble(),
        pluginOrder: (p['order'] as List?)?.cast<String>() ?? const [],
        // PluginPrefs.fromJson only reads 'hiddenPlugins'/'catalogs' —
        // passing the whole plugins map (which also has 'order') is fine,
        // it ignores keys it doesn't know.
        pluginPrefs: p.isEmpty ? const PluginPrefs() : PluginPrefs.fromJson(p),
        preferredLanguage: pb['language'] as String?,
        unknownBlocks: unknown,
      );
    } catch (_) {
      return empty;
    }
  }

  /// `{}` when nothing is set (symmetric with the server's own "empty →
  /// {}"); otherwise `{"v":1,"subtitles":{…},"plugins":{…}}` with only the
  /// blocks actually set, plus any unrecognised block preserved as-is, so an
  /// untouched setting never pins a value the app default could move later
  /// and a block this build doesn't understand is never destroyed.
  String toJson() {
    final sub = <String, dynamic>{
      if (subtitleFontSize != null) 'fontSize': subtitleFontSize,
      if (subtitleColorArgb != null) 'colorArgb': subtitleColorArgb,
      if (subtitleBgEnabled != null) 'bgEnabled': subtitleBgEnabled,
      if (subtitleBottomPadding != null) 'bottomPadding': subtitleBottomPadding,
    };
    final plugins = <String, dynamic>{
      if (pluginOrder.isNotEmpty) 'order': pluginOrder,
      if (!pluginPrefs.isEmpty) ...pluginPrefs.toJson(),
    };
    final playback = <String, dynamic>{
      if (preferredLanguage != null) 'language': preferredLanguage,
    };
    if (sub.isEmpty &&
        plugins.isEmpty &&
        playback.isEmpty &&
        _unknownBlocks.isEmpty) {
      return '{}';
    }
    return jsonEncode({
      'v': schemaVersion,
      if (sub.isNotEmpty) 'subtitles': sub,
      if (plugins.isNotEmpty) 'plugins': plugins,
      if (playback.isNotEmpty) 'playback': playback,
      ..._unknownBlocks,
    });
  }

  ProfilePrefs copyWith({
    double? subtitleFontSize,
    int? subtitleColorArgb,
    bool? subtitleBgEnabled,
    double? subtitleBottomPadding,
    List<String>? pluginOrder,
    PluginPrefs? pluginPrefs,
    String? preferredLanguage,
  }) =>
      ProfilePrefs(
        subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
        subtitleColorArgb: subtitleColorArgb ?? this.subtitleColorArgb,
        subtitleBgEnabled: subtitleBgEnabled ?? this.subtitleBgEnabled,
        subtitleBottomPadding:
            subtitleBottomPadding ?? this.subtitleBottomPadding,
        pluginOrder: pluginOrder ?? this.pluginOrder,
        pluginPrefs: pluginPrefs ?? this.pluginPrefs,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        unknownBlocks: _unknownBlocks,
      );
}
