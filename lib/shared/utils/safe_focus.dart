import 'package:flutter/widgets.dart';

/// Wraps a nullable [FocusNode] reference the way this app's carousels and
/// overlay panels each ended up doing by hand, after the same two bugs kept
/// resurfacing independently in different files: requesting focus on a node
/// whose owning widget had already been disposed (a silent no-op or worse in
/// a release build, since the assertions that would catch it in debug are
/// stripped), and losing every focus target after a subtree unmounted with
/// no fallback wired up — which breaks Escape/Back too, not just directional
/// navigation, since an ancestor `Focus` scope's own key handling depends on
/// primary focus still being somewhere underneath it.
///
/// Concretely: `_firstResultFocus` in home_screen.dart's quick-search panel
/// was exactly this pattern, hand-rolled, before this existed — see its
/// usage there for the reference migration.
class SafeFocusRef {
  FocusNode? _node;

  /// True if a node is currently held, whether or not it's still attached
  /// to a live element.
  bool get isSet => _node != null;

  /// True if the held node currently has primary focus. False (not an
  /// error) when no node is held at all.
  bool get hasFocus => _node?.hasFocus ?? false;

  void set(FocusNode? node) => _node = node;

  /// Drop the held reference without touching the node itself — call this
  /// when whatever owns the node is about to unmount, so a later
  /// [requestFocus] doesn't retry on a soon-to-be-disposed node.
  void clear() => _node = null;

  /// Requests focus on the held node if — and only if — it's still
  /// attached to a live element. Returns whether the request was actually
  /// made, so a caller can fall back to something else instead of the
  /// failure mode this exists to prevent: silently doing nothing.
  bool requestFocus() {
    final n = _node;
    if (n == null || n.context == null) return false;
    n.requestFocus();
    return true;
  }
}

/// Walks a 0-indexed sequence of length [length] from [from] in [direction]
/// (`+1` or `-1`), skipping any index [isSkippable] flags, and returns the
/// first landable index — or `null` if every remaining index in that
/// direction is skippable.
///
/// Same idiom home_screen.dart's `onCatalogEmpty` and search_screen.dart's
/// `_moveVertical` each hand-rolled separately before this existed: a
/// directional move that stops dead at the first skippable index (an empty
/// catalog, a filter row with no controls) instead of walking past it is
/// exactly how "focus permanently stranded on one empty catalog" and
/// "filter rows past an unrecognized type become unreachable" kept
/// happening independently in different screens.
int? nextFocusableIndex({
  required int from,
  required int direction,
  required int length,
  required bool Function(int index) isSkippable,
}) {
  var i = from + direction;
  while (i >= 0 && i < length && isSkippable(i)) {
    i += direction;
  }
  return (i >= 0 && i < length) ? i : null;
}

/// True if focus is currently on any node in [nodes]. The "hadFocus" guard
/// used before rebuilding a `List<FocusNode>` whose length is about to
/// change (a carousel's cards, a strip's items) — only restore focus into
/// the rebuilt list if it was actually there before, otherwise a background
/// reload silently steals focus from wherever the user actually is. Same
/// one-line check duplicated across card_carousel_block_view.dart's two
/// carousel types and home_screen.dart's Continue Watching strip before
/// this existed; named here so it reads as the guard it is, not an
/// incidental `.any()` call.
bool anyHasFocus(Iterable<FocusNode> nodes) => nodes.any((n) => n.hasFocus);
