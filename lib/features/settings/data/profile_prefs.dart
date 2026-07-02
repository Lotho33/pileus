import 'dart:convert';

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
///                          "bgEnabled": true, "bottomPadding": 80.0 } }
/// ```
///
/// Every field is nullable: absent means "not set on this profile, fall
/// back to the local value / app default". It carries only the four
/// subtitle-appearance settings — nothing else is person-scoped. Volume
/// (desktop-only headroom above 100%), preferred audio/subtitle language,
/// and any parental gate are all deliberately NOT settings here, and
/// device/hardware settings (overscan, low-power, buffers, diagnostics)
/// stay local by design.
class ProfilePrefs {
  static const schemaVersion = 1;

  final double? subtitleFontSize;
  final int? subtitleColorArgb;
  final bool? subtitleBgEnabled;
  final double? subtitleBottomPadding;

  const ProfilePrefs({
    this.subtitleFontSize,
    this.subtitleColorArgb,
    this.subtitleBgEnabled,
    this.subtitleBottomPadding,
  });

  static const empty = ProfilePrefs();

  bool get isEmpty =>
      subtitleFontSize == null &&
      subtitleColorArgb == null &&
      subtitleBgEnabled == null &&
      subtitleBottomPadding == null;

  /// Tolerant: "", "{}", `{"v":1}`, malformed JSON, or an unexpected shape
  /// all yield [empty] rather than throwing. Unknown top-level / block keys
  /// (a newer schema, or a block this build doesn't read) are ignored.
  factory ProfilePrefs.fromJson(String json) {
    if (json.trim().isEmpty) return empty;
    try {
      final root = jsonDecode(json);
      if (root is! Map) return empty;
      final sub = root['subtitles'];
      final s = sub is Map ? sub : const <dynamic, dynamic>{};
      return ProfilePrefs(
        subtitleFontSize: (s['fontSize'] as num?)?.toDouble(),
        subtitleColorArgb: (s['colorArgb'] as num?)?.toInt(),
        subtitleBgEnabled: s['bgEnabled'] as bool?,
        subtitleBottomPadding: (s['bottomPadding'] as num?)?.toDouble(),
      );
    } catch (_) {
      return empty;
    }
  }

  /// `{}` when nothing is set (symmetric with the server's own "empty →
  /// {}"); otherwise `{"v":1,"subtitles":{…}}` with only the keys actually
  /// set, so an untouched setting never pins a value the app default could
  /// move later.
  String toJson() {
    final sub = <String, dynamic>{
      if (subtitleFontSize != null) 'fontSize': subtitleFontSize,
      if (subtitleColorArgb != null) 'colorArgb': subtitleColorArgb,
      if (subtitleBgEnabled != null) 'bgEnabled': subtitleBgEnabled,
      if (subtitleBottomPadding != null) 'bottomPadding': subtitleBottomPadding,
    };
    if (sub.isEmpty) return '{}';
    return jsonEncode({'v': schemaVersion, 'subtitles': sub});
  }

  ProfilePrefs copyWith({
    double? subtitleFontSize,
    int? subtitleColorArgb,
    bool? subtitleBgEnabled,
    double? subtitleBottomPadding,
  }) =>
      ProfilePrefs(
        subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
        subtitleColorArgb: subtitleColorArgb ?? this.subtitleColorArgb,
        subtitleBgEnabled: subtitleBgEnabled ?? this.subtitleBgEnabled,
        subtitleBottomPadding:
            subtitleBottomPadding ?? this.subtitleBottomPadding,
      );
}
