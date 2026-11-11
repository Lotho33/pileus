import 'package:flutter/material.dart';

import '../../core/grpc/clients/media_client.dart'
    show CatalogItem, DetailsResponse;
import '../../features/media/my_list.dart';

/// "La mia lista" toggle for a details page's play row — mobile, desktop
/// and web (the TV has its own D-pad chip, see details_actions.dart). Hidden
/// on a server without the feature.
class MyListButton extends StatelessWidget {
  final String pluginId;
  final CatalogItem item;
  // "series"/"movie" — used when the catalog item didn't carry its type.
  final String mediaType;
  // What the page loaded: the plot, genres… a saved card shows later.
  final DetailsResponse? details;

  const MyListButton({
    super.key,
    required this.pluginId,
    required this.item,
    required this.mediaType,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MyList.instance,
      builder: (context, _) {
        final list = MyList.instance;
        if (!list.supported) return const SizedBox.shrink();
        final saved = list.contains(pluginId, item.id);
        return IconButton.filledTonal(
          tooltip: saved ? 'Rimuovi da La mia lista' : 'Aggiungi a La mia lista',
          onPressed: () => toggleMyListWithFeedback(
            ScaffoldMessenger.of(context),
            MyList.itemFromDetails(pluginId, item, details,
                mediaType: item.mediaType.isNotEmpty ? item.mediaType : mediaType),
          ),
          icon: Icon(saved ? Icons.check_rounded : Icons.add_rounded),
        );
      },
    );
  }
}
