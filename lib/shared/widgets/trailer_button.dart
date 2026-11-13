// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';

import '../../core/grpc/clients/media_client.dart' show DetailsResponse;
import '../utils/open_trailer.dart';

/// The trailer link a details answer carries (MovieDetails/SeriesDetails
/// .trailer_url, filled by the plugin), or ''.
String trailerUrlOf(DetailsResponse? d) {
  if (d == null) return '';
  if (d.hasSeries()) return d.series.trailerUrl;
  if (d.hasMovie()) return d.movie.trailerUrl;
  return '';
}

/// "Trailer" for a details page's play row — mobile, desktop and web (the
/// TV has TvTrailerChip). Nothing when the plugin gave no trailer.
class TrailerButton extends StatelessWidget {
  final String url;
  const TrailerButton({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const SizedBox.shrink();
    return IconButton.filledTonal(
      tooltip: 'Trailer',
      onPressed: () =>
          openTrailerWithFeedback(ScaffoldMessenger.of(context), url),
      icon: const Icon(Icons.movie_outlined),
    );
  }
}
