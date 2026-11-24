/// Live sources as a tree: a plugin may give each source a `path` — its
/// place among the choices, outermost first and ending with its own name
/// (["Canale A", "Player 2"]). Sources sharing a prefix are a group; any
/// depth, and sources may use different depths. Without paths the list
/// stays flat, as before.
///
/// [sourceRows] turns the flat list (in the plugin's order) into what a
/// picker shows: group headers and sources, indented by depth, with the
/// groups outside [open] collapsed. Every picker (TV panel, mobile sheet,
/// desktop/web menus) renders these rows its own way; tapping a header
/// opens that group, tapping a source plays it. The automatic fallback
/// (LiveFailover) needs nothing from this: it already follows the list
/// order, which keeps a group's sources together.
library;

class SourceRow {
  /// 0 = top level.
  final int depth;

  /// The group's name, or the source's own (short) name.
  final String title;

  /// The source's index in the flat list; null for a group header.
  final int? index;

  /// The group a header opens (its full prefix); for a source, the group it
  /// belongs to.
  final List<String> group;

  /// Sources under this header (any depth); 1 for a source.
  final int count;

  const SourceRow._(this.depth, this.title, this.index, this.group, this.count);

  bool get isGroup => index == null;

  @override
  String toString() =>
      '${'  ' * depth}${isGroup ? '▸ ' : ''}$title${isGroup ? ' ($count)' : ' #$index'}';
}

bool _startsWith(List<String> a, List<String> prefix) {
  if (prefix.length > a.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (a[i] != prefix[i]) return false;
  }
  return true;
}

/// True when any source has a path of two or more levels (so there is
/// something to group); single-level paths only shorten the names.
bool hasSourceGroups(List<List<String>> paths) =>
    paths.any((p) => p.length > 1);

/// The rows of a picker for sources with [paths] and full [labels]
/// (parallel lists, the plugin's order). [open] is the group whose content
/// is shown (with every group above it); null = everything open. A source
/// without a path shows its label at the top level.
List<SourceRow> sourceRows(List<List<String>> paths, List<String> labels,
    {List<String>? open}) {
  final n = labels.length;
  List<String> pathOf(int i) =>
      i < paths.length && paths[i].isNotEmpty ? paths[i] : const [];
  final rows = <SourceRow>[];
  var prev = const <String>[];
  for (var i = 0; i < n; i++) {
    final p = pathOf(i);
    final group = p.length > 1 ? p.sublist(0, p.length - 1) : const <String>[];
    // Headers for the groups this source enters (those it doesn't share
    // with the previous source's group).
    var shared = 0;
    while (shared < group.length &&
        shared < prev.length &&
        group[shared] == prev[shared]) {
      shared++;
    }
    for (var d = shared; d < group.length; d++) {
      final g = group.sublist(0, d + 1);
      // Shown when its parent is open (or everything is).
      if (open == null || _startsWith(open, g.sublist(0, d))) {
        var count = 0;
        for (var j = i; j < n; j++) {
          if (_startsWith(pathOf(j), g) && pathOf(j).length > g.length) {
            count++;
          }
        }
        rows.add(SourceRow._(d, g[d], null, g, count));
      }
    }
    prev = group;
    if (open == null || _startsWith(open, group)) {
      final title = p.isNotEmpty
          ? p.last
          : (labels[i].isNotEmpty ? labels[i] : 'Sorgente ${i + 1}');
      rows.add(SourceRow._(group.length, title, i, group, 1));
    }
  }
  return rows;
}

/// The group of source [index] (its path without its own name): the group
/// a picker opens first, so the source playing is in view.
List<String> groupOf(List<List<String>> paths, int index) {
  if (index < 0 || index >= paths.length) return const [];
  final p = paths[index];
  return p.length > 1 ? p.sublist(0, p.length - 1) : const [];
}

/// A short "Canale A · Player 2" for a source, from its path (or label).
String sourceTitle(List<List<String>> paths, List<String> labels, int index) {
  if (index >= 0 && index < paths.length && paths[index].isNotEmpty) {
    return paths[index].join(' · ');
  }
  if (index >= 0 && index < labels.length && labels[index].isNotEmpty) {
    return labels[index];
  }
  return 'Sorgente ${index + 1}';
}

/// Whether [group] is open (its content shown) when [open] is the open group.
bool groupIsOpen(List<String>? open, List<String> group) =>
    open == null || _startsWith(open, group);

/// The open group after tapping the header of [group]: an open group closes
/// (back to its parent), a closed one opens.
List<String> toggleGroup(List<String> open, List<String> group) =>
    groupIsOpen(open, group) ? group.sublist(0, group.length - 1) : group;
