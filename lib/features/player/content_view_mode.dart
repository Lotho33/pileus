import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../media/data/continue_watching_item.dart';
import 'engine/video_view_mode.dart';

/// The player "Formato" remembered per content, for as long as that content
/// sits in Continue Watching — set it once on a badly flagged 4:3 series and
/// every later episode opens in 4:3, while everything else keeps opening in
/// [VideoViewMode.fit].
///
/// Local to this device (the right format depends on this screen's shape)
/// and per profile (each profile has its own Continue Watching). A content
/// is identified the way Continue Watching identifies it: the series id
/// (`parentId`) for an episode, otherwise the media/stream ids it was played
/// under — Continue Watching stores the *stream* id for a movie (it carries
/// the language), which is why an entry keeps every id it has been seen
/// with.
///
/// A player screen calls [open] when it starts a title, [track] whenever it
/// learns more of its identity (the stream id once resolved, the series id
/// once looked up — each Continue Watching save does it), and [close] on
/// dispose. Entries whose content left Continue Watching (finished, or
/// removed) are dropped by [prune], run on every full Continue Watching
/// fetch (see MediaRepository.getContinueWatching).
class ContentViewModeMemory {
  SharedPreferences? _prefs;
  String? Function()? _profileId;
  DateTime Function() _now = DateTime.now;

  _Session? _session;
  // True while [_apply] writes [videoViewMode] itself — that change is a
  // restore, not the user's choice, and must not be saved.
  bool _applying = false;
  bool _listening = false;

  static const _keyPrefix = 'player.viewModes@';
  static const _legacyDeviceKey = 'settings.videoViewMode';

  /// An entry is kept this long even when Continue Watching doesn't list it
  /// (yet): the row is written when the stream opens, but a fetch already in
  /// flight at that moment wouldn't have it.
  static const pruneGrace = Duration(minutes: 10);

  /// Hard cap for entries Continue Watching can't vouch for — a full page
  /// (more items than a fetch returns) can't prove an entry is gone.
  static const maxAge = Duration(days: 180);
  static const maxEntries = 200;
  static const _maxIds = 40;

  /// Wires storage once per app start. [profileId] is read on every access
  /// (the active profile can change at any time).
  void bind(SharedPreferences prefs, String? Function() profileId,
      {DateTime Function()? now}) {
    _prefs = prefs;
    _profileId = profileId;
    if (now != null) _now = now;
    // The format used to be one device-wide setting.
    prefs.remove(_legacyDeviceKey);
    if (!_listening) {
      _listening = true;
      videoViewMode.addListener(_onModeChanged);
    }
  }

  /// A player screen started [pluginId]'s title: applies the format stored
  /// for it, else keeps the current one when [continuing] is the open
  /// session's token (the same screen moving on in place: a retry, another
  /// source/language, the next episode), else [VideoViewMode.fit]. Returns
  /// the token for [track]/[close].
  Object open({
    required String pluginId,
    String parentId = '',
    required Iterable<String> ids,
    Object? continuing,
  }) {
    final idSet = {...ids.where((i) => i.isNotEmpty)};
    final previous = _session;
    final session = _Session(pluginId, parentId, idSet);
    _session = session;
    final list = _load();
    final hit = _indexOf(list, session);
    if (hit >= 0) {
      final e = list[hit];
      session.merge(e.parentId, e.ids);
      _apply(VideoViewMode.fromName(e.mode));
      _store(list, session, videoViewMode.value);
    } else if (previous != null && identical(previous, continuing)) {
      session.merge(previous.parentId, previous.ids);
      if (videoViewMode.value != VideoViewMode.fit) {
        _store(list, session, videoViewMode.value);
      }
    } else {
      _apply(VideoViewMode.fit);
    }
    return session;
  }

  /// More of the open content's identity is known (stream id, series id).
  /// No-op for a token that isn't the open session's.
  void track(Object token,
      {String parentId = '', Iterable<String> ids = const []}) {
    final s = _session;
    if (!identical(s, token) || s == null) return;
    if (!s.merge(parentId, ids)) return;
    if (videoViewMode.value == VideoViewMode.fit) return;
    _store(_load(), s, videoViewMode.value);
  }

  /// The player screen that got [token] is gone: later format changes are no
  /// longer anyone's, and the next screen starts from [VideoViewMode.fit]
  /// unless its content has its own.
  void close(Object token) {
    if (!identical(_session, token)) return;
    _session = null;
    _apply(VideoViewMode.fit);
  }

  /// Drops the entries whose content is no longer in Continue Watching.
  /// [complete]: [items] is the whole list — when it was cut at the fetch
  /// limit only [maxAge] applies.
  void prune(List<ContinueWatchingItem> items, {required bool complete}) {
    final list = _load();
    if (list.isEmpty) return;
    final now = _now();
    final open = _session;
    final kept = [
      for (final e in list)
        if ((open != null && e.matches(open)) ||
            (now.difference(e.touched) < pruneGrace) ||
            (now.difference(e.touched) < maxAge &&
                (!complete || items.any(e.inContinueWatching))))
          e,
    ];
    if (kept.length != list.length) _save(kept);
  }

  /// Stored mode for this identity, if any — for tests/diagnostics.
  VideoViewMode? storedFor({
    required String pluginId,
    String parentId = '',
    Iterable<String> ids = const [],
  }) {
    final list = _load();
    final i = _indexOf(list, _Session(pluginId, parentId, {...ids}));
    return i < 0 ? null : VideoViewMode.fromName(list[i].mode);
  }

  void _onModeChanged() {
    if (_applying) return;
    final s = _session;
    if (s == null) return;
    _store(_load(), s, videoViewMode.value);
  }

  void _apply(VideoViewMode m) {
    if (videoViewMode.value == m) return;
    _applying = true;
    try {
      videoViewMode.value = m;
    } finally {
      _applying = false;
    }
  }

  /// Replaces every entry of [s]'s content with one for [mode] — or none for
  /// [VideoViewMode.fit], the default.
  void _store(List<_Entry> list, _Session s, VideoViewMode mode) {
    final next = [
      for (final e in list)
        if (!e.matches(s)) e
    ];
    if (mode != VideoViewMode.fit) {
      final ids = s.ids.toList();
      next.add(_Entry(
        pluginId: s.pluginId,
        parentId: s.parentId,
        ids: ids.length > _maxIds ? ids.sublist(ids.length - _maxIds) : ids,
        mode: mode.name,
        touched: _now(),
      ));
    }
    if (next.length > maxEntries) {
      next.sort((a, b) => a.touched.compareTo(b.touched));
      next.removeRange(0, next.length - maxEntries);
    }
    _save(next);
  }

  int _indexOf(List<_Entry> list, _Session s) {
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i].matches(s)) return i;
    }
    return -1;
  }

  String? get _key {
    final pid = _profileId?.call() ?? '';
    return _prefs == null ? null : '$_keyPrefix$pid';
  }

  List<_Entry> _load() {
    final key = _key;
    if (key == null) return [];
    try {
      final raw = _prefs!.getString(key);
      if (raw == null || raw.isEmpty) return [];
      return [
        for (final m in jsonDecode(raw) as List)
          _Entry.fromJson(m as Map<String, dynamic>)
      ];
    } catch (_) {
      return [];
    }
  }

  void _save(List<_Entry> list) {
    final key = _key;
    if (key == null) return;
    if (list.isEmpty) {
      _prefs!.remove(key);
    } else {
      _prefs!.setString(key, jsonEncode([for (final e in list) e.toJson()]));
    }
  }
}

/// The app-wide instance (one player at a time). Bound in injection.dart.
final contentViewModes = ContentViewModeMemory();

class _Session {
  _Session(this.pluginId, this.parentId, this.ids);
  final String pluginId;
  String parentId;
  final Set<String> ids;

  /// Adds what's new; true when anything changed.
  bool merge(String parent, Iterable<String> more) {
    var changed = false;
    if (parentId.isEmpty && parent.isNotEmpty) {
      parentId = parent;
      changed = true;
    }
    for (final id in more) {
      if (id.isNotEmpty && ids.add(id)) changed = true;
    }
    return changed;
  }
}

class _Entry {
  _Entry({
    required this.pluginId,
    required this.parentId,
    required this.ids,
    required this.mode,
    required this.touched,
  });

  final String pluginId;
  final String parentId;
  final List<String> ids;
  final String mode;
  final DateTime touched;

  bool matches(_Session s) =>
      s.pluginId == pluginId &&
      ((parentId.isNotEmpty && parentId == s.parentId) ||
          ids.any(s.ids.contains) ||
          (parentId.isNotEmpty && s.ids.contains(parentId)));

  bool inContinueWatching(ContinueWatchingItem i) =>
      i.providerID == pluginId &&
      ((parentId.isNotEmpty && i.parentID == parentId) ||
          ids.contains(i.playableID) ||
          (i.parentID.isNotEmpty && ids.contains(i.parentID)));

  Map<String, dynamic> toJson() => {
        'p': pluginId,
        if (parentId.isNotEmpty) 's': parentId,
        'ids': ids,
        'm': mode,
        't': touched.millisecondsSinceEpoch,
      };

  factory _Entry.fromJson(Map<String, dynamic> j) => _Entry(
        pluginId: j['p'] as String? ?? '',
        parentId: j['s'] as String? ?? '',
        ids: [for (final i in (j['ids'] as List? ?? const [])) i as String],
        mode: j['m'] as String? ?? '',
        touched: DateTime.fromMillisecondsSinceEpoch(j['t'] as int? ?? 0),
      );
}
