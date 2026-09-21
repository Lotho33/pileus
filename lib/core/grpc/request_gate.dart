import 'dart:async';

/// Caps how many tasks run at once; the rest wait FIFO.
///
/// Exists for the web build only. A browser allows ~6 concurrent HTTP/1.1
/// connections per origin and mycelium serves the web app over plain HTTP/1.1,
/// so gRPC-Web XHRs and poster fetches (`/img`, TMDB) all share those same 6
/// slots. Home fires one `GetCatalog` per carousel at once (a dozen or more);
/// each one parks on a plugin's Lua pool (2 states) on the server, holding its
/// connection for seconds, and every poster `fetch` queues behind them —
/// covers show the placeholder until the catalog burst drains. Gating the
/// content RPCs to a few at a time leaves connections free for images without
/// slowing the server, which was only ever running 2 at a time per plugin.
///
/// [run]'s `group` (the plugin id) handles fast plugin switching: the calls
/// of the previous plugin are still queued — their screens are gone but the
/// RPCs can't be recalled — and would otherwise run before the new plugin's.
/// Waiters of the most recently seen group go first; everything else stays
/// FIFO, so a single home load still fills top-to-bottom.
class RequestGate {
  RequestGate(this.limit) : assert(limit > 0);

  final int limit;
  int _active = 0;
  Object? _latestGroup;
  final List<({Completer<void> turn, Object? group})> _waiters = [];

  Future<T> run<T>(Future<T> Function() task, {Object? group}) async {
    _latestGroup = group ?? _latestGroup;
    if (_active >= limit) {
      final turn = Completer<void>();
      _waiters.add((turn: turn, group: group));
      // The finishing task hands its slot straight to us (no _active change).
      await turn.future;
    } else {
      _active++;
    }
    try {
      return await task();
    } finally {
      if (_waiters.isNotEmpty) {
        final i = _waiters.indexWhere((w) => w.group == _latestGroup);
        _waiters.removeAt(i < 0 ? 0 : i).turn.complete();
      } else {
        _active--;
      }
    }
  }
}
