/// Rows and grids that page by themselves: no "Carica altri" to press, the
/// next page is asked for while the user is still a few cards away from the
/// end, so it's usually there before they get to it. Shared by the home rows
/// and the search results on every platform (and mirrored in pileus-vega's
/// src/core/paging.ts).
library;

import 'bloc/discovery_state.dart';

/// How many cards before the end of what's loaded the next page is asked for.
const kLoadAheadItems = 5;

/// A home row stops growing past this many cards: the home is for browsing,
/// a longer list belongs to search — and each page is another plugin request
/// and more cards kept around on a Fire Stick.
const kHomeRowMaxItems = 60;

/// Whether [s] has a next page worth asking for by itself. A failed request
/// isn't retried automatically (that would loop while the row is on screen):
/// the row shows "Riprova" instead. [cap]: stop once this many items are in.
bool canAutoLoadMore(DiscoveryLoaded s, {int? cap}) =>
    s.hasMore &&
    !s.isLoadingMore &&
    !s.loadMoreFailed &&
    (cap == null || s.items.length < cap);

/// Whether the row/grid still has a trailing slot to show: loading, "Riprova",
/// or a next page not asked for yet.
bool showsMoreSlot(DiscoveryLoaded s, {int? cap}) =>
    s.hasMore && (cap == null || s.items.length < cap);

/// Card [index] of [count] just came into view (focused on TV, built by a
/// lazy list elsewhere): is that close enough to the end to load more?
bool nearEnd(int index, int count) => index >= count - kLoadAheadItems;
