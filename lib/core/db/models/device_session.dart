import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Plain data holder for the single cached device/session row — replaces the
/// old Isar `@collection` class. This app only ever keeps one row (there is
/// no per-key lookup here, unlike LayoutCache), so it's stored whole under
/// one SharedPreferences key rather than being split into scalar prefs.
class DeviceSession {
  DeviceSession();

  String deviceId = '';
  String deviceJwt = '';
  int expiresAtTimestamp = 0;
  bool isAuthorized = false;
  String? lastActiveProfileId;
  String? grpcHost;
  String? vpnHost;

  // SHA-256 (hex) of the gRPC server's self-signed TLS cert, pinned on
  // first contact (TOFU) from /pileus/info's grpc_tls_fingerprint — see
  // server_discovery_screen.dart's _saveHost and grpc_channel_io.dart. Null
  // means either TLS is off on the server or no info round-trip has
  // happened yet (e.g. resolveGrpcHost's plain TCP probe never fetches
  // /pileus/info), in which case the channel falls back to insecure.
  String? tlsFingerprint;

  factory DeviceSession.fromJson(Map<String, dynamic> json) => DeviceSession()
    ..deviceId = json['deviceId'] as String? ?? ''
    ..deviceJwt = json['deviceJwt'] as String? ?? ''
    ..expiresAtTimestamp = json['expiresAtTimestamp'] as int? ?? 0
    ..isAuthorized = json['isAuthorized'] as bool? ?? false
    ..lastActiveProfileId = json['lastActiveProfileId'] as String?
    ..grpcHost = json['grpcHost'] as String?
    ..vpnHost = json['vpnHost'] as String?
    ..tlsFingerprint = json['tlsFingerprint'] as String?;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceJwt': deviceJwt,
        'expiresAtTimestamp': expiresAtTimestamp,
        'isAuthorized': isAuthorized,
        'lastActiveProfileId': lastActiveProfileId,
        'grpcHost': grpcHost,
        'vpnHost': vpnHost,
        'tlsFingerprint': tlsFingerprint,
      };

  static const _prefsKey = 'device_session';

  /// Reads the single cached session row from SharedPreferences (was Isar's
  /// `deviceSessions.where().findFirst()` — this app never keeps more than
  /// one). Shared by AuthRepository, host_resolver.dart, injection.dart and
  /// ServerDiscoveryScreen so the JSON shape and key live in exactly one
  /// place instead of being duplicated at every call site.
  static DeviceSession? readFrom(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    try {
      return DeviceSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeTo(SharedPreferences prefs, DeviceSession session) =>
      prefs.setString(_prefsKey, jsonEncode(session.toJson()));

  static Future<void> clear(SharedPreferences prefs) => prefs.remove(_prefsKey);
}
