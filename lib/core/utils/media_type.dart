enum MediaKind { standard, live, music, vodClip }

MediaKind mediaKindOf(String mediaType) {
  switch (mediaType) {
    case 'live':
      return MediaKind.live;
    case 'music':
      return MediaKind.music;
    case 'vod_clip':
      return MediaKind.vodClip;
    default:
      return MediaKind.standard;
  }
}
