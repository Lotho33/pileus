import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/server_config.dart';
import '../db/models/device_session.dart';
import '../di/injection.dart';
// dart:io lives behind this shim so `flutter build web` links only the stub.
// `dart.library.js_interop` (not legacy `dart.library.html`) so the stub is
// also picked under `flutter build web --wasm`.
import 'host_resolver_io.dart'
    if (dart.library.js_interop) 'host_resolver_stub.dart';

// Runtime env var (dev convenience, native only) OR a compile-time default
// (`--dart-define=PILEUS_MYCELIUM_HOST=…`, optional) — the latter lets an
// Android TV / Fire TV, where `mycelium.local` won't resolve, still find the
// server on first launch. Both empty in a public build.
String? get _envHost {
  final runtime = runtimeEnvHost();
  if (runtime != null && runtime.isNotEmpty) return runtime;
  const baked = String.fromEnvironment('PILEUS_MYCELIUM_HOST');
  return baked.isNotEmpty ? baked : null;
}

// The browser can't open a raw TCP socket at all — a page loaded in the
// browser is already talking to a specific origin, and that origin's own
// hostname normally *is* the resolved host (the app is served by mycelium).
//
// A saved override (WebDiscoveryScreen's manual host — "for the case where
// the app is hosted somewhere else", which in practice also covers a local
// `flutter run -d web-server` dev session, where the page's own origin is
// the Flutter dev server, not mycelium) takes precedence when present. Every
// successful WebDiscoveryScreen connection — including the routine
// same-origin auto-confirm — saves `host` via saveHostInfo(), so checking it
// first here doesn't change behaviour for the normal "served by mycelium"
// deployment (the saved value and Uri.base.host already agree there); it
// only matters when they'd otherwise disagree.
//
// Without this, a full page *reload* forgot the override every time:
// configureDependencies() calls resolveGrpcHost() from scratch on every
// fresh load, so grpc_channel_web.dart/myceliumHttpBase()'s own
// "prefer the saved host" fix (2026-09-14) never got a chance to fire — this
// is what actually feeds `host` into both of those the first place, and it
// was still handing them Uri.base.host unconditionally. Symptom: dev-server
// testing worked until a browser refresh, at which point gRPC calls started
// hitting the Flutter dev server's own shelf-based static server (its 404
// response is how this was actually diagnosed — "x-powered-by: Dart with
// package:shelf" is the dev server, not mycelium, which is Go).
String _webHost() {
  try {
    final saved = DeviceSession.readFrom(getIt<SharedPreferences>())?.grpcHost;
    if (saved != null && saved.isNotEmpty) return saved;
    final host = Uri.base.host;
    return host.isNotEmpty ? host : 'mycelium.local';
  } catch (_) {
    return 'mycelium.local';
  }
}

/// Resolves the best reachable gRPC host for Mycelium.
///
/// Strategy (all in parallel, first reachable answer wins):
/// 1. UDP broadcast discovery on :51900 — finds the server by its live reply,
///    so it keeps working after the server's LAN IP changes.
/// 2. TCP probe of the usual candidates: saved host, env override,
///    `mycelium.local`, loopback, Android emulator host, VPN host.
/// 3. If every candidate fails, wait out the UDP window, then fall back to the
///    saved host (or loopback).
/// 4. Cache the winner in the active DeviceSession for next launch.
Future<String> resolveGrpcHost({int port = ServerPorts.grpc}) async {
  if (kIsWeb) return _webHost();

  const lanHost = 'mycelium.local';
  const loopback = '127.0.0.1';
  const androidEmulatorHost = '10.0.2.2';

  String? savedHost;
  String? vpnHost;
  try {
    final prefs = getIt<SharedPreferences>();
    final session = DeviceSession.readFrom(prefs);
    if (session != null) {
      if (session.grpcHost != null && session.grpcHost!.isNotEmpty) {
        savedHost = session.grpcHost;
      }
      if (session.vpnHost != null && session.vpnHost!.isNotEmpty) {
        vpnHost = session.vpnHost;
      }
    }
  } catch (_) {}

  // Deduplicated — any pair of these can coincide in practice, each
  // duplicate wasting one of the parallel probe slots.
  final candidates = <String>{
    if (savedHost != null) savedHost,
    if (_envHost != null && _envHost!.isNotEmpty) _envHost!,
    lanHost,
    loopback,
    if (isAndroidPlatform) androidEmulatorHost,
    if (vpnHost != null) vpnHost,
  }.toList();
  const timeout = Duration(seconds: 2);
  final tcpFallback = savedHost ?? loopback;

  final completer = Completer<String>();
  void win(String h) {
    if (!completer.isCompleted) completer.complete(h);
  }

  // UDP broadcast discovery races the TCP candidate probe below. It wins if
  // its answer is TCP-reachable — the only mechanism that survives a server
  // IP change with no working mDNS.
  discoverViaBroadcast().then((h) async {
    if (h != null &&
        !completer.isCompleted &&
        await canReach(h, port, timeout)) {
      win(h);
    }
  });

  var pending = candidates.length;
  for (final host in candidates) {
    canReach(host, port, timeout).then((ok) {
      if (ok) win(host);
      if (--pending == 0 && !completer.isCompleted) {
        // Every candidate failed — the saved IP is probably stale. Give the
        // UDP discovery the rest of its window before falling back.
        Future.delayed(const Duration(milliseconds: 1100)).then((_) {
          win(tcpFallback);
        });
      }
    });
  }

  final resolved = await completer.future;

  // Persist winning host so next launch skips the probe.
  try {
    final prefs = getIt<SharedPreferences>();
    final session = DeviceSession.readFrom(prefs);
    if (session != null && session.grpcHost != resolved) {
      session.grpcHost = resolved;
      await DeviceSession.writeTo(prefs, session);
    }
  } catch (_) {}

  return resolved;
}

/// HTTP base URL for Mycelium's REST / asset endpoints (`/plugin-icon/…`,
/// `/pileus/info`, …), derived from the already-resolved gRPC host. The HTTP
/// API always listens on 8000. Returns `null` when the host isn't known yet —
/// callers fall back to a local asset.
const _myceliumHttpPort = ServerPorts.http;

String? myceliumHttpBase() {
  try {
    if (kIsWeb) {
      final u = Uri.base;
      // Same bug/fix as _webOrigin in grpc_channel_web.dart: an explicit
      // override host (WebDiscoveryScreen, or a local dev server whose own
      // origin isn't mycelium) must actually be used here too, or every
      // /plugin-icon//pileus/info//img request keeps silently hitting the
      // page's own origin regardless of what was saved (2026-09-14).
      final saved =
          DeviceSession.readFrom(getIt<SharedPreferences>())?.grpcHost;
      if (saved != null && saved.isNotEmpty && saved != u.host) {
        return 'http://$saved:$_myceliumHttpPort';
      }
      final port = u.hasPort ? ':${u.port}' : '';
      return '${u.scheme}://${u.host}$port';
    }
    final host = DeviceSession.readFrom(getIt<SharedPreferences>())?.grpcHost;
    if (host == null || host.isEmpty) return null;
    return 'http://$host:$_myceliumHttpPort';
  } catch (_) {
    return null;
  }
}
