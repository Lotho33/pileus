/// Plain data holder for one cached local profile row — replaces the old
/// Isar `@collection` class. The list of these is stored as a single JSON
/// array under one SharedPreferences key (see AuthRepository._readProfiles /
/// _writeProfiles), keyed in memory by [profileId].
class LocalProfile {
  LocalProfile();

  String profileId = '';
  String profileName = '';
  String avatarUrl = '';

  // Profile PIN — mirrors ProfileResponse's three
  // server-computed, per-calling-device flags (proto/auth.proto's "Profile
  // PIN" section). Cached here like the rest of the row so the profile
  // picker can show a lock icon without a round-trip, and so AuthBloc's
  // fast auto-entry path (_onAppStarted, which deliberately skips
  // syncProfilesFromServer for speed) can still decide whether the
  // remembered default profile needs the PIN dialog. Being a cached
  // snapshot, it can go stale (trust revoked from another device, PIN
  // changed elsewhere) — that's fine: the first protected RPC call would
  // then fail with isProfileLocked, which bounces back to the picker with
  // the PIN dialog open regardless of what this cache says.
  bool pinProtected = false;
  bool unlocked = false;
  bool deviceTrusted = false;

  factory LocalProfile.fromJson(Map<String, dynamic> json) => LocalProfile()
    ..profileId = json['profileId'] as String? ?? ''
    ..profileName = json['profileName'] as String? ?? ''
    ..avatarUrl = json['avatarUrl'] as String? ?? ''
    ..pinProtected = json['pinProtected'] as bool? ?? false
    ..unlocked = json['unlocked'] as bool? ?? false
    ..deviceTrusted = json['deviceTrusted'] as bool? ?? false;

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'profileName': profileName,
        'avatarUrl': avatarUrl,
        'pinProtected': pinProtected,
        'unlocked': unlocked,
        'deviceTrusted': deviceTrusted,
      };
}
