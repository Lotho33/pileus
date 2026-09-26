import 'dart:convert';

/// Per-profile home-screen customisation for plugins and their catalogs
/// (carousels). Server-synced as part of the profile's `ProfilePrefs`
/// "plugins" block (see `ProfilePrefs`/`SettingsRepository`), so it follows
/// the profile to every paired device — `MediaRepository.loadPluginPrefs`/
/// `savePluginPrefs` are the read/write entry points UI code actually calls,
/// with a one-time migration from this class's old local-only storage.
///
///  - [hiddenPlugins]: plugin ids that should not appear in the home nav or
///    load any content at all.
///  - [catalogs]: per-plugin catalog order + hidden catalog ids.
class PluginPrefs {
  final Set<String> hiddenPlugins;
  final Map<String, PluginCatalogPrefs> catalogs;

  const PluginPrefs({
    this.hiddenPlugins = const {},
    this.catalogs = const {},
  });

  bool isPluginHidden(String pluginId) => hiddenPlugins.contains(pluginId);

  PluginCatalogPrefs catalogPrefs(String pluginId) =>
      catalogs[pluginId] ?? const PluginCatalogPrefs();

  bool get isEmpty => hiddenPlugins.isEmpty && catalogs.isEmpty;

  PluginPrefs withPluginHidden(String pluginId, bool hidden) {
    final next = Set<String>.from(hiddenPlugins);
    if (hidden) {
      next.add(pluginId);
    } else {
      next.remove(pluginId);
    }
    return PluginPrefs(hiddenPlugins: next, catalogs: catalogs);
  }

  PluginPrefs withCatalogPrefs(String pluginId, PluginCatalogPrefs prefs) {
    final next = Map<String, PluginCatalogPrefs>.from(catalogs);
    if (prefs.isEmpty) {
      next.remove(pluginId);
    } else {
      next[pluginId] = prefs;
    }
    return PluginPrefs(hiddenPlugins: hiddenPlugins, catalogs: next);
  }

  factory PluginPrefs.fromJson(Map<String, dynamic> json) {
    final hidden = (json['hiddenPlugins'] as List?)?.cast<String>() ?? const [];
    final rawCatalogs = (json['catalogs'] as Map?) ?? const {};
    final catalogs = <String, PluginCatalogPrefs>{};
    rawCatalogs.forEach((key, value) {
      if (value is Map) {
        catalogs[key.toString()] =
            PluginCatalogPrefs.fromJson(value.cast<String, dynamic>());
      }
    });
    return PluginPrefs(hiddenPlugins: hidden.toSet(), catalogs: catalogs);
  }

  Map<String, dynamic> toJson() => {
        'hiddenPlugins': hiddenPlugins.toList(),
        'catalogs': {
          for (final e in catalogs.entries) e.key: e.value.toJson(),
        },
      };

  static PluginPrefs decode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return PluginPrefs.fromJson(map);
    } catch (_) {}
    return const PluginPrefs();
  }

  String encode() => jsonEncode(toJson());
}

class PluginCatalogPrefs {
  /// Desired catalog id order. May be partial or contain stale ids — the
  /// apply step in MediaRepository.listPlugins reconciles it against the
  /// live catalog list (unknown ids dropped, unlisted catalogs appended).
  final List<String> order;

  /// Catalog ids hidden from the home screen.
  final Set<String> hidden;

  const PluginCatalogPrefs({
    this.order = const [],
    this.hidden = const {},
  });

  bool get isEmpty => order.isEmpty && hidden.isEmpty;

  bool isHidden(String catalogId) => hidden.contains(catalogId);

  PluginCatalogPrefs withHidden(String catalogId, bool hidden) {
    final next = Set<String>.from(this.hidden);
    if (hidden) {
      next.add(catalogId);
    } else {
      next.remove(catalogId);
    }
    return PluginCatalogPrefs(order: order, hidden: next);
  }

  PluginCatalogPrefs withOrder(List<String> order) =>
      PluginCatalogPrefs(order: List<String>.from(order), hidden: hidden);

  factory PluginCatalogPrefs.fromJson(Map<String, dynamic> json) =>
      PluginCatalogPrefs(
        order: (json['order'] as List?)?.cast<String>() ?? const [],
        hidden: ((json['hidden'] as List?)?.cast<String>() ?? const []).toSet(),
      );

  Map<String, dynamic> toJson() => {
        'order': order,
        'hidden': hidden.toList(),
      };
}
