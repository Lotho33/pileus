/// Automatic move to the next node of a live event when the one playing
/// fails for good (resolve failed, or a playback error that outlived its
/// grace window) — instead of an error page while other nodes are up. The
/// manual "Sorgente" pick stays; this only decides what happens on failure.
///
/// Each node is tried once per bad stretch: a node that failed isn't tried
/// again until the stream has played fine for [healthyAfter] (then every
/// node is fair game again — a node down five minutes ago may be back).
/// When every node has failed, [next] returns null and the screen shows its
/// error as before.
class LiveFailover {
  LiveFailover(this.sources,
      {required String current, DateTime Function()? clock})
      : _current = sources.indexOf(current),
        _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  /// The event's node stream ids, in the plugin's order.
  final List<String> sources;
  static const healthyAfter = Duration(seconds: 60);

  int _current;
  final Set<int> _failed = {};
  DateTime? _healthySince;

  bool get enabled => sources.length > 1;

  /// The user (or the screen) switched to [streamId] — follow it.
  void switchedTo(String streamId) {
    final i = sources.indexOf(streamId);
    if (i >= 0) _current = i;
    _healthySince = null;
  }

  /// A position tick / frame: the current node is playing. Call often; it
  /// only clears the failed set once playback has held for [healthyAfter].
  void playing() {
    final since = _healthySince ??= _now();
    if (_failed.isNotEmpty && _now().difference(since) >= healthyAfter) {
      _failed.clear();
    }
  }

  /// The current node failed. The next node not yet failed in this bad
  /// stretch (in the plugin's order, wrapping around), already recorded as
  /// current — or null when there's none left (or a single node).
  String? next() {
    _healthySince = null;
    if (!enabled) return null;
    if (_current >= 0) _failed.add(_current);
    for (var k = 1; k <= sources.length; k++) {
      final i = ((_current < 0 ? -1 : _current) + k) % sources.length;
      if (!_failed.contains(i)) {
        _current = i;
        return sources[i];
      }
    }
    return null;
  }

  /// Label for [streamId] from [labels] (parallel to [sources]), or
  /// "Sorgente N".
  String labelOf(String streamId, List<String> labels) {
    final i = sources.indexOf(streamId);
    if (i >= 0 && i < labels.length && labels[i].isNotEmpty) return labels[i];
    return 'Sorgente ${i + 1}';
  }
}
