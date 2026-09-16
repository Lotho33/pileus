import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/grpc/auth_interceptor.dart';
import 'profile_prefs.dart';

/// App preferences. Two tiers:
///
/// - **Device/hardware** (buffers, low-power mode, diagnostics, overscan) —
///   local only, never leave this device. These follow the box, not the
///   person.
/// - **Person-scoped** (subtitle appearance) — kept in a
///   [ProfilePrefs] blob that mycelium stores per profile
///   (`preferences_json`) and echoes on every `ListProfiles`, so they
///   follow the person to every paired device. Written through to a local
///   `key@$pid` SharedPreferences copy too, so a read works offline / before
///   the first sync, and the server push is debounced.
///
/// Deliberately NOT stored in Isar: the Isar collections in this app
/// (LocalProfile, DeviceSession, caches) all have a sync/wipe/session
/// lifecycle — mixing flat scalar prefs into that risks the same kind of
/// accidental-wipe bug already found in profile sync (see AuthRepository).
class SettingsRepository {
  SettingsRepository(this._prefs, this._interceptor, this._pushProfilePrefs);
  final SharedPreferences _prefs;
  final AuthInterceptor _interceptor;

  /// Debounced server push of a profile's preferences blob. Wired in
  /// injection.dart to AuthRepository.setProfilePreferences (via a getIt
  /// lookup, so a rebuildGrpcClients can't leave it stale).
  final Future<void> Function(String profileId, String prefsJson)
      _pushProfilePrefs;

  static const _kSubtitleFontSize = 'settings.subtitleFontSize';
  static const _kSubtitleColorArgb = 'settings.subtitleColorArgb';
  static const _kSubtitleBgEnabled = 'settings.subtitleBgEnabled';
  static const _kSubtitleBottomPadding = 'settings.subtitleBottomPadding';
  static const _kPlayerBufferMiB = 'settings.playerBufferMiB';
  static const _kLiveBufferMiB = 'settings.liveBufferMiB';
  static const _kLowPowerMode = 'settings.lowPowerMode';
  static const _kDiagnostics = 'settings.diagnostics';
  static const _kOverscanPercent = 'settings.overscanPercent';
  static const _kProfilePrefsBlob = 'settings.profilePrefsBlob';

  // Player demux buffer, in MiB. Not per-profile (it's a device/hardware
  // concern, not a viewing preference). Split VOD vs live: a film benefits
  // from a big cushion against a slow link, a live stream does NOT — a large
  // buffer there just means a long pre-roll before the picture appears and
  // more latency behind the live edge, for no gain.
  static const int playerBufferMiBDefault = 32; // VOD
  static const int playerBufferMiBMin = 8;
  static const int playerBufferMiBMax = 128;
  static const int liveBufferMiBDefault = 16;
  static const int liveBufferMiBMin = 4;
  static const int liveBufferMiBMax = 64;

  int getPlayerBufferMiB() =>
      ((_prefs.getInt(_kPlayerBufferMiB) ?? playerBufferMiBDefault))
          .clamp(playerBufferMiBMin, playerBufferMiBMax);
  Future<void> setPlayerBufferMiB(int v) => _prefs.setInt(
      _kPlayerBufferMiB, v.clamp(playerBufferMiBMin, playerBufferMiBMax));

  int getLiveBufferMiB() =>
      ((_prefs.getInt(_kLiveBufferMiB) ?? liveBufferMiBDefault))
          .clamp(liveBufferMiBMin, liveBufferMiBMax);
  Future<void> setLiveBufferMiB(int v) => _prefs.setInt(
      _kLiveBufferMiB, v.clamp(liveBufferMiBMin, liveBufferMiBMax));

  // "Modalità hardware modesto" — trims the UI's own GPU cost on weak boxes
  // (drops blur passes and scale-shader effects; see core/perf_profile.dart).
  // Device-level, not per-profile. Off by default, EXCEPT on boxes
  // main.dart's weak-device auto-detect flags (Amlogic S905W/X etc.) where
  // it's turned on once — after which `containsKey` is true and the user's
  // own toggle always wins.
  bool getLowPowerMode() => _prefs.getBool(_kLowPowerMode) ?? false;
  Future<void> setLowPowerMode(bool v) => _prefs.setBool(_kLowPowerMode, v);

  // Whether the low-power flag has ever been written (by the user or by the
  // auto-detect). When false, main.dart is free to set it from hardware
  // detection; when true, that stored choice is authoritative.
  bool isLowPowerModeSet() => _prefs.containsKey(_kLowPowerMode);

  // Field diagnostics: when on, a release build emits the `[pileus/perf]` /
  // `[pileus/jank]` trace — used to pull logs off a specific TV box without a
  // debug build. Off by default; read once in main() into `kPerfDiagnostics`,
  // so a change needs an app restart to take effect. Device-level.
  bool getDiagnostics() => _prefs.getBool(_kDiagnostics) ?? false;
  Future<void> setDiagnostics(bool v) => _prefs.setBool(_kDiagnostics, v);

  // TV overscan compensation: many TVs/boxes crop the outer ~3-5% of the
  // HDMI frame, so a full-bleed UI loses its edges (desktop has no
  // overscan, hence desktop is fine). This is the % of width/height inset
  // as a safe-area margin on every side, applied globally on Android in
  // main.dart. Device-level. `overscan` is a live ValueNotifier so the
  // Preferenze slider reflows the whole app as you adjust it, instead of
  // needing a restart. Default 2% — mild help for the common mild-overscan
  // TV without a distracting border on a pixel-perfect one; raise it for a
  // TV that crops harder, set 0 for one that doesn't crop at all.
  static const double overscanPercentDefault = 2.0;
  static const double overscanPercentMax = 8.0;

  double getOverscanPercent() =>
      (_prefs.getDouble(_kOverscanPercent) ?? overscanPercentDefault)
          .clamp(0.0, overscanPercentMax);

  late final ValueNotifier<double> overscan =
      ValueNotifier<double>(getOverscanPercent());

  Future<void> setOverscanPercent(double v) async {
    final clamped = v.clamp(0.0, overscanPercentMax);
    overscan.value = clamped;
    await _prefs.setDouble(_kOverscanPercent, clamped);
  }

  // ── Person-scoped preferences blob (server-synced per profile) ────────────

  String _pid() => _interceptor.profileId ?? '';
  static String _blobKey(String pid) => '$_kProfilePrefsBlob@$pid';
  // Set when a push is attempted, cleared when it succeeds. A profile whose
  // flag is still set on the next sync has local edits that never reached
  // the server — they get retried instead of being overwritten by the
  // (older) server copy.
  static String _dirtyKey(String pid) => '$_kProfilePrefsBlob.dirty@$pid';

  void _push(String pid, String json) {
    _pushProfilePrefs(pid, json).then((_) {
      _prefs.remove(_dirtyKey(pid));
    }).catchError((_) {
      // Kept dirty; retried on the next settings change or profile sync.
    });
  }

  ProfilePrefs _cachedBlob = ProfilePrefs.empty;
  String _cachedBlobPid = '';

  ProfilePrefs get _blob {
    final pid = _pid();
    if (pid.isEmpty) return ProfilePrefs.empty;
    if (pid != _cachedBlobPid) {
      _cachedBlobPid = pid;
      _cachedBlob =
          ProfilePrefs.fromJson(_prefs.getString(_blobKey(pid)) ?? '');
    }
    return _cachedBlob;
  }

  /// Reconciles a profile's server-synced prefs blob with the local copy —
  /// called by AuthRepository.syncProfilesFromServer for every profile it
  /// gets back.
  ///
  /// - If this device still has an un-pushed local edit for the profile
  ///   (dirty flag set), the local copy wins: retry the push, keep local.
  ///   Last-write-wins is fine here — one person per profile.
  /// - Else if the server has nothing yet but the profile has local
  ///   `key@$pid` subtitle values (set before prefs became server-synced),
  ///   seed the blob from them and push once (one-time migration).
  /// - Else adopt the server copy.
  Future<void> cacheProfilePrefsBlob(String profileId, String prefsJson) async {
    if (_prefs.getBool(_dirtyKey(profileId)) ?? false) {
      final localJson = _prefs.getString(_blobKey(profileId)) ?? '{}';
      _push(profileId, localJson);
      _applyBlob(profileId, ProfilePrefs.fromJson(localJson));
      return;
    }
    var prefs = ProfilePrefs.fromJson(prefsJson);
    if (prefs.isEmpty) {
      final seeded = _seedFromLocal(profileId);
      if (!seeded.isEmpty) {
        prefs = seeded;
        await _prefs.setBool(_dirtyKey(profileId), true);
        _push(profileId, seeded.toJson());
      }
    }
    await _prefs.setString(_blobKey(profileId), prefs.toJson());
    _applyBlob(profileId, prefs);
  }

  void _applyBlob(String profileId, ProfilePrefs prefs) {
    if (profileId == _pid()) {
      _cachedBlobPid = profileId;
      _cachedBlob = prefs;
    }
  }

  ProfilePrefs _seedFromLocal(String pid) => ProfilePrefs(
        subtitleFontSize: _prefs.getDouble('$_kSubtitleFontSize@$pid'),
        subtitleColorArgb: _prefs.getInt('$_kSubtitleColorArgb@$pid'),
        subtitleBgEnabled: _prefs.getBool('$_kSubtitleBgEnabled@$pid'),
        subtitleBottomPadding:
            _prefs.getDouble('$_kSubtitleBottomPadding@$pid'),
      );

  Timer? _pushDebounce;

  Future<void> _updateBlob(ProfilePrefs Function(ProfilePrefs) f) async {
    final pid = _pid();
    if (pid.isEmpty) return;
    final next = f(_blob);
    _cachedBlobPid = pid;
    _cachedBlob = next;
    final json = next.toJson();
    await _prefs.setString(_blobKey(pid), json);
    await _prefs.setBool(_dirtyKey(pid), true);
    // Debounced so dragging a slider doesn't spam the RPC; the local value
    // above is already applied and offline-safe regardless.
    _pushDebounce?.cancel();
    _pushDebounce =
        Timer(const Duration(milliseconds: 600), () => _push(pid, json));
  }

  String _scoped(String base) {
    final pid = _pid();
    return pid.isEmpty ? base : '$base@$pid';
  }

  /// Releases the debounce timer and the [overscan] notifier. Wired to
  /// get_it's `dispose:` hook: the startup-error "Riprova" path does
  /// `getIt.reset()` and builds a fresh repo — without this the abandoned
  /// instance's `_pushDebounce` Timer still fires, into a now-dead `_push`
  /// closure.
  void dispose() {
    _pushDebounce?.cancel();
    overscan.dispose();
  }

  // Read order for the four subtitle settings: server-synced blob → local
  // per-profile copy → old unscoped key (pre-per-profile) → hardcoded
  // default (matches playback_screen.dart's original values, so first-run
  // behaviour is unchanged until the user opens Preferenze).
  double getSubtitleFontSize() =>
      _blob.subtitleFontSize ??
      _prefs.getDouble(_scoped(_kSubtitleFontSize)) ??
      _prefs.getDouble(_kSubtitleFontSize) ??
      32.0;
  Future<void> setSubtitleFontSize(double v) async {
    await _prefs.setDouble(_scoped(_kSubtitleFontSize), v);
    await _updateBlob((b) => b.copyWith(subtitleFontSize: v));
  }

  Color getSubtitleColor() => Color(_blob.subtitleColorArgb ??
      _prefs.getInt(_scoped(_kSubtitleColorArgb)) ??
      _prefs.getInt(_kSubtitleColorArgb) ??
      Colors.white.toARGB32());
  Future<void> setSubtitleColor(Color c) async {
    await _prefs.setInt(_scoped(_kSubtitleColorArgb), c.toARGB32());
    await _updateBlob((b) => b.copyWith(subtitleColorArgb: c.toARGB32()));
  }

  bool getSubtitleBgEnabled() =>
      _blob.subtitleBgEnabled ??
      _prefs.getBool(_scoped(_kSubtitleBgEnabled)) ??
      _prefs.getBool(_kSubtitleBgEnabled) ??
      true;
  Future<void> setSubtitleBgEnabled(bool v) async {
    await _prefs.setBool(_scoped(_kSubtitleBgEnabled), v);
    await _updateBlob((b) => b.copyWith(subtitleBgEnabled: v));
  }

  double getSubtitleBottomPadding() =>
      _blob.subtitleBottomPadding ??
      _prefs.getDouble(_scoped(_kSubtitleBottomPadding)) ??
      _prefs.getDouble(_kSubtitleBottomPadding) ??
      80.0;
  Future<void> setSubtitleBottomPadding(double v) async {
    await _prefs.setDouble(_scoped(_kSubtitleBottomPadding), v);
    await _updateBlob((b) => b.copyWith(subtitleBottomPadding: v));
  }
}
