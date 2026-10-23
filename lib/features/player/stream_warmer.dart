import 'dart:async';

/// Asks the server to prepare a stream before the user presses Play
/// (WarmStream, see proto/media.proto): the server-side preparation runs
/// while they read the plot, and the Play then finds it ready, or picks up
/// the preparation still in progress instead of starting over.
///
/// Only from screens where a Play is the likely next step — a title's
/// details, an episode popup, a Continue Watching card the D-pad rests on.
/// Never from the home rows, search or carousel scrolling: each request
/// costs the server real work, so it's spent only where it's likely to pay
/// off.
///
/// Client-side rules, on top of the server's own caps:
/// - [delay] of dwell first: [schedule] does nothing until it has passed,
///   and [WarmTicket.cancel] (leaving the screen, focus moving on) before
///   then means no request at all;
/// - one warm per plugin + stream id per session;
/// - nothing for a plugin the server said it won't warm
///   (MediaRepository.canWarm).
class StreamWarmer {
  StreamWarmer({
    required this.warm,
    required this.canWarm,
    this.delay = const Duration(milliseconds: 1500),
  });

  final void Function(String pluginId, String streamId) warm;
  final bool Function(String pluginId) canWarm;
  final Duration delay;

  final Set<String> _warmed = {};

  /// After [delay], works out the stream id with [target] — which must give
  /// exactly the id the Play would send to ResolveStream (see
  /// source_continuity.dart's playStreamIdFor), or null for "nothing to
  /// warm" — and warms it.
  /// [target] runs only once the delay has passed, so its own lookups
  /// (cached GetStreams, Continue Watching) are skipped when the user just
  /// passes through.
  WarmTicket schedule(String pluginId, Future<String?> Function() target) {
    final ticket = WarmTicket._();
    if (pluginId.isEmpty || !canWarm(pluginId)) return ticket;
    ticket._timer = Timer(delay, () async {
      String? streamId;
      try {
        streamId = await target();
      } catch (_) {
        return; // best-effort: the Play just resolves cold
      }
      if (ticket._cancelled || streamId == null || streamId.isEmpty) return;
      if (!canWarm(pluginId)) return;
      if (!_warmed.add('$pluginId\u0000$streamId')) return;
      warm(pluginId, streamId);
    });
    return ticket;
  }
}

class WarmTicket {
  WarmTicket._();

  Timer? _timer;
  bool _cancelled = false;

  /// The user left before the warm went out — it never will.
  void cancel() {
    _cancelled = true;
    _timer?.cancel();
  }
}
