import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/db/models/device_session.dart';
import '../../../core/di/injection.dart';
import '../../../core/grpc/auth_interceptor.dart';
import '../../../core/grpc/grpc_errors.dart' show isUnauthenticated;
import '../../media/active_plugin_controller.dart';
import '../../media/bloc/continue_watching_bloc.dart';
import '../../media/bloc/continue_watching_event.dart';
import '../../media/bloc/discovery_bloc.dart';
import '../../media/bloc/discovery_event.dart';
import '../../media/bloc/discovery_state.dart';
import '../../media/bloc/plugin_bloc.dart';
import '../../media/bloc/plugin_event.dart';
import '../../media/bloc/plugin_state.dart';
import '../../media/data/media_repository.dart';
import '../data/auth_repository.dart';
import '../friendly_error.dart';
import 'auth_event.dart';
import 'auth_state.dart';

// flutter_bloc's default transformer runs handlers concurrently. None of
// these three screens (PIN entry, device pairing, add-profile) disable
// their submit control while awaiting, so a rapid double-Enter on a remote
// fires two overlapping gRPC calls — worst case a duplicate profile or two
// competing auth attempts racing to emit conflicting states. Each call
// below gets its own transformer instance (own `isBusy`), so the three
// event types don't block each other, only duplicates of themselves.
EventTransformer<E> _droppable<E>() {
  var isBusy = false;
  return (events, mapper) {
    return events.asyncExpand((event) {
      if (isBusy) return const Stream.empty();
      isBusy = true;
      return mapper(event).transform(
        StreamTransformer.fromHandlers(handleDone: (sink) {
          isBusy = false;
          sink.close();
        }),
      );
    });
  };
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthRepository _repo;

  // ignore: avoid_setters_without_getters
  set repository(AuthRepository r) => _repo = r;

  AuthBloc(this._repo) : super(const AuthInitial()) {
    on<AppStartedEvent>(_onAppStarted);
    on<AuthenticateDeviceEvent>(_onAuthenticateDevice,
        transformer: _droppable());
    on<SelectProfileEvent>(_onSelectProfile, transformer: _droppable());
    on<LogoutEvent>(_onLogout);
    on<ChangeServerEvent>(_onChangeServer);
    on<SwitchProfileEvent>(_onSwitchProfile);
    on<CreateProfileEvent>(_onCreateProfile, transformer: _droppable());
    on<SessionExpiredEvent>(_onSessionExpired);
    on<ProfileLockedEvent>(_onProfileLocked);
  }

  // getStoredSession()/getLocalProfiles() below are local reads (shared
  // prefs / Isar) and typically resolve in single-digit milliseconds — fast
  // enough that the splash screen's own reveal animation (see
  // splash_screen.dart) would never get a chance to actually play, since
  // both it and PileusApp's root listener (main.dart) navigate away the
  // instant this handler emits its terminal state. Padding the handler out
  // to a floor keeps the splash on screen for at least one full pass of its
  // animation no matter how fast the underlying lookup is — a UI-timing
  // concern, but it has to live here rather than in the widget because two
  // independent listeners react to this same state and neither can hold the
  // other back.
  // Public (not the original `_minSplashDuration`) so splash_screen.dart can
  // reference this single value instead of keeping its own manually
  // synced copy (`_kSplashDuration`) — the two used to drift by construction
  // any time one was tuned without remembering the other.
  static const minSplashDuration = Duration(milliseconds: 2000);

  // Upper bound on top of minSplashDuration for _waitForPluginsReady below —
  // generous enough for a real gRPC round-trip over a slow LAN/Wi-Fi link
  // (plugin discovery + each plugin's own reachability probe), short enough
  // that an unreachable/hung server doesn't strand the user on the splash
  // screen indefinitely.
  static const _pluginsReadyTimeout = Duration(seconds: 8);

  // Blocks until PluginBloc reaches a terminal state (loaded or errored) or
  // _pluginsReadyTimeout elapses, whichever comes first — see the call site
  // in _onAppStarted for why this matters (the splash should gate on the
  // home screen actually being ready, not just a fixed cosmetic duration).
  Future<void> _waitForPluginsReady() async {
    final bloc = getIt<PluginBloc>();
    if (bloc.state is PluginsLoaded || bloc.state is PluginError) return;
    await bloc.stream
        .firstWhere((s) => s is PluginsLoaded || s is PluginError)
        .timeout(_pluginsReadyTimeout, onTimeout: () => bloc.state);
  }

  // Separate, independent timeout from _pluginsReadyTimeout — this is a
  // second network round-trip (the actual first catalog page) layered on
  // top of the plugin list, not the same wait.
  static const _firstCatalogReadyTimeout = Duration(seconds: 8);

  // Best-effort: get the very first catalog row (first plugin, first
  // catalog — the same one HomeScreen's _PluginPageBody._initBlocs mounts
  // first, see its _acquireDiscoveryBloc) actually loaded before the splash
  // hands off, so the home screen's first carousel shows real items
  // (poster URLs already handed to CachedNetworkImage) instead of sitting
  // on its own empty/skeleton state for another round-trip after the
  // splash is already gone. Deliberately scoped to just this one catalog,
  // not every catalog of every plugin — the rest still load progressively
  // inside HomeScreen exactly as before (same as any catalog app's
  // thumbnails popping in while you scroll — not attempting to preload
  // every image up front, that's a much larger and lower-value undertaking).
  Future<void> _prewarmFirstCatalog() async {
    final pluginState = getIt<PluginBloc>().state;
    if (pluginState is! PluginsLoaded || pluginState.plugins.isEmpty) return;
    final plugin = pluginState.plugins.first;
    if (plugin.catalogs.isEmpty) return;
    final catalog = plugin.catalogs.first;
    // Named instance — not the plain DiscoveryBloc registration used
    // everywhere else (registerFactory, a fresh instance per call) — so
    // this doesn't collide with it. HomeScreen looks for this exact name
    // and adopts it (unregistering it from getIt in the process) instead
    // of creating a fresh bloc, so the dispatch below isn't wasted.
    final key = '${plugin.pluginId}::${catalog.id}';
    if (!getIt.isRegistered<DiscoveryBloc>(instanceName: key)) {
      getIt.registerLazySingleton<DiscoveryBloc>(
        () => DiscoveryBloc(
          getIt<MediaRepository>(),
          onSessionExpired: () => add(const SessionExpiredEvent()),
        ),
        instanceName: key,
      );
    }
    final bloc = getIt<DiscoveryBloc>(instanceName: key);
    if (bloc.state is DiscoveryLoaded || bloc.state is DiscoveryError) return;
    bloc.add(LoadCatalogEvent(
      pluginId: plugin.pluginId,
      catalogId: catalog.id,
      cacheTtlSeconds: catalog.cacheTtlSeconds,
    ));
    await bloc.stream
        .firstWhere((s) => s is DiscoveryLoaded || s is DiscoveryError)
        .timeout(_firstCatalogReadyTimeout, onTimeout: () => bloc.state);
  }

  // ─── Device JWT refresh ────────────────────────────────────
  // mycelium-core's device JWT expires 30 days after pairing (or the last
  // refresh) and, since the same server release, re-pairing an
  // already-known device_id wipes every PIN trust/session that device held
  // (a rotating pairing code is for a device authorizing for the first
  // time, not for renewing one already paired) — so letting the JWT lapse,
  // as Pileus always did before this, silently forced the PIN back on every
  // protected profile once a month, on every platform. Checked once at
  // every cold start ([_onAppStarted], right after confirming the stored
  // session is still valid) and every [_refreshCheckInterval] thereafter
  // while a session stays authorized; only actually calls RefreshToken once
  // less than [_refreshMargin] remains, so most checks are a no-op local
  // read. Best-effort like unpairSelf/lockProfile: anything other than an
  // UNAUTHENTICATED response (unreachable server, timeout, …) is silently
  // left for the next check — never surfaced to the user.
  static const _refreshMargin = Duration(days: 7);
  static const _refreshCheckInterval = Duration(hours: 12);
  Timer? _refreshTimer;

  Future<void> _refreshIfDue(DeviceSession session) async {
    if (!session.isAuthorized || session.expiresAtTimestamp <= 0) return;
    final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (session.expiresAtTimestamp - nowSecs > _refreshMargin.inSeconds) {
      return;
    }
    try {
      await _repo.refreshToken();
    } catch (e) {
      // Device revoked/deleted server-side since it last checked in — same
      // recovery as any other mid-session 401.
      if (isUnauthenticated(e)) add(const SessionExpiredEvent());
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshCheckInterval, (_) async {
      final session = await _repo.getStoredSession();
      if (session != null) await _refreshIfDue(session);
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  Future<void> close() {
    _stopRefreshTimer();
    return super.close();
  }

  Future<void> _onAppStarted(
      AppStartedEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final started = DateTime.now();
    Future<void> floor() async {
      if (!event.splashFloor) return;
      final elapsed = DateTime.now().difference(started);
      if (elapsed < minSplashDuration) {
        await Future<void>.delayed(minSplashDuration - elapsed);
      }
    }

    try {
      final session = await _repo.getStoredSession();
      // expiresAtTimestamp is populated at pairing time but was never
      // actually checked here — a JWT that expired while the app was closed
      // used to be treated as still "authorized" until the first real gRPC
      // call came back 401 (SessionExpiredEvent), which meant flashing the
      // profile picker before bouncing back to /pairing a moment later.
      final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expired = session != null &&
          session.expiresAtTimestamp > 0 &&
          session.expiresAtTimestamp <= nowSecs;
      if (session == null || !session.isAuthorized || expired) {
        await floor();
        if (session?.grpcHost == null) {
          emit(const ServerDiscoveryRequired());
        } else {
          emit(const DevicePairingRequired());
        }
        return;
      }
      // Best-effort, never awaited past this point — see "Device JWT
      // refresh" above. Started here (not only on the fast path below) so
      // it covers the profile-picker branch too, not just an immediate
      // auto-login.
      _startRefreshTimer();
      unawaited(_refreshIfDue(session));
      var profiles = await _repo.getLocalProfiles();
      // Skip the picker straight to the remembered profile (set on every
      // successful pick / first-ever creation, see setLastActiveProfile).
      // Falls through to the picker if the remembered id no longer matches
      // any profile (e.g. it was deleted).
      //
      // Computed *before* floor() (unlike the branch above) specifically so
      // the "going straight to /home" case can be known this early: that
      // lets the home screen's own data start loading right here, in
      // parallel with the rest of the floor() wait below, instead of only
      // starting once HomeScreen actually mounts after navigation.
      final rememberedProfile = session.lastActiveProfileId == null
          ? null
          : profiles
              .where((p) => p.profileId == session.lastActiveProfileId)
              .firstOrNull;
      // A remembered default that's PIN-protected and this device isn't
      // unlocked/trusted for (pinProtected/unlocked are cached snapshots of
      // ProfileResponse's per-device flags — see LocalProfile's doc) can't
      // auto-enter: fall through to the picker with the PIN dialog already
      // open on it instead. The typical case — a trusted family device on
      // an unprotected or already-trusted profile — is unaffected and
      // enters exactly as before.
      final lockedDefault = rememberedProfile != null &&
          rememberedProfile.pinProtected &&
          !rememberedProfile.unlocked;
      final defaultProfile = lockedDefault ? null : rememberedProfile;
      if (defaultProfile != null) {
        // Must happen before LoadPluginsEvent below: PluginBloc's first
        // listPlugins() reads the plugin-order cache key scoped by
        // AuthInterceptor.profileId (see MediaRepository._pluginOrderKey).
        // Without this, that first fetch still had the empty profileId set
        // by getStoredSession() above (deliberately blank there — see
        // AuthRepository.getStoredSession — just enough for a valid JWT),
        // so it read the unscoped/wrong-profile order and showed it until
        // the next 30s poll corrected it. main.dart's own
        // setCredentials(...) call once AuthenticatedState is emitted below
        // is now redundant with this one, but harmless.
        getIt<AuthInterceptor>()
            .setCredentials(session.deviceJwt, defaultProfile.profileId);
        getIt<PluginBloc>().add(const LoadPluginsEvent());
        getIt<ContinueWatchingBloc>().add(const LoadContinueWatchingEvent());
      }
      await floor();
      if (defaultProfile != null) {
        // The splash is meant to actually gate on the home screen being
        // ready, not just hold for a fixed cosmetic duration — otherwise
        // "loading" happens twice: once behind the splash's lockup, once
        // again behind HomeScreen's own spinner a moment later. Bounded by
        // _kPluginsReadyTimeout so an unreachable server can't turn this
        // into an infinite splash: past that, fall through to /home anyway,
        // which already has its own error/retry UI for a plugin list that
        // never loaded.
        await _waitForPluginsReady();
        await _prewarmFirstCatalog();
        emit(AuthenticatedState(
          jwt: session.deviceJwt,
          activeProfileId: defaultProfile.profileId,
        ));
        return;
      }
      // About to show the picker (no remembered profile, or it was deleted).
      // Profiles are now server-wide — a profile created on another device
      // won't be in this device's local cache — so refresh from the server
      // before showing the list. Best-effort: a failure here must NOT bounce
      // a device with a valid session to discovery (the outer catch does
      // that), so fall back to the cached list.
      try {
        profiles = await _repo.syncProfilesFromServer();
      } catch (_) {/* keep the local list */}
      emit(ProfileSelectionRequired(profiles,
          openPinForProfileId:
              lockedDefault ? rememberedProfile.profileId : null));
    } catch (_) {
      await floor();
      emit(const ServerDiscoveryRequired());
    }
  }

  Future<void> _onAuthenticateDevice(
    AuthenticateDeviceEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repo.authorizeDevice(event.pin);
      // A fresh pairing this session never goes through _onAppStarted's own
      // start call — this is the only other place a device becomes
      // authorized, so it starts the refresh timer too.
      _startRefreshTimer();
      // Fetch profiles from server and sync to the local cache.
      final profiles = await _repo.syncProfilesFromServer();
      emit(ProfileSelectionRequired(profiles));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSelectProfile(
    SelectProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    final profiles = await _repo.getLocalProfiles();
    final profile =
        profiles.where((p) => p.profileId == event.profileId).firstOrNull;

    if (profile == null) {
      emit(const AuthError('Profilo non trovato'));
      return;
    }

    final session = await _repo.getStoredSession();
    if (session == null) {
      emit(const DevicePairingRequired());
      return;
    }
    // Point the interceptor at the picked profile *before* anything reloads
    // — MediaRepository keys the plugin-order preference (and, going
    // forward, per-plugin catalog prefs) by AuthInterceptor.profileId, so a
    // reload that races ahead of this would read the previous profile's
    // order. main.dart's app-wide listener also calls this on the emit
    // below; doing it here too is redundant but harmless.
    getIt<AuthInterceptor>().setCredentials(session.deviceJwt, event.profileId);
    // PluginBloc / ContinueWatchingBloc are session-long singletons warmed
    // by _onAppStarted's fast path. On a profile switch they'd otherwise
    // keep serving the previous profile's plugin list/order and
    // continue-watching rows until the next 30s poll happened to correct
    // them — reset them so the incoming HomeScreen loads this profile's data
    // from scratch (same reset the logout path already does).
    await _resetHomePrefetchBlocs();
    // Deliberately does NOT call setLastActiveProfile — the "default"
    // profile is an explicit choice made only via the toggle in
    // profile_settings_screen.dart (or first-time setup, see
    // _onCreateProfile below). Auto-updating it on every pick used to make
    // whichever profile you last opened silently become "default", which
    // read as several profiles being flagged at once as you switched
    // between them.
    emit(AuthenticatedState(
      jwt: session.deviceJwt,
      activeProfileId: event.profileId,
    ));
  }

  // Best-effort LockProfile for whichever profile is currently active,
  // called right before actually leaving it (logout/change-server/switch-
  // profile) — never blocks or throws, same fire-and-forget spirit as
  // AuthRepository.unpairSelf. A no-op if no profile is active (e.g. logout
  // from the picker itself, before any profile was ever selected).
  //
  // Also releases this device's single-device playback lease (contract "One
  // device playing per profile") for the same reason: leaving the profile
  // (not just switching episodes) should free it at once rather than
  // leaving it to lapse ~90s later — a player screen still open at this
  // point already released it on its own dispose, but logout/switch-profile
  // can also be triggered from elsewhere (e.g. the settings screen) with no
  // player in the tree to do that, so this is the catch-all.
  Future<void> _lockActiveProfile() async {
    getIt<MediaRepository>().releasePlayback();
    final profileId = getIt<AuthInterceptor>().profileId;
    if (profileId == null || profileId.isEmpty) return;
    await _repo.lockProfile(profileId);
    getIt<AuthInterceptor>().clearProfileSessionToken();
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    _stopRefreshTimer();
    await _lockActiveProfile();
    await _repo.logout();
    await _resetHomePrefetchBlocs();
    emit(const DevicePairingRequired());
  }

  Future<void> _onChangeServer(
      ChangeServerEvent event, Emitter<AuthState> emit) async {
    _stopRefreshTimer();
    // Fire-and-forget, and strictly before forgetServer(): once that runs,
    // the host/JWT/TLS fingerprint this call needs are gone. Never awaited —
    // "Cambia server" is instant today and a slow/unreachable old server
    // must not add any delay to leaving it (see AuthRepository.unpairSelf's
    // doc for why it's also fine for this to silently fail).
    unawaited(_lockActiveProfile());
    unawaited(_repo.unpairSelf());
    await _repo.forgetServer();
    await _resetHomePrefetchBlocs();
    // main.dart's app-wide listener routes this to /discovery. Once a new
    // host is saved there, ServerDiscoveryScreen calls rebuildGrpcClients(),
    // which points this bloc's `repository` at the new channel.
    emit(const ServerDiscoveryRequired());
  }

  // PluginBloc/ContinueWatchingBloc are lazy singletons (see injection.dart)
  // kept alive across the whole app session so _onAppStarted's authenticated
  // branch can prefetch into them before HomeScreen even mounts. Without
  // this reset, logging out and back in (as a different account/profile on
  // the same device) would leave the next home screen looking at whatever
  // the previous session last loaded until a fresh Load*Event resolves.
  Future<void> _resetHomePrefetchBlocs() async {
    await getIt.resetLazySingleton<PluginBloc>(
        disposingFunction: (b) => b.close());
    await getIt.resetLazySingleton<ContinueWatchingBloc>(
        disposingFunction: (b) => b.close());
    // Mobile-only: the plugin id picked here belongs to the account just
    // logged out of — same staleness this whole method exists to avoid for
    // Plugin/ContinueWatchingBloc above. A no-op on TV/desktop/web, which
    // never register it (lazy singleton, only ever instantiated by mobile's
    // Home/Cerca tabs).
    if (getIt.isRegistered<ActivePluginController>()) {
      await getIt.resetLazySingleton<ActivePluginController>(
          disposingFunction: (c) => c.dispose());
    }
  }

  Future<void> _onSwitchProfile(
      SwitchProfileEvent event, Emitter<AuthState> emit) async {
    // The device jwt in AuthInterceptor stays put — it's device-level, not
    // profile-level (see _onSelectProfile, which reuses session.deviceJwt
    // for every profile). Only the profile picker needs to come back up.
    await _lockActiveProfile();
    final profiles = await _repo.getLocalProfiles();
    emit(ProfileSelectionRequired(profiles));
  }

  Future<void> _onCreateProfile(
      CreateProfileEvent event, Emitter<AuthState> emit) async {
    try {
      final response =
          await _repo.createProfile(name: event.name, avatarUrl: '');
      final profiles = await _repo.syncProfilesFromServer();
      // First-time setup: the very first profile a fresh install creates
      // becomes the remembered default (see _onAppStarted), so day-two
      // launches skip straight past the picker. Later profiles don't
      // silently steal the default away from whichever one the user is
      // actually using — picking one from the grid (_onSelectProfile) is
      // what changes it after that.
      final session = await _repo.getStoredSession();
      if (session != null && session.lastActiveProfileId == null) {
        await _repo.setLastActiveProfile(response.profileId);
      }
      emit(ProfileSelectionRequired(profiles));
    } catch (e) {
      emit(AuthError(friendlyOperationErrorMessage(e.toString())));
    }
  }

  Future<void> _onSessionExpired(
      SessionExpiredEvent event, Emitter<AuthState> emit) async {
    _stopRefreshTimer();
    await _repo.logout();
    await _resetHomePrefetchBlocs();
    emit(const DevicePairingRequired(
        reason: 'Sessione scaduta — ripeti l\'abbinamento del dispositivo.'));
  }

  // The active profile's PIN lease/trust stopped covering this device mid-
  // session (idle timeout past 4h, trust revoked from the dashboard, PIN
  // changed elsewhere) — every media bloc/repo call routes here the same way
  // they route isUnauthenticated to SessionExpiredEvent (see grpc_errors.
  // dart's isProfileLocked doc). The device pairing/JWT are still fine, so
  // this only drops the (now-invalid) PIN session and bounces to the picker
  // with the dialog open again — not all the way to device pairing, and
  // deliberately no LockProfile call: the server already considers this
  // device locked out, there is nothing left here to unwind.
  Future<void> _onProfileLocked(
      ProfileLockedEvent event, Emitter<AuthState> emit) async {
    getIt<AuthInterceptor>().clearProfileSessionToken();
    final profiles = await _repo.getLocalProfiles();
    emit(ProfileSelectionRequired(profiles,
        openPinForProfileId: event.profileId));
  }
}
