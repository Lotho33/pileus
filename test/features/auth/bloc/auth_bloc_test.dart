import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show ClientChannel, GrpcError;
import 'package:pileus/core/db/models/device_session.dart';
import 'package:pileus/core/db/models/local_profile.dart';
import 'package:pileus/core/di/injection.dart' show getIt;
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/core/grpc/clients/auth_client.dart';
import 'package:pileus/core/grpc/clients/media_client.dart' show PluginInfo;
import 'package:pileus/features/auth/bloc/auth_bloc.dart';
import 'package:pileus/features/auth/bloc/auth_event.dart';
import 'package:pileus/features/auth/bloc/auth_state.dart';
import 'package:pileus/features/auth/data/auth_repository.dart';
import 'package:pileus/features/media/bloc/continue_watching_bloc.dart';
import 'package:pileus/features/media/bloc/plugin_bloc.dart';
import 'package:pileus/features/media/data/continue_watching_item.dart';
import 'package:pileus/features/media/data/media_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Empty-and-instant [MediaRepository] — just enough for AuthBloc's
/// authenticated fast path (_onAppStarted) to warm PluginBloc/
/// ContinueWatchingBloc and complete, without a real gRPC channel.
class _EmptyMediaRepository extends MediaRepository {
  _EmptyMediaRepository(super.prefs, super.interceptor);

  @override
  Future<List<PluginInfo>> listPlugins() async => const [];

  @override
  Future<List<ContinueWatchingItem>> getContinueWatching(
          {int limit = 20, String? parentId, String? pluginId}) async =>
      const [];
}

/// Scripted [AuthRepository] — overrides only what AuthBloc's handlers under
/// test actually call, same "subclass, don't mock" approach as
/// playback_bloc_test.dart's `_ScriptedMediaRepository` (no mocking package
/// in this project's dev_dependencies, and the base class has no interface
/// split to fake against).
class _ScriptedAuthRepository extends AuthRepository {
  _ScriptedAuthRepository(
    this.session,
    this.profiles,
    SharedPreferences prefs,
    AuthGrpcClient client,
    AuthInterceptor interceptor,
  ) : super(prefs, client, interceptor);

  final DeviceSession? session;
  final List<LocalProfile> profiles;
  // Device JWT refresh: scripted so tests can assert whether
  // AuthBloc actually called it, and simulate an UNAUTHENTICATED response
  // (device revoked/deleted server-side).
  int refreshTokenCalls = 0;
  Object? refreshTokenError;

  @override
  Future<DeviceSession?> getStoredSession() async => session;

  @override
  Future<List<LocalProfile>> getLocalProfiles() async => profiles;

  @override
  Future<List<LocalProfile>> syncProfilesFromServer() async => profiles;

  @override
  Future<void> refreshToken() async {
    refreshTokenCalls++;
    final err = refreshTokenError;
    if (err != null) throw err;
  }
}

LocalProfile _profile(
  String id, {
  bool pinProtected = false,
  bool unlocked = false,
}) =>
    LocalProfile()
      ..profileId = id
      ..profileName = 'Profile $id'
      ..pinProtected = pinProtected
      ..unlocked = unlocked;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late AuthInterceptor interceptor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    interceptor = AuthInterceptor();
    // AuthBloc._onProfileLocked/_lockActiveProfile read this straight off
    // getIt, same as production (main.dart's real wiring) — see
    // injection.dart's _dispatchProfileLocked.
    getIt.registerSingleton<AuthInterceptor>(interceptor);
    // _onAppStarted's authenticated fast path warms these two off getIt
    // (see its own doc) before emitting — needed only by the "still
    // auto-enters" test below, registered unconditionally since it's cheap
    // and harmless for the other tests, which never reach that branch.
    // Lazy (not eager) singletons, same as production's injection.dart —
    // AuthBloc._resetHomePrefetchBlocs (SessionExpiredEvent/logout) calls
    // getIt.resetLazySingleton on both, which throws against an eagerly
    // registered instance.
    final mediaRepo = _EmptyMediaRepository(prefs, interceptor);
    getIt.registerLazySingleton<PluginBloc>(() => PluginBloc(mediaRepo),
        dispose: (b) => b.close());
    getIt.registerLazySingleton<ContinueWatchingBloc>(
        () => ContinueWatchingBloc(mediaRepo),
        dispose: (b) => b.close());
  });

  tearDown(() async {
    await getIt.reset();
  });

  AuthGrpcClient buildClient() =>
      AuthGrpcClient(ClientChannel('localhost', port: 0), interceptor);

  group('AuthBloc._onAppStarted — profile PIN auto-entry gating',
      () {
    test(
        'a remembered default that is pin_protected && !unlocked does NOT '
        'auto-enter — the picker opens with its PIN dialog instead', () async {
      final session = DeviceSession()
        ..isAuthorized = true
        ..deviceJwt = 'jwt-token-xxxxxxxxxx'
        ..lastActiveProfileId = 'p1';
      final profiles = [_profile('p1', pinProtected: true, unlocked: false)];
      final repo = _ScriptedAuthRepository(
          session, profiles, prefs, buildClient(), interceptor);
      final bloc = AuthBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const AppStartedEvent(splashFloor: false));
      final state = await bloc.stream
          .firstWhere((s) => s is ProfileSelectionRequired || s is AuthenticatedState);

      expect(state, isA<ProfileSelectionRequired>());
      expect((state as ProfileSelectionRequired).openPinForProfileId, 'p1');
      expect(state.profiles, profiles);
    });

    test(
        'a remembered default that is pin_protected && unlocked (trusted '
        'device) still auto-enters exactly as an unprotected profile would '
        '— the typical "family TV" case', () async {
      final session = DeviceSession()
        ..isAuthorized = true
        ..deviceJwt = 'jwt-token-xxxxxxxxxx'
        ..lastActiveProfileId = 'p1';
      final profiles = [_profile('p1', pinProtected: true, unlocked: true)];
      final repo = _ScriptedAuthRepository(
          session, profiles, prefs, buildClient(), interceptor);
      final bloc = AuthBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const AppStartedEvent(splashFloor: false));
      final state = await bloc.stream.firstWhere((s) =>
          s is AuthenticatedState ||
          s is ProfileSelectionRequired ||
          s is ServerDiscoveryRequired);

      expect(state, isA<AuthenticatedState>());
      expect((state as AuthenticatedState).activeProfileId, 'p1');
    });
  });

  group('AuthBloc.ProfileLockedEvent', () {
    test(
        'bounces to the picker with openPinForProfileId set and clears the '
        'interceptor\'s PIN session token', () async {
      interceptor.setCredentials('jwt', 'p1');
      interceptor.setProfileSessionToken('stale-token');

      final profiles = [_profile('p1', pinProtected: true, unlocked: false)];
      final repo = _ScriptedAuthRepository(
          null, profiles, prefs, buildClient(), interceptor);
      final bloc = AuthBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const ProfileLockedEvent('p1'));
      final state =
          await bloc.stream.firstWhere((s) => s is ProfileSelectionRequired);

      expect((state as ProfileSelectionRequired).openPinForProfileId, 'p1');
      expect(
          interceptor.debugMetadataForTests.containsKey('x-profile-session'),
          isFalse);
      // Not a session-expired/re-pairing bounce — the JWT/pairing must
      // survive untouched (isProfileLocked's doc: distinct from
      // isUnauthenticated on purpose).
      expect(interceptor.jwt, 'jwt');
      expect(interceptor.profileId, 'p1');
    });
  });

  group('AuthBloc — device JWT refresh', () {
    int nowSecs() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

    test(
        '_onAppStarted calls RefreshToken when less than 7 days remain on '
        'the JWT', () async {
      final session = DeviceSession()
        ..isAuthorized = true
        ..deviceJwt = 'jwt-token-xxxxxxxxxx'
        ..expiresAtTimestamp = nowSecs() + const Duration(days: 1).inSeconds;
      final profiles = [_profile('p1')];
      final repo = _ScriptedAuthRepository(
          session, profiles, prefs, buildClient(), interceptor);
      final bloc = AuthBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const AppStartedEvent(splashFloor: false));
      await bloc.stream.firstWhere(
          (s) => s is ProfileSelectionRequired || s is AuthenticatedState);
      // The refresh check is fire-and-forget (unawaited) — give it a beat
      // to actually run before asserting on it.
      await Future<void>.delayed(Duration.zero);

      expect(repo.refreshTokenCalls, 1);
    });

    test(
        '_onAppStarted does NOT call RefreshToken when more than 7 days '
        'remain — most cold starts, so this must stay a cheap no-op',
        () async {
      final session = DeviceSession()
        ..isAuthorized = true
        ..deviceJwt = 'jwt-token-xxxxxxxxxx'
        ..expiresAtTimestamp = nowSecs() + const Duration(days: 20).inSeconds;
      final profiles = [_profile('p1')];
      final repo = _ScriptedAuthRepository(
          session, profiles, prefs, buildClient(), interceptor);
      final bloc = AuthBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const AppStartedEvent(splashFloor: false));
      await bloc.stream.firstWhere(
          (s) => s is ProfileSelectionRequired || s is AuthenticatedState);
      await Future<void>.delayed(Duration.zero);

      expect(repo.refreshTokenCalls, 0);
    });

    test(
        'a RefreshToken failing UNAUTHENTICATED (device revoked/deleted) '
        'bounces to pairing, same as any other mid-session 401', () async {
      final session = DeviceSession()
        ..isAuthorized = true
        ..deviceJwt = 'jwt-token-xxxxxxxxxx'
        ..expiresAtTimestamp = nowSecs() + const Duration(days: 1).inSeconds;
      final profiles = [_profile('p1')];
      final repo = _ScriptedAuthRepository(
          session, profiles, prefs, buildClient(), interceptor)
        ..refreshTokenError = const GrpcError.unauthenticated('device revoked');
      final bloc = AuthBloc(repo);
      addTearDown(bloc.close);

      // Captured from the start (not via a second `firstWhere` after the
      // first await) — the fire-and-forget refresh check can already have
      // bounced the bloc all the way to DevicePairingRequired by the time a
      // *new* stream subscription is set up, which would otherwise miss it
      // and hang forever waiting for an event that already happened.
      final states = <AuthState>[];
      final sub = bloc.stream.listen(states.add);
      addTearDown(sub.cancel);

      bloc.add(const AppStartedEvent(splashFloor: false));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (bloc.state is! DevicePairingRequired &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(bloc.state, isA<DevicePairingRequired>());
      // And it did pass through the picker first — the refresh check runs
      // only after the ordinary cold-start resolution already landed there,
      // it doesn't preempt it.
      expect(
          states.any(
              (s) => s is ProfileSelectionRequired || s is AuthenticatedState),
          isTrue);
    });

    test(
        'a RefreshToken failing any other way (unreachable, timeout) is '
        'silently left for the next check — never surfaced to the user',
        () async {
      final session = DeviceSession()
        ..isAuthorized = true
        ..deviceJwt = 'jwt-token-xxxxxxxxxx'
        ..expiresAtTimestamp = nowSecs() + const Duration(days: 1).inSeconds;
      final profiles = [_profile('p1')];
      final repo = _ScriptedAuthRepository(
          session, profiles, prefs, buildClient(), interceptor)
        ..refreshTokenError = const GrpcError.unavailable('server unreachable');
      final bloc = AuthBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const AppStartedEvent(splashFloor: false));
      final state = await bloc.stream.firstWhere(
          (s) => s is ProfileSelectionRequired || s is AuthenticatedState);
      await Future<void>.delayed(Duration.zero);

      // Still on the state _onAppStarted reached — no bounce to pairing.
      expect(state, isNot(isA<DevicePairingRequired>()));
      expect(bloc.state, isNot(isA<DevicePairingRequired>()));
    });
  });
}
