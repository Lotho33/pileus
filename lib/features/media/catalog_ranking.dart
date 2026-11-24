import '../../core/grpc/generated/media.pb.dart' show CatalogDef, CatalogItem;

/// Top 10 rows and card badges — mycelium core 2.0.1 contract:
///  - a catalog with `style_hint: "ranked"` is a chart: at most
///    [kRankedMaxItems] cards, no further pages, each drawn beside its
///    number;
///  - `rank` on an item (> 0) is the number to show, else its position —
///    plugins drop titles already shown higher up, so positions can slip;
///  - `badge` on an item: "new" / "new_episode"; any other value shows
///    nothing (a newer plugin never breaks an older client).
const kRankedMaxItems = 10;

bool isRankedCatalog(CatalogDef def) => def.styleHint == 'ranked';

int catalogItemRank(CatalogItem item) => item.rank;

String catalogItemBadge(CatalogItem item) => item.badge;

/// The number to draw for the item at [index] (0-based) of a ranked row.
int rankFor(int rank, int index) => rank > 0 ? rank : index + 1;
