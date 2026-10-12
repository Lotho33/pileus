/// How the "Riserva di riproduzione" setting (seconds) maps onto each
/// backend's own buffer knobs. Pure, so the numbers are testable.
library;

/// ExoPlayer's DefaultLoadControl windows, in ms.
typedef ExoBufferMs = ({
  int minBuffer,
  int maxBuffer,
  int forPlayback,
  int afterRebuffer,
});

/// - minBuffer = the reserve: ExoPlayer keeps loading until it holds this.
/// - maxBuffer = reserve × 1.75 (≤ 300s): room to run ahead of it.
/// - forPlayback = 2.5s: first start / after a seek, unchanged.
/// - afterRebuffer = reserve / 8, kept within 3–10s: how much has to be
///   back before playback resumes after a stall. It used to grow up to 20s
///   with the old slider, which only made every stall longer.
ExoBufferMs exoBufferMs(int reserveSec) {
  final minMs = reserveSec * 1000;
  final maxMs = (reserveSec * 1750).clamp(minMs, 300000);
  final afterMs = (reserveSec * 1000 / 8).round().clamp(3000, 10000);
  return (
    minBuffer: minMs,
    maxBuffer: maxMs,
    forPlayback: 2500.clamp(0, minMs),
    afterRebuffer: afterMs.clamp(0, minMs),
  );
}

/// mpv's demuxer byte ceiling. The reserve itself is time-based
/// (demuxer-readahead-secs / cache-secs); this is only a safety cap so a
/// high-bitrate stream can't buffer without bound — sized for the reserve at
/// a high 8 Mbit/s (1 MB per second), never below 16 MiB.
int mpvBufferCapBytes(int reserveSec) {
  const highBitrateBytesPerSec = 8 * 1000 * 1000 ~/ 8;
  final bytes = reserveSec * highBitrateBytesPerSec;
  const floor = 16 * 1024 * 1024;
  return bytes < floor ? floor : bytes;
}

/// hls.js (web): maxBufferLength = reserve, maxMaxBufferLength = reserve ×
/// 1.75 (≤ 300s) — same shape as ExoPlayer's min/max.
({double maxBufferLength, double maxMaxBufferLength}) hlsJsBuffer(
    int reserveSec) {
  final max = (reserveSec * 1.75).clamp(reserveSec.toDouble(), 300.0);
  return (
    maxBufferLength: reserveSec.toDouble(),
    maxMaxBufferLength: max,
  );
}

/// The reserve actually applied: the user's choice, except under "Hardware
/// modesto" where it is capped (90s VOD / 30s live) — those boxes are
/// RAM-starved and the buffered media lives in memory. Callers log both
/// values so a capped reserve is never silent.
int appliedReserveSec(int chosenSec,
    {required bool live, required bool lowPower}) {
  if (!lowPower) return chosenSec;
  final cap = live ? 30 : 90;
  return chosenSec > cap ? cap : chosenSec;
}
