import 'web_local_ip_io.dart'
    if (dart.library.js_interop) 'web_local_ip_web.dart' as impl;

/// TV web only: this device's LAN IPv4 addresses, as far as the page can
/// learn them (`pileusLocalIps` in web/index.html — webOS Luna
/// connection manager, Tizen webapis, then WebRTC host candidates).
/// Empty when none of those answer, or on native (use NetworkInterface).
Future<List<String>> webLocalIpv4() => impl.webLocalIpv4();
