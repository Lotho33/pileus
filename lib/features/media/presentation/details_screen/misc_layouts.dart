// Part of details_screen.dart — split out for readability (plan 2e). The
// library file holds the shared imports, the layout-ratio comment, the
// DetailsScreen / _DetailsView / _DetailsContent entry chain and the shared
// logo helpers (logoUrlOnly / logoDark / logoRenderSize); private
// identifiers are shared across all parts.
part of '../details_screen.dart';

// ── Anime series layout ───────────────────────────────────────────────────────

// ── Music layout ──────────────────────────────────────────────────────────────

class _MusicLayout extends StatelessWidget {
  final String pluginId;
  final DetailsResponse response;
  const _MusicLayout({required this.pluginId, required this.response});

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final item = response.item;
    final d = response.hasMusic() ? response.music : null;
    final artist = d?.artist.isNotEmpty == true ? d!.artist : '';
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textHigh),
                onPressed: () => context.pop(),
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.posterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      // Web-only, no-op on every other platform — see image_sizing.dart's
                      // "ImageRenderMethodForWeb.HttpGet" section for why every
                      // CachedNetworkImage call site in the app sets this.
                      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                      imageUrl: posterSrc(
                          item.posterUrl, cacheWidthFor(context, 280)),
                      width: 280,
                      height: 280,
                      fit: BoxFit.cover,
                      memCacheWidth: cacheWidthFor(context, 280),
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => const SizedBox(
                          width: 280,
                          height: 280,
                          child: ColoredBox(color: Colors.white12)),
                      errorWidget: (_, __, ___) => Container(
                          width: 280, height: 280, color: Colors.white12))
                  : Container(
                      width: 280,
                      height: 280,
                      color: Colors.white12,
                      child: const Icon(Icons.music_note,
                          color: AppTheme.textLow, size: 80)),
            ),
          ),
          const SizedBox(height: 24),
          Text(item.title,
              style: TextStyle(
                  color: AppTheme.textHigh,
                  fontSize: sh * (24.0 / 1080.0),
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          if (artist.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(artist,
                style: TextStyle(
                    color: Colors.white54, fontSize: sh * (16.0 / 1080.0)),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 32),
          _WatchButton(
              pluginId: pluginId,
              mediaId: item.id,
              isAudio: true,
              posterUrl: item.posterUrl,
              itemTitle: item.title),
          const Spacer(),
        ],
      ),
    );
  }
}

// ── VOD clip layout ───────────────────────────────────────────────────────────

class _VodClipLayout extends StatelessWidget {
  final String pluginId;
  final DetailsResponse response;
  const _VodClipLayout({required this.pluginId, required this.response});

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    final item = response.item;
    final d = response.hasVideo() ? response.video : null;
    final channel = d?.channelName.isNotEmpty == true ? d!.channelName : '';
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                item.posterUrl.isNotEmpty
                    ? CachedNetworkImage(
                        // Web-only, no-op on every other platform — see image_sizing.dart's
                        // "ImageRenderMethodForWeb.HttpGet" section for why every
                        // CachedNetworkImage call site in the app sets this.
                        imageRenderMethodForWeb:
                            ImageRenderMethodForWeb.HttpGet,
                        imageUrl: backdropSrc(
                            item.posterUrl, backdropCacheWidth(context)),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: backdropCacheWidth(context),
                        fadeInDuration: const Duration(milliseconds: 200),
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.grey[900]))
                    : Container(color: Colors.grey[900]),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon:
                        const Icon(Icons.arrow_back, color: AppTheme.textHigh),
                    onPressed: () => context.pop(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          color: AppTheme.textHigh,
                          fontSize: sh * (22.0 / 1080.0),
                          fontWeight: FontWeight.bold)),
                  if (channel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(channel,
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: sh * (14.0 / 1080.0))),
                  ],
                  const SizedBox(height: 24),
                  _WatchButton(
                      pluginId: pluginId,
                      mediaId: item.id,
                      posterUrl: item.posterUrl,
                      fanartUrl: item.extra['fanart_url'] ?? '',
                      coverUrl: item.extra['cover_url'] ?? '',
                      itemTitle: item.title),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
