import '../config/server_config.dart';

/// What a person typed into a "manual server address" field resolves to —
/// shared by every discovery screen (TV/mobile/desktop; web's manual
/// override is a gRPC-Web reverse-proxy URL, a different kind of remote
/// setup that never goes through this) and by [DeviceSession]'s
/// persistence of the choice.
///
/// Two modes (before this, only LAN mode existed):
///
/// - **LAN** (the default, unchanged from before): a bare private-range IP
///   with no scheme, found by UDP/mDNS-less discovery or typed by hand,
///   connected to on the server's fixed `:8000` (HTTP)/`:50051` (gRPC, or
///   whatever `/pileus/info` itself reports — see host_resolver.dart) with
///   the server's self-signed cert pinned by SHA-256 fingerprint
///   (trust-on-first-use).
/// - **Remote**: anything else — an explicit `http(s)://` URL, or a bare
///   domain name, or even a public (non-private-range) bare IP — connected
///   to over HTTPS on a single port (443, or an explicit `:port` in the
///   input) with standard system CA certificate validation, no pinning.
///   For a mycelium published on the public internet (e.g. a demo instance
///   store reviewers connect to), which has a real CA-issued certificate
///   and was never going to answer a LAN UDP broadcast or a raw-IP TCP
///   probe on :50051 in the first place.
class ParsedServerAddress {
  final bool remote;
  final String host;

  /// Only meaningful when [remote] — 'https' unless the input explicitly
  /// said `http://`. LAN mode is never https (the gRPC channel's own TLS,
  /// pinned by fingerprint, is a separate thing from this scheme — see
  /// grpc_channel_io.dart).
  final String scheme;

  /// Explicit `:port` parsed out of the input, if any. LAN mode ignores
  /// this entirely (the fixed :8000/:50051 apply regardless, exactly as
  /// before this class existed — see [effectiveHost]'s doc for why this
  /// matters even there). Remote mode falls back to 443 when absent — see
  /// [remoteHttpPort].
  final int? port;

  const ParsedServerAddress({
    required this.remote,
    required this.host,
    required this.scheme,
    this.port,
  });

  /// The port remote mode's REST API and gRPC channel both connect to —
  /// the explicit `:port` from the input, or 443. Meaningless for LAN
  /// (which has its own two separate fixed ports, unaffected by this).
  int get remoteHttpPort => port ?? ServerPorts.remoteHttps;

  /// `scheme://host[:port]`, the port suffix omitted when it's the
  /// scheme's own default (443 for https, 80 for http) — for display and
  /// for building the /pileus/info probe URL. Meaningful only when
  /// [remote].
  String get remoteBaseUrl {
    final defaultPort = scheme == 'https' ? 443 : 80;
    final suffix = port != null && port != defaultPort ? ':$port' : '';
    return '$scheme://$host$suffix';
  }
}

// RFC1918 + loopback + link-local — the ranges LAN discovery's manual
// field has always implicitly assumed a typed bare IP falls in.
// Deliberately NOT extended to carrier-grade NAT (100.64/10, some VPN
// meshes use it) or anything else: a bare IP outside these ranges is
// public, and a public mycelium is exactly the "remote" case this exists
// to detect.
bool _isPrivateOrLocalIPv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final nums = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255 || (p.length > 1 && p.startsWith('0'))) {
      return false;
    }
    nums.add(n);
  }
  final a = nums[0], b = nums[1];
  if (a == 10) return true; // 10.0.0.0/8
  if (a == 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12
  if (a == 192 && b == 168) return true; // 192.168.0.0/16
  if (a == 127) return true; // loopback
  if (a == 169 && b == 254) return true; // link-local
  return false;
}

bool _looksLikeIPv4(String s) {
  final parts = s.split('.');
  if (parts.length != 4) return false;
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return false;
  }
  return true;
}

// Best-effort only — the test matrix this exists for (server_address_test.
// dart) never exercises a bare IPv6 LAN address, and nobody in practice
// types one into this field (see the ambiguity note on the bracket
// handling in parseServerAddressInput). Good enough to keep a real IPv6
// loopback/link-local/ULA address out of "remote" if one ever shows up.
bool _isPrivateOrLocalIPv6(String ip) {
  final lower = ip.toLowerCase();
  if (lower == '::1') return true; // loopback
  if (lower.startsWith('fe80:')) return true; // link-local
  if (lower.startsWith('fc') || lower.startsWith('fd')) return true; // ULA
  return false;
}

final _schemeRe = RegExp(r'^(https?)://', caseSensitive: false);

/// Parses a manual "server address" field into LAN vs. remote — see
/// [ParsedServerAddress]'s own doc for the two modes and what decides
/// between them.
ParsedServerAddress parseServerAddressInput(String rawInput) {
  final input = rawInput.trim();

  // No explicit scheme defaults to https, not http — a bare domain typed
  // into this field (no IP, no scheme) is always treated as a public
  // mycelium reachable over TLS; only an explicit "http://" opts out.
  var scheme = 'https';
  var rest = input;
  final schemeMatch = _schemeRe.firstMatch(input);
  final hasExplicitScheme = schemeMatch != null;
  if (hasExplicitScheme) {
    scheme = schemeMatch.group(1)!.toLowerCase();
    rest = input.substring(schemeMatch.end);
  }

  // Strip a trailing path/query/fragment, if any ("https://host/foo" →
  // "host").
  final cut = RegExp(r'[/?#]').firstMatch(rest);
  if (cut != null) rest = rest.substring(0, cut.start);

  // host[:port] — a bracketed IPv6 literal ("[::1]:443") keeps its colons
  // out of the port split. A bare (unbracketed) IPv6 literal is inherently
  // ambiguous with "host:port" syntax and isn't something this field's
  // hint text (an IPv4 example) or its tests ever ask for — falls through
  // to the plain branch below, which just keeps the whole thing as `host`
  // (its multiple colons mean the "single trailing :digits" port check
  // never matches).
  String host;
  int? port;
  if (rest.startsWith('[')) {
    final end = rest.indexOf(']');
    if (end > 0) {
      host = rest.substring(1, end);
      final tail = rest.substring(end + 1);
      if (tail.startsWith(':')) port = int.tryParse(tail.substring(1));
    } else {
      host = rest;
    }
  } else {
    final colon = rest.lastIndexOf(':');
    final maybePort = colon >= 0 ? int.tryParse(rest.substring(colon + 1)) : null;
    if (colon > 0 && maybePort != null) {
      host = rest.substring(0, colon);
      port = maybePort;
    } else {
      host = rest;
    }
  }

  final isIPv4 = _looksLikeIPv4(host);
  final isIPv6 = !isIPv4 && host.contains(':');
  final isPrivateIp = isIPv4
      ? _isPrivateOrLocalIPv4(host)
      : isIPv6
          ? _isPrivateOrLocalIPv6(host)
          : false;
  final isLan = !hasExplicitScheme && (isIPv4 || isIPv6) && isPrivateIp;

  return ParsedServerAddress(
    remote: !isLan,
    host: host,
    scheme: scheme,
    port: port,
  );
}
