import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import '../config/server_config.dart';

class AuthInterceptor extends ClientInterceptor {
  String? _jwt;
  String? _profileId;
  String? _grpcHost;
  final int _httpPort = ServerPorts.http;

  // Remote server mode — see server_address.dart's own doc.
  // Set alongside _grpcHost by setGrpcHost(); drives _httpHostHeader/
  // _httpSchemeHeader below into sending the full https://<host>[:port]
  // URL mycelium needs to build proxy/download URLs for a publicly
  // reachable instance, instead of the LAN-only bare "host:8000".
  bool _remote = false;
  int? _remotePort;

  // Profile PIN: a one-off unlock session for a PIN-protected
  // profile (UnlockProfile with remember_device=false — see
  // AuthRepository.unlockProfile). Deliberately in-memory ONLY: never
  // written to secure storage, SharedPreferences, IndexedDB or
  // localStorage, so it's gone the moment the app closes (or, on web, the
  // page reloads) and the PIN is asked again next time, exactly like the
  // server's own "just this time" semantics for it. Always cleared on a
  // profile change (see setCredentials) so it can never leak onto a
  // different profile's calls.
  String? _profileSessionToken;

  void setGrpcHost(String host, {bool remote = false, int? remotePort}) {
    _grpcHost = host;
    _remote = remote;
    _remotePort = remotePort;
  }

  void setCredentials(String jwt, String profileId) {
    // debugPrint (unlike assert) isn't stripped in release — this used to
    // log JWT metadata + a full stack trace on every login/profile-switch
    // in production builds too, visible via adb logcat.
    if (kDebugMode) {
      debugPrint(
          '[interceptor] setCredentials jwt.length=${jwt.length} segments=${jwt.split('.').length}\n${StackTrace.current}');
    }
    _jwt = jwt.isNotEmpty ? jwt : _jwt; // never overwrite with empty
    // A real profile change (not the empty-string "keep current" callers use
    // pre-login, nor an idempotent re-set of the same id) drops any PIN
    // session token: it was scoped to whichever profile was active when it
    // was issued and must never be sent for a different one.
    if (profileId.isNotEmpty && profileId != _profileId) {
      _profileSessionToken = null;
    }
    _profileId = profileId.isNotEmpty ? profileId : _profileId;
  }

  /// Stores the one-off session token from a successful UnlockProfile
  /// (remember_device=false) for the *current* profile — see the field's
  /// doc for why this never touches disk.
  void setProfileSessionToken(String token) {
    _profileSessionToken = token.isNotEmpty ? token : null;
  }

  /// Drops the current PIN session, if any — called on LockProfile (exit
  /// profile), a profile-locked bounce back to the picker, or logout.
  void clearProfileSessionToken() {
    _profileSessionToken = null;
  }

  void clear() {
    _jwt = null;
    _profileId = null;
    _profileSessionToken = null;
  }

  bool get hasCredentials => _jwt != null;
  String? get jwt => _jwt;
  String? get profileId => _profileId;
  String? get httpHost => _grpcHost;
  int get httpPort => _httpPort;

  /// The value sent as `x-http-host` — the host mycelium uses to build its
  /// image-proxy URLs.
  ///
  /// Native, remote mode (see server_address.dart): the full
  /// `https://<host>[:port]` URL, not just a bare host:port — mycelium
  /// needs the scheme here too to build a publicly-reachable proxy/download
  /// URL for a remote deployment (there's no LAN-only :8000 to imply http).
  /// Native, LAN mode: the resolved gRPC host + the fixed HTTP port (8000),
  /// unchanged from before remote mode existed.
  /// Web, same-origin (the page is served *by* mycelium — the common case
  /// for a browser visiting mycelium's own /app/): the origin the app
  /// loaded from — send that host:port, not the native :8000 default
  /// (which pointed every poster/fanart URL at the wrong port on any web
  /// deploy not served on 8000).
  /// Web, explicit override (WebDiscoveryScreen's manual host, or — always,
  /// since there's no "served by mycelium" origin to default to — a
  /// packaged Tizen/webOS app, see docs/TIZEN_WEBOS.md): same shape as
  /// native, LAN or remote — _grpcHost/_remote/_remotePort are set by
  /// setGrpcHost() exactly the same way on every platform.
  String? get _httpHostHeader {
    if (kIsWeb) {
      final b = Uri.base;
      if (_grpcHost != null && _grpcHost!.isNotEmpty && _grpcHost != b.host) {
        return _remoteOrLanHost;
      }
      return b.hasPort ? '${b.host}:${b.port}' : b.host;
    }
    if (_grpcHost == null) return null;
    return _remoteOrLanHost;
  }

  // Shared by both the native branch and web's explicit-override branch —
  // see _httpHostHeader's own doc for when each applies.
  String get _remoteOrLanHost {
    if (_remote) {
      final port = _remotePort ?? ServerPorts.remoteHttps;
      final suffix = port == ServerPorts.remoteHttps ? '' : ':$port';
      return 'https://$_grpcHost$suffix';
    }
    return '$_grpcHost:$_httpPort';
  }

  /// The value sent as `x-http-scheme`, paired with `x-http-host` so mycelium
  /// can build absolute image-proxy URLs when it sits behind no reverse
  /// proxy (i.e. no `X-Forwarded-Proto` to read).
  ///
  /// Native, remote mode: 'https' — see _httpHostHeader's doc.
  /// Native, LAN mode: the HTTP API on :8000 is plain HTTP by design (the
  /// TLS fingerprint TOFU covers the gRPC channel only). If mycelium ever
  /// serves its REST/asset API over TLS this must follow that.
  /// Web, same-origin: the actual scheme of the origin the app loaded from.
  /// Web, explicit override: 'https'/'http' matching _remote, same as
  /// native — Uri.base.scheme is meaningless there (a packaged app's own
  /// bundle origin, not mycelium's).
  String get _httpSchemeHeader {
    if (kIsWeb) {
      final b = Uri.base;
      if (_grpcHost != null && _grpcHost!.isNotEmpty && _grpcHost != b.host) {
        return _remote ? 'https' : 'http';
      }
      return b.scheme;
    }
    return _remote ? 'https' : 'http';
  }

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    return invoker(method, request, _inject(options));
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    ClientStreamingInvoker<Q, R> invoker,
  ) {
    return invoker(method, requests, _inject(options));
  }

  // `x-http-host` / `x-http-scheme` tell mycelium which absolute base to
  // build image-proxy URLs against when nothing upstream sets
  // `X-Forwarded-*`; not auth, and the pre-login calls (discovery, pairing)
  // need them too — so they're sent whenever a host is known, independent
  // of the JWT. Only `authorization` / `x-profile-id` / `x-profile-session`
  // gate on a session. Split out from [_inject] (rather than building the
  // map inline there) purely so a test can inspect exactly what a call
  // would carry right now without constructing grpc's own heavyweight
  // ClientMethod/ClientCall machinery — see [debugMetadataForTests].
  Map<String, String> _metadata() {
    final httpHost = _httpHostHeader;
    return <String, String>{
      if (httpHost != null) 'x-http-host': httpHost,
      if (httpHost != null) 'x-http-scheme': _httpSchemeHeader,
      if (_jwt != null) 'authorization': 'Bearer $_jwt',
      if (_jwt != null && _profileId != null) 'x-profile-id': _profileId!,
      // Always for the CURRENT profile by construction — setCredentials
      // clears this the moment the profile actually changes (see its doc).
      // Sent on every call, streams included (interceptStreaming also routes
      // through _inject), which is what lets a PIN-protected profile's
      // ResolveStream go through on a one-off unlock.
      if (_jwt != null &&
          _profileSessionToken != null &&
          _profileSessionToken!.isNotEmpty)
        'x-profile-session': _profileSessionToken!,
    };
  }

  /// The metadata headers the next call would carry, exactly as [_inject]
  /// computes them — for tests only. Production code always goes through
  /// [interceptUnary]/[interceptStreaming].
  @visibleForTesting
  Map<String, String> get debugMetadataForTests => _metadata();

  CallOptions _inject(CallOptions options) {
    final md = _metadata();
    if (md.isEmpty) return options;
    return options.mergedWith(CallOptions(metadata: md));
  }
}
