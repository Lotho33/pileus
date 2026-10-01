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
// Android TV / Fire TV, with no other way to auto-detect the server, still
// find it on first launch. Both empty in a public build.
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
// "prefer the saved host" fix never got a chance to fire — this
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
    // Empty (not 'mycelium.local', dropped along with the
    // server's mDNS responder — see server_discovery_screen.dart's doc)
    // deliberately falls through to grpc_channel_web.dart's own
    // "host.isEmpty → same-origin" branch, which is the only sane guess
    // left when even Uri.base.host is somehow empty.
    return Uri.base.host;
  } catch (_) {
    return '';
  }
}

/// Resolves the best reachable gRPC host for Mycelium.
///
/// Strategy (all in parallel, first reachable answer wins):
/// 1. UDP broadcast discovery on :51900 — finds the server by its live
///    reply, so it keeps working after the server's LAN IP changes. Probed
///    on the `grpc_port` the reply itself advertises (falling back to
///    [port] if the reply omits it — an older server).
/// 2. TCP probe of the usual candidates: saved host, env override,
///    loopback, Android emulator host, VPN host — each on [port], except
///    the saved host, which is probed on its own previously-learned gRPC
///    port when one is known (see [DeviceSession.grpcPort]).
/// 3. If every candidate fails, wait out the UDP window, then fall back to
///    the saved host (or loopback).
/// 4. Cache the winning host (and its gRPC port, when learned via the UDP
///    reply or already known for the saved host) in the active
///    DeviceSession for next launch.
///
/// `mycelium.local` used to be a candidate here — dropped
/// alongside the server's own mDNS responder for it (see
/// server_discovery_screen.dart's doc): with no responder left to answer,
/// it could never resolve, so keeping it only wasted a probe slot.
Future<String> resolveGrpcHost({int port = ServerPorts.grpc}) async {
  if (kIsWeb) return _webHost();

  // Remote mode (see server_address.dart): none of the probing
  // below applies — there's no LAN UDP broadcast to race and no reason to
  // suspect the saved host moved (unlike a LAN IP from DHCP, a domain name
  // or public IP isn't expected to change under the device). Skip straight
  // to it; injection.dart's channel creation is what actually validates
  // reachability, with a proper error surfaced from there if it's wrong.
  try {
    final session = DeviceSession.readFrom(getIt<SharedPreferences>());
    if (session?.remote == true &&
        session?.grpcHost != null &&
        session!.grpcHost!.isNotEmpty) {
      return session.grpcHost!;
    }
  } catch (_) {}

  const loopback = '127.0.0.1';
  const androidEmulatorHost = '10.0.2.2';

  String? savedHost;
  String? vpnHost;
  int? savedPort;
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
      savedPort = session.grpcPort;
    }
  } catch (_) {}

  // Deduplicated — any pair of these can coincide in practice, each
  // duplicate wasting one of the parallel probe slots.
  final candidates = <String>{
    if (savedHost != null) savedHost,
    if (_envHost != null && _envHost!.isNotEmpty) _envHost!,
    loopback,
    if (isAndroidPlatform) androidEmulatorHost,
    if (vpnHost != null) vpnHost,
  }.toList();
  const timeout = Duration(seconds: 2);
  final tcpFallback = savedHost ?? loopback;

  final completer = Completer<String>();
  // Set only when the winning candidate's real gRPC port became known
  // during this resolve (the UDP reply carried one, or the saved host won
  // on its own previously-learned port) — persisted alongside the host
  // below. Left null (not reset to the default) when nothing new was
  // learned, so a stale-but-correct persisted port isn't clobbered.
  int? discoveredGrpcPort;
  void win(String h) {
    if (!completer.isCompleted) completer.complete(h);
  }

  // UDP broadcast discovery races the TCP candidate probe below. It wins if
  // its answer is TCP-reachable — the only mechanism that survives a server
  // IP change with no working mDNS.
  discoverViaBroadcast().then((result) async {
    if (result == null || completer.isCompleted) return;
    final probePort = result.grpcPort ?? port;
    if (await canReach(result.host, probePort, timeout)) {
      discoveredGrpcPort = result.grpcPort;
      win(result.host);
    }
  });

  var pending = candidates.length;
  for (final host in candidates) {
    final isSaved = host == savedHost;
    final probePort = (isSaved && savedPort != null && savedPort > 0)
        ? savedPort
        : port;
    canReach(host, probePort, timeout).then((ok) {
      if (ok) {
        if (isSaved) discoveredGrpcPort = savedPort;
        win(host);
      }
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

  // Persist winning host (+ its gRPC port, when this resolve learned one)
  // so next launch skips the probe.
  try {
    final prefs = getIt<SharedPreferences>();
    final session = DeviceSession.readFrom(prefs);
    if (session != null) {
      var changed = false;
      if (session.grpcHost != resolved) {
        session.grpcHost = resolved;
        changed = true;
      }
      if (discoveredGrpcPort != null && session.grpcPort != discoveredGrpcPort) {
        session.grpcPort = discoveredGrpcPort;
        changed = true;
      }
      if (changed) await DeviceSession.writeTo(prefs, session);
    }
  } catch (_) {}

  return resolved;
}

/// HTTP base URL for Mycelium's REST / asset endpoints (`/plugin-icon/…`,
/// `/pileus/info`, …), derived from the already-resolved gRPC host. Returns
/// `null` when the host isn't known yet — callers fall back to a local
/// asset.
///
/// Remote mode (see server_address.dart): `https://<host>`
/// (plus the explicit remote port, if any) — the HTTP API isn't on the
/// LAN-only fixed :8000 for a publicly published mycelium.
const _myceliumHttpPort = ServerPorts.http;

String? myceliumHttpBase() {
  try {
    if (kIsWeb) {
      final u = Uri.base;
      // Same bug/fix as _webOrigin in grpc_channel_web.dart: an explicit
      // override host (WebDiscoveryScreen, a packaged Tizen/webOS app with
      // no "served by mycelium" origin at all — see docs/TIZEN_WEBOS.md —
      // or a local dev server whose own origin isn't mycelium) must
      // actually be used here too, or every /plugin-icon//pileus/info//img
      // request keeps silently hitting the page's own origin regardless of
      // what was saved. Remote mode additionally
      // needs https + its own port, not the LAN-assumed :8000.
      final session = DeviceSession.readFrom(getIt<SharedPreferences>());
      final saved = session?.grpcHost;
      if (saved != null && saved.isNotEmpty && saved != u.host) {
        if (session?.remote == true) {
          final port = session!.remotePort ?? ServerPorts.remoteHttps;
          final suffix = port == ServerPorts.remoteHttps ? '' : ':$port';
          return 'https://$saved$suffix';
        }
        return 'http://$saved:$_myceliumHttpPort';
      }
      final port = u.hasPort ? ':${u.port}' : '';
      return '${u.scheme}://${u.host}$port';
    }
    final session = DeviceSession.readFrom(getIt<SharedPreferences>());
    final host = session?.grpcHost;
    if (host == null || host.isEmpty) return null;
    if (session?.remote == true) {
      final port = session!.remotePort ?? ServerPorts.remoteHttps;
      final suffix = port == ServerPorts.remoteHttps ? '' : ':$port';
      return 'https://$host$suffix';
    }
    return 'http://$host:$_myceliumHttpPort';
  } catch (_) {
    return null;
  }
}
