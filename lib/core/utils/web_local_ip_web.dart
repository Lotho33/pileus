import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Future<List<String>> webLocalIpv4() async {
  if (!globalContext.has('pileusLocalIps')) return const [];
  try {
    final promise = globalContext
        .callMethod<JSPromise<JSArray<JSString>>>('pileusLocalIps'.toJS);
    final ips = await promise.toDart;
    return [for (final ip in ips.toDart) ip.toDart];
  } catch (_) {
    return const [];
  }
}
