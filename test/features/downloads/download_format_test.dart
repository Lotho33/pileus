import 'package:fixnum/fixnum.dart' show Int64;
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    show DownloadVariant, DownloadTrack, DownloadInfo, PluginInfo;
import 'package:pileus/features/downloads/download_format.dart';

DownloadVariant _variant({
  int estimatedBytes = 0,
  bool bandwidthIsPeak = false,
}) =>
    DownloadVariant(
        estimatedBytes: Int64(estimatedBytes),
        bandwidthIsPeak: bandwidthIsPeak);

DownloadTrack _track({int estimatedBytes = 0}) =>
    DownloadTrack(estimatedBytes: Int64(estimatedBytes));

void main() {
  group('pluginSupportsDownload', () {
    test('true when capabilities lists "download"', () {
      final p = PluginInfo(capabilities: ['search', 'download']);
      expect(pluginSupportsDownload(p), isTrue);
    });

    test('false when absent', () {
      final p = PluginInfo(capabilities: ['search']);
      expect(pluginSupportsDownload(p), isFalse);
    });
  });

  group('totalEstimatedBytes', () {
    test('variant alone when no audio selected', () {
      final v = _variant(estimatedBytes: 1000);
      expect(
          totalEstimatedBytes(variant: v, selectedAudio: const []), 1000);
    });

    test('variant + every selected audio track, subtitles never counted', () {
      final v = _variant(estimatedBytes: 1000);
      final audio = [_track(estimatedBytes: 100), _track(estimatedBytes: 50)];
      expect(totalEstimatedBytes(variant: v, selectedAudio: audio), 1150);
    });

    test('null variant contributes 0', () {
      expect(
          totalEstimatedBytes(
              variant: null, selectedAudio: [_track(estimatedBytes: 20)]),
          20);
    });
  });

  group('formatBytes', () {
    test('bytes', () => expect(formatBytes(0), '0 B'));
    test('sub-KB stays in bytes', () => expect(formatBytes(512), '512 B'));
    test('KB', () => expect(formatBytes(2048), '2.0 KB'));
    test('MB with one decimal under 10',
        () => expect(formatBytes(5 * 1024 * 1024), '5.0 MB'));
    test('GB', () => expect(formatBytes(2 * 1024 * 1024 * 1024), '2.0 GB'));
  });

  group('formatVariantSize', () {
    test('plain size when not a peak estimate', () {
      final v = _variant(estimatedBytes: 1024 * 1024, bandwidthIsPeak: false);
      expect(formatVariantSize(v), '1.0 MB');
    });

    test('"fino a ~" prefix when bandwidth_is_peak', () {
      final v = _variant(estimatedBytes: 1024 * 1024, bandwidthIsPeak: true);
      expect(formatVariantSize(v), 'fino a ~1.0 MB');
    });
  });

  group('formatEtaLabel', () {
    test('unknown rate → empty', () {
      expect(formatEtaLabel(1000, 0), '');
    });
    test('unknown total → empty', () {
      expect(formatEtaLabel(0, 1000), '');
    });
    test('seconds', () => expect(formatEtaLabel(50, 10), '~5 s'));
    test('minutes', () => expect(formatEtaLabel(600, 1), '~10 min'));
    test('hours + minutes',
        () => expect(formatEtaLabel(3600 * 2 + 60 * 15, 1), '~2 h 15min'));
    test('exact hours, no minutes suffix',
        () => expect(formatEtaLabel(3600 * 3, 1), '~3 h'));
  });

  group('retentionLabel', () {
    test('0 = never', () => expect(retentionLabel(0),
        'Il file resta sul server finché non lo elimini'));
    test('singular day', () => expect(
        retentionLabel(1), 'Il file resta sul server per 1 giorno'));
    test('plural days', () => expect(
        retentionLabel(7), 'Il file resta sul server per 7 giorni'));
  });

  group('qualityBelowUsualWarning', () {
    test('nothing to warn about', () {
      expect(
          qualityBelowUsualWarning(
              qualityBelowUsual: false, usualMaxHeight: 1080, bestHeightNow: 1080),
          '');
    });

    test('flagged with a known usual height', () {
      final msg = qualityBelowUsualWarning(
          qualityBelowUsual: true, usualMaxHeight: 1080, bestHeightNow: 720);
      expect(msg, contains('720p'));
      expect(msg, contains('1080p'));
    });

    test('usualMaxHeight unset suppresses the warning even if flagged', () {
      expect(
          qualityBelowUsualWarning(
              qualityBelowUsual: true, usualMaxHeight: 0, bestHeightNow: 720),
          '');
    });
  });

  group('downloadStatusLabel', () {
    String fmtTime(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    test('queued', () {
      final i = DownloadInfo(status: 'queued');
      expect(downloadStatusLabel(i, formatTime: fmtTime), 'In coda');
    });

    test('scheduled with a time', () {
      final at = DateTime(2026, 1, 1, 3, 30);
      final i = DownloadInfo(
          status: 'scheduled',
          scheduledFor: Int64(at.millisecondsSinceEpoch ~/ 1000));
      expect(downloadStatusLabel(i, formatTime: fmtTime),
          'Programmato alle 03:30');
    });

    test('running shows rounded percent', () {
      final i = DownloadInfo(status: 'running', progress: 0.42);
      expect(downloadStatusLabel(i, formatTime: fmtTime), 'Preparazione 42%');
    });

    test('completed', () {
      final i = DownloadInfo(status: 'completed');
      expect(downloadStatusLabel(i, formatTime: fmtTime), 'Pronto');
    });

    test('failed with server error text', () {
      final i = DownloadInfo(status: 'failed', error: 'spazio esaurito');
      expect(
          downloadStatusLabel(i, formatTime: fmtTime), 'spazio esaurito');
    });

    test('failed with no error text falls back to a generic label', () {
      final i = DownloadInfo(status: 'failed');
      expect(downloadStatusLabel(i, formatTime: fmtTime), 'Errore');
    });

    test('canceled', () {
      final i = DownloadInfo(status: 'canceled');
      expect(downloadStatusLabel(i, formatTime: fmtTime), 'Annullato');
    });

    // "Non è un errore: nessuna azione per l'utente, nessun retry" — the
    // server pauses its own downloads while someone is watching something
    // and resumes them by itself; this must read as calm/informational, not
    // as a failure state.
    test('paused reads as calm and informational, not an error', () {
      final i = DownloadInfo(status: 'paused');
      final label = downloadStatusLabel(i, formatTime: fmtTime);
      expect(label, 'In pausa — riprende quando nessuno guarda');
      expect(label.toLowerCase(), isNot(contains('errore')));
    });
  });

  group('upgradePendingLabel', () {
    test('with a known preferred-hours window', () {
      expect(upgradePendingLabel('02:00-06:00'),
          'Cerco una qualità migliore (02:00-06:00)');
    });

    test('with no known window still reads fine', () {
      expect(upgradePendingLabel(''), 'Cerco una qualità migliore');
    });
  });

  group('preferredHoursSourceLabel', () {
    test('plugin', () => expect(
        preferredHoursSourceLabel('plugin'), 'consigliata dalla sorgente'));
    test(
        'learned',
        () => expect(preferredHoursSourceLabel('learned'),
            'in queste ore la qualità di solito è migliore'));
    test('unknown/empty falls back to an empty label',
        () => expect(preferredHoursSourceLabel(''), ''));
  });

  test('sharedIndicatorLabel is a fixed, informative string', () {
    expect(sharedIndicatorLabel, 'Condiviso con un altro profilo');
  });
}
