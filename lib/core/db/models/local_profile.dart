/// Plain data holder for one cached local profile row — replaces the old
/// Isar `@collection` class. The list of these is stored as a single JSON
/// array under one SharedPreferences key (see AuthRepository._readProfiles /
/// _writeProfiles), keyed in memory by [profileId].
class LocalProfile {
  LocalProfile();

  String profileId = '';
  String profileName = '';
  String avatarUrl = '';
  bool isChildProfile = false;

  factory LocalProfile.fromJson(Map<String, dynamic> json) => LocalProfile()
    ..profileId = json['profileId'] as String? ?? ''
    ..profileName = json['profileName'] as String? ?? ''
    ..avatarUrl = json['avatarUrl'] as String? ?? ''
    ..isChildProfile = json['isChildProfile'] as bool? ?? false;

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'profileName': profileName,
        'avatarUrl': avatarUrl,
        'isChildProfile': isChildProfile,
      };
}
