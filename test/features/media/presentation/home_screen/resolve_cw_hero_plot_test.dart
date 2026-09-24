import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/media/presentation/home_screen.dart';

void main() {
  group('resolveCwHeroPlot', () {
    test('prefers the series\' own plot', () {
      final plot = resolveCwHeroPlot(
        seriesPlot: 'The series synopsis.',
        savedPlot: 'Whatever the CW row had saved.',
      );
      expect(plot, 'The series synopsis.');
    });

    test('falls back to the saved plot when the series has none', () {
      final plot = resolveCwHeroPlot(
        seriesPlot: '',
        savedPlot: 'Whatever the CW row had saved.',
      );
      expect(plot, 'Whatever the CW row had saved.');
    });

    test('never falls through to episode- or season-level text', () {
      // Regression test: this used to fall back to the episode's own plot,
      // then the season overview, before finally trying the saved plot —
      // both removed on purpose. Only the series' plot and the CW row's
      // already-saved (series-level) plot are legitimate sources.
      final plot = resolveCwHeroPlot(seriesPlot: '', savedPlot: '');
      expect(plot, '');
    });
  });
}
