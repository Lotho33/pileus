/// Recovery from ExoPlayer's "this device's decoder can't take that video"
/// failure (`format_supported=NO_EXCEEDS_CAPABILITIES`).
///
/// ExoPlayer runs with `exceedRendererCapabilitiesIfNecessary` on: when no
/// HLS variant fits the decoder — or the master playlist doesn't declare
/// RESOLUTION, so nothing looks over the limit — it starts one anyway and
/// MediaCodec fails on the first frame. Seen on a Xiaomi Mi TV Stick
/// (Amlogic, decoder max ~1920×1088) with a 4:3 anime upscaled to
/// 1920×1440. Pure helpers here, the engine does the reopen.
library;

/// The video format MediaCodec refused, as far as the error text tells.
/// Any field can be null (ExoPlayer prints -1 for unknown values).
class FailedVideoFormat {
  final int? width;
  final int? height;
  final int? bitrate;

  const FailedVideoFormat({this.width, this.height, this.bitrate});

  /// "1920×1440" for the user-facing message, or null when unknown.
  String? get sizeLabel =>
      (width != null && height != null) ? '$width×$height' : null;
}

/// One HLS variant the player could be limited to.
typedef VideoVariant = ({int height, int bitrate});

/// Highest resolution a fallback prefers when the variants declare one —
/// what every Android TV decoder handles.
const kFallbackMaxHeight = 1080;

// Media3's Format.toString(): Format(id, label, containerMimeType,
// sampleMimeType, codecs, bitrate, language, [width, height, frameRate, ...
final _formatRe =
    RegExp(r'Format\((?:[^,]*, ){5}(-?\d+), [^,]*, \[(-?\d+), (-?\d+)');

int? _known(String? s) {
  final v = int.tryParse(s ?? '');
  return (v == null || v <= 0) ? null : v;
}

/// Non-null when [message] is a decoder-capability failure. A bare
/// "MediaCodecVideoRenderer error" counts too when the format is taller
/// than any TV decoder is guaranteed to take (some devices report the
/// failure without the capability verdict).
FailedVideoFormat? parseDecoderCapabilityError(String message) {
  final m = _formatRe.firstMatch(message);
  final failed = FailedVideoFormat(
    bitrate: _known(m?.group(1)),
    width: _known(m?.group(2)),
    height: _known(m?.group(3)),
  );
  if (message.contains('EXCEEDS_CAPABILITIES')) return failed;
  if (message.contains('MediaCodecVideoRenderer error') &&
      (failed.height ?? 0) > 1088) {
    return failed;
  }
  return null;
}

/// Index into [variants] of the quality to fall back to after [failed], or
/// null when there is nothing lower to try. [tried] holds indices already
/// used as a fallback for this source (one attempt per quality, no loops).
///
/// Prefers the highest variant at or under [maxHeight]; failing that, the
/// next one below the format that failed. Without declared resolutions it
/// goes by bitrate.
int? pickDecoderFallback(
  List<VideoVariant> variants,
  FailedVideoFormat failed,
  Set<int> tried, {
  int maxHeight = kFallbackMaxHeight,
}) {
  bool isLower(VideoVariant v) {
    final fh = failed.height, fb = failed.bitrate;
    // The playlist's declared RESOLUTION can lie (a "1080p" variant that is
    // really 1920x1440 — exactly what fails): when bitrates are known, a
    // variant at or above the failed one's is the same or a bigger stream,
    // whatever height it claims.
    if (fb != null && v.bitrate > 0 && v.bitrate >= fb) return false;
    if (fh != null && v.height > 0) return v.height < fh;
    if (fb != null && v.bitrate > 0) return v.bitrate < fb;
    if (v.height > 0) return v.height <= maxHeight;
    return false;
  }

  bool fits(VideoVariant v) => v.height > 0 && v.height <= maxHeight;

  int? best;
  for (var i = 0; i < variants.length; i++) {
    final v = variants[i];
    if (tried.contains(i) || !isLower(v)) continue;
    if (best == null) {
      best = i;
      continue;
    }
    final b = variants[best];
    if (fits(v) != fits(b)) {
      if (fits(v)) best = i;
      continue;
    }
    if (v.height != b.height ? v.height > b.height : v.bitrate > b.bitrate) {
      best = i;
    }
  }
  return best;
}
