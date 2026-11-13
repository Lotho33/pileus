// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;

import '../../core/di/injection.dart' show getIt;
import '../../core/grpc/auth_interceptor.dart';
import '../../core/grpc/clients/media_client.dart';
import '../../core/utils/perf_log.dart';
import 'data/media_repository.dart';

/// "La mia lista" — titles the active profile saved to watch later, kept on
/// mycelium (GetMyList/SetMyListItem) so the list follows the profile across
/// devices. One app-wide instance; every screen reads it and rebuilds on
/// [notifyListeners].
///
/// Changes are optimistic: the UI flips at once and rolls back if the
/// server refuses. A server without the RPCs (UNIMPLEMENTED) turns the
/// feature off ([supported]) until the next server change.
class MyList extends ChangeNotifier {
  MyList._();
  static final instance = MyList._();

  List<MyListItem> _items = const [];
  // The profile _items belong to — a list never shows on another profile.
  String? _owner;
  bool _supported = true;
  Future<void>? _loading;

  bool get supported => _supported;

  static String? get _profile {
    try {
      final pid = getIt<AuthInterceptor>().profileId ?? '';
      return pid.isEmpty ? null : pid;
    } catch (_) {
      return null;
    }
  }

  bool get _current => _owner != null && _owner == _profile;

  List<MyListItem> get items => _current ? _items : const [];

  List<MyListItem> forPlugin(String pluginId) => [
        for (final i in items)
          if (i.pluginId == pluginId) i
      ];

  bool contains(String pluginId, String mediaId) =>
      items.any((i) => i.pluginId == pluginId && i.mediaId == mediaId);

  /// Reloads the list for the active profile. Concurrent calls share one
  /// request.
  /// Keyed by profile: a load still in flight for the profile just left
  /// must not stand in for the new one's (it discards its own answer, so
  /// the new profile would show no list until the next refresh).
  Future<void> refresh() {
    final profile = _profile;
    if (_loading != null && _loadingFor == profile) return _loading!;
    _loadingFor = profile;
    late final Future<void> f;
    f = _load().whenComplete(() {
      if (identical(_loading, f)) _loading = null;
    });
    return _loading = f;
  }

  String? _loadingFor;

  Future<void> _load() async {
    final profile = _profile;
    try {
      final list = await getIt<MediaRepository>().getMyList();
      if (profile != _profile) return; // switched meanwhile
      _items = list;
      _owner = profile;
      _supported = true;
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unimplemented) {
        _supported = false;
        _items = const [];
        _owner = profile;
      } else {
        perf('mylist: load failed: $e');
        return;
      }
    } catch (e) {
      perf('mylist: load failed: $e');
      return;
    }
    notifyListeners();
  }

  // ── changes ───────────────────────────────────────────────────────────────

  /// Adds [item] if it isn't in the list, removes it otherwise. Returns the
  /// new state (true = in the list), or null when the server refused and
  /// the change was rolled back.
  Future<bool?> toggle(MyListItem item) async {
    final profile = _profile;
    if (profile == null) return null;
    if (!_current) {
      _items = const [];
      _owner = profile;
    }
    final before = _items;
    final add = !contains(item.pluginId, item.mediaId);
    _items = add
        ? [item, ..._items]
        : [
            for (final i in _items)
              if (!(i.pluginId == item.pluginId && i.mediaId == item.mediaId))
                i
          ];
    notifyListeners();
    try {
      await getIt<MediaRepository>().setInMyList(item, inList: add);
      return add;
    } catch (e) {
      perf('mylist: ${add ? 'add' : 'remove'} failed: $e');
      if (e is GrpcError && e.code == StatusCode.unimplemented) {
        _supported = false;
      }
      if (_owner == profile) {
        _items = before;
        notifyListeners();
      }
      return null;
    }
  }

  /// The card for a catalog item (home card, search result, details page),
  /// with everything it carries in `extra` — what a home shows for a focused
  /// card (plot, genres…) and what tells an anime from a series. The named
  /// arguments are what only a details page knows.
  static MyListItem itemFrom(
    String pluginId,
    CatalogItem item, {
    String mediaType = '',
    String plot = '',
    List<String> genres = const [],
    String fanartUrl = '',
    String logoUrl = '',
    LogoMeta? logoMeta,
  }) {
    final extra = Map<String, String>.of(item.extra);
    if (plot.isNotEmpty) extra['plot'] = plot;
    if (genres.isNotEmpty) extra['genres'] = genres.join(', ');
    return MyListItem(
      pluginId: pluginId,
      mediaId: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      mediaType: mediaType.isNotEmpty ? mediaType : item.mediaType,
      year: item.year,
      rating: item.rating,
      fanartUrl: fanartUrl.isNotEmpty ? fanartUrl : extra['fanart_url'] ?? '',
      logoUrl: logoUrl.isNotEmpty ? logoUrl : item.logoUrl,
      logoMeta: logoMeta ??
          (item.hasLogoMeta() && (logoUrl.isEmpty || logoUrl == item.logoUrl)
              ? item.logoMeta
              : null),
      extra: extra.entries,
    );
  }

  /// [itemFrom] with the typed metadata of a GetDetails answer.
  static MyListItem itemFromDetails(
    String pluginId,
    CatalogItem item,
    DetailsResponse? d, {
    String mediaType = '',
  }) {
    final series = d != null && d.hasSeries() ? d.series : null;
    final movie = d != null && d.hasMovie() ? d.movie : null;
    final entry = itemFrom(
      pluginId,
      item,
      mediaType: mediaType,
      plot: series?.plot ?? movie?.plot ?? '',
      genres: series?.genres ?? movie?.genres ?? const [],
      fanartUrl: series?.fanartUrl ?? movie?.fanartUrl ?? '',
      logoUrl: series?.logoUrl ?? movie?.logoUrl ?? '',
      logoMeta: series?.hasLogoMeta() == true
          ? series!.logoMeta
          : movie?.hasLogoMeta() == true
              ? movie!.logoMeta
              : null,
    );
    if (entry.year == 0) entry.year = series?.year ?? movie?.year ?? 0;
    return entry;
  }

  /// The catalog card for a saved title — what the "La mia lista" page opens.
  static CatalogItem toCatalogItem(MyListItem i) => CatalogItem(
        id: i.mediaId,
        title: i.title,
        posterUrl: i.posterUrl,
        mediaType: i.mediaType,
        year: i.year,
        rating: i.rating,
        logoUrl: i.logoUrl,
        logoMeta: i.hasLogoMeta() ? i.logoMeta : null,
        isDir: i.mediaType == 'series',
        extra: i.extra.entries,
      )..extra.addAll({
          if (i.fanartUrl.isNotEmpty) 'fanart_url': i.fanartUrl,
        });

  @visibleForTesting
  void resetForTest() {
    _items = const [];
    _owner = null;
    _supported = true;
    _loading = null;
    _loadingFor = null;
  }
}

/// Toggles [item] and says what happened — the one confirmation every
/// "La mia lista" button/menu entry shows.
Future<void> toggleMyListWithFeedback(
    ScaffoldMessengerState messenger, MyListItem item) async {
  final added = await MyList.instance.toggle(item);
  messenger.showSnackBar(SnackBar(
    content: Text(switch (added) {
      true => 'Aggiunto a La mia lista',
      false => 'Rimosso da La mia lista',
      null => 'Non è stato possibile aggiornare La mia lista',
    }),
  ));
}
