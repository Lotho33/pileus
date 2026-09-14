import 'dart:async' show unawaited;

import 'package:get_it/get_it.dart';
import 'package:grpc/service_api.dart' show ClientChannel;
import 'package:shared_preferences/shared_preferences.dart';

import '../db/models/device_session.dart';
import '../grpc/auth_interceptor.dart';
import '../grpc/clients/auth_client.dart';
import '../grpc/clients/media_client.dart';
import '../grpc/grpc_channel.dart';
import '../grpc/host_resolver.dart';
import '../update/update_service.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/media/active_plugin_controller.dart';
import '../../features/media/bloc/continue_watching_bloc.dart';
import '../../features/media/bloc/details_bloc.dart';
import '../../features/media/bloc/discovery_bloc.dart';
import '../../features/media/bloc/plugin_bloc.dart';
import '../../features/media/data/media_repository.dart';
import '../../features/player/bloc/playback_bloc.dart';
import '../../features/player/playback_episode_cache.dart';
import '../../features/settings/bloc/profile_management_cubit.dart';
import '../../features/settings/bloc/settings_cubit.dart';
import '../../features/settings/data/settings_repository.dart';

final GetIt getIt = GetIt.instance;

// Tracks the channel currently backing AuthGrpcClient/MediaGrpcClient so
// rebuildGrpcClients can shut the old one down instead of leaking it — see
// rebuildGrpcClients for why this matters.
// The abstract ClientChannel interface from service_api.dart (NOT the
// concrete http2 ClientChannel from package:grpc/grpc.dart): both
// createGrpcChannel() results — native ClientChannel and web
// GrpcWebClientChannel — implement it, and it pulls no dart:io, so this
// storage + the client ctors below stay web-compilable.
ClientChannel? _currentChannel;

Future<void> configureDependencies() async {
  // 1. Storage locale (device session / local profiles / layout cache / prefs)
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  // 2. Interceptor JWT (singleton — aggiornato post-login)
  final interceptor = AuthInterceptor();
  getIt.registerSingleton<AuthInterceptor>(interceptor);

  // 3. Canale gRPC — risolve host LAN/VPN in background
  final host = await resolveGrpcHost();
  interceptor.setGrpcHost(host);
  // resolveGrpcHost is a plain TCP reachability probe (no /pileus/info
  // round-trip), so the pinned TLS fingerprint — if any — comes from the
  // last time ServerDiscoveryScreen actually fetched /pileus/info and
  // saved it alongside grpcHost, not from this resolution itself.
  //
  // DeviceSession.readFrom is the same shared decode helper AuthRepository
  // uses internally — reused here rather than duplicating the JSON shape.
  String? tlsFingerprint;
  try {
    tlsFingerprint = DeviceSession.readFrom(prefs)?.tlsFingerprint;
  } catch (_) {}
  final channel = createGrpcChannel(host: host, tlsFingerprint: tlsFingerprint);
  _currentChannel = channel;

  // 4. Client gRPC
  getIt.registerLazySingleton<AuthGrpcClient>(
      () => AuthGrpcClient(channel, interceptor));
  getIt.registerLazySingleton<MediaGrpcClient>(
      () => MediaGrpcClient(channel, interceptor));

  // 5. Repository
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
        prefs, getIt<AuthGrpcClient>(), getIt<AuthInterceptor>()),
  );
  getIt.registerLazySingleton<MediaRepository>(
    () => MediaRepository(prefs, getIt<AuthInterceptor>())
      ..onSessionExpired =
          () => getIt<AuthBloc>().add(const SessionExpiredEvent()),
  );
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepository(
      getIt<SharedPreferences>(),
      getIt<AuthInterceptor>(),
      // Resolved per-call, not captured: AuthRepository is re-registered by
      // rebuildGrpcClients on a server switch.
      (pid, json) => getIt<AuthRepository>().setProfilePreferences(pid, json),
    ),
    dispose: (r) => r.dispose(),
  );
  // In-app "newer release available" check (best-effort, no-op unless
  // UpdateConfig is pointed at a GitHub repo — see core/update/).
  getIt.registerLazySingleton<UpdateService>(
    () => UpdateService(getIt<SharedPreferences>()),
    dispose: (s) => s.dispose(),
  );

  // 6. BLoC — AuthBloc è singleton: stato condiviso su tutte le schermate.
  // PluginBloc/ContinueWatchingBloc sono anch'essi lazy singleton (non più
  // factory) così AuthBloc può "svegliarli" dallo splash — prima che
  // HomeScreen sia montata — e HomeScreen ritrova la stessa istanza già
  // (o quasi) carica invece di ripartire da zero. Vanno azzerati con
  // resetLazySingleton su logout (vedi AuthBloc._onLogout/_onSessionExpired)
  // per non far trapelare i dati dell'account precedente al prossimo login.
  getIt.registerSingleton<AuthBloc>(AuthBloc(getIt<AuthRepository>()),
      dispose: (b) => b.close());
  getIt.registerLazySingleton<ContinueWatchingBloc>(
    () => ContinueWatchingBloc(getIt<MediaRepository>()),
  );
  getIt.registerFactory<DiscoveryBloc>(() => DiscoveryBloc(
        getIt<MediaRepository>(),
        onSessionExpired: () =>
            getIt<AuthBloc>().add(const SessionExpiredEvent()),
      ));
  getIt.registerFactory<DetailsBloc>(() => DetailsBloc(
        getIt<MediaRepository>(),
        onSessionExpired: () =>
            getIt<AuthBloc>().add(const SessionExpiredEvent()),
      ));
  getIt.registerLazySingleton<PluginBloc>(() => PluginBloc(
        getIt<MediaRepository>(),
        onSessionExpired: () =>
            getIt<AuthBloc>().add(const SessionExpiredEvent()),
      ));
  // Mobile-only (Home/Cerca tab sync — see the class doc), registered here
  // like everything else so it's reset alongside the rest on logout; a
  // lazy singleton never instantiates at all on TV/desktop/web, which never
  // call getIt<ActivePluginController>().
  getIt.registerLazySingleton<ActivePluginController>(
      () => ActivePluginController());
  getIt.registerFactory<PlaybackBloc>(() => PlaybackBloc(
        getIt<MediaRepository>(),
        onSessionExpired: () =>
            getIt<AuthBloc>().add(const SessionExpiredEvent()),
      ));
  getIt.registerFactory<SettingsCubit>(
      () => SettingsCubit(getIt<SettingsRepository>()));
  getIt.registerFactory<ProfileManagementCubit>(
    () => ProfileManagementCubit(
      getIt<AuthRepository>(),
      onSessionExpired: () =>
          getIt<AuthBloc>().add(const SessionExpiredEvent()),
    ),
  );
}

/// Ricrea AuthGrpcClient e MediaGrpcClient sul nuovo host.
/// Chiamare dopo che ServerDiscoveryScreen ha salvato l'host.
Future<void> rebuildGrpcClients(String host, {String? tlsFingerprint}) async {
  final interceptor = getIt<AuthInterceptor>();
  // `_grpcHost` is otherwise set once at startup (configureDependencies) and
  // never again — mycelium reads `x-http-host` (sent on every call, see
  // AuthInterceptor._inject) to build the image-proxy URLs in its catalog
  // responses. Without updating it here, switching server left every
  // request still advertising the *old* host: posters/fanart from the new
  // server's responses pointed at a host that was no longer reachable,
  // until the app was restarted (2026-09 audit).
  interceptor.setGrpcHost(host);
  // The player's prev/next episode-list cache is keyed by plugin+parent id
  // only — those ids belong to the server we're leaving, so drop them.
  clearPlaybackEpisodeCache();
  final prefs = getIt<SharedPreferences>();
  final oldChannel = _currentChannel;
  final channel = createGrpcChannel(host: host, tlsFingerprint: tlsFingerprint);
  _currentChannel = channel;
  // Every call here used to leave the previous HTTP/2 connection open until
  // its own 30s idle timeout — harmless once, but re-discovery can happen
  // more than once per session (network change, retried scan), and each
  // leaked connection is a real cost on TV-box-class RAM. Fire-and-forget:
  // a graceful shutdown, errors ignored — nothing here should block getting
  // the new clients registered.
  if (oldChannel != null) {
    unawaited(oldChannel.shutdown().catchError((_) {}));
  }

  if (getIt.isRegistered<AuthGrpcClient>()) {
    await getIt.unregister<AuthGrpcClient>();
  }
  if (getIt.isRegistered<MediaGrpcClient>()) {
    await getIt.unregister<MediaGrpcClient>();
  }
  if (getIt.isRegistered<AuthRepository>()) {
    await getIt.unregister<AuthRepository>();
  }
  if (getIt.isRegistered<MediaRepository>()) {
    await getIt.unregister<MediaRepository>();
  }

  getIt.registerLazySingleton<AuthGrpcClient>(
      () => AuthGrpcClient(channel, interceptor));
  getIt.registerLazySingleton<MediaGrpcClient>(
      () => MediaGrpcClient(channel, interceptor));
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
        prefs, getIt<AuthGrpcClient>(), getIt<AuthInterceptor>()),
  );
  getIt.registerLazySingleton<MediaRepository>(
    () => MediaRepository(prefs, getIt<AuthInterceptor>())
      ..onSessionExpired =
          () => getIt<AuthBloc>().add(const SessionExpiredEvent()),
  );

  // Aggiorna il repository nel bloc esistente senza ricrearlo —
  // così il BlocProvider.value in main.dart continua ad ascoltare il bloc corretto.
  if (getIt.isRegistered<AuthBloc>()) {
    getIt<AuthBloc>().repository = getIt<AuthRepository>();
  }
}
