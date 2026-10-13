import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/presentation/widgets/player_seek_bar.dart';

/// D-pad scrubbing on the TV seek bar: preview only while held, one real
/// seek after release — and a release must be honoured even while the bar
/// is disabled (buffering), or the hold runs away (the reported bug: hold →
/// first seek starts a rebuffer → KeyUp swallowed → ~20s of ramping → huge
/// jump, playback left broken).
void main() {
  late List<double> seeks;
  late int scrubStarts;
  late int scrubEnds;
  late FocusNode node;

  Future<void> pumpBar(WidgetTester tester, {bool disabled = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 800,
            child: PlayerSeekBar(
              posSec: 100,
              durSec: 3600,
              skipIntervals: const [],
              onSeek: seeks.add,
              onScrubStart: () => scrubStarts++,
              onScrubEnd: () => scrubEnds++,
              focusNode: node,
              disabled: disabled,
            ),
          ),
        ),
      ),
    ));
    node.requestFocus();
    await tester.pump();
  }

  setUp(() {
    seeks = [];
    scrubStarts = 0;
    scrubEnds = 0;
    node = FocusNode();
  });

  tearDown(() => node.dispose());

  testWidgets('a tap is one seek of 5s, after the commit delay',
      (tester) async {
    await pumpBar(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    expect(seeks, isEmpty, reason: 'nothing seeks while the scrub is open');
    await tester.pump(const Duration(milliseconds: 800));
    expect(seeks, [105]);
    expect(scrubStarts, 1);
    expect(scrubEnds, 1);
  });

  testWidgets('quick taps add up into a single seek', (tester) async {
    await pumpBar(tester);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(seeks, [115]);
  });

  testWidgets('a hold previews, then commits once on release',
      (tester) async {
    await pumpBar(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    // 1.4s held = 4 ticks: 5 (press) + 5 + 5 (ticks 1–2) + 10 + 10 (ticks 3–4).
    await tester.pump(const Duration(milliseconds: 1400));
    expect(seeks, isEmpty);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 800));
    expect(seeks, [135]);
    expect(scrubEnds, 1);
  });

  testWidgets('release still stops the hold while the bar is disabled',
      (tester) async {
    await pumpBar(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 400));
    // Playback starts buffering mid-scrub.
    await pumpBar(tester, disabled: true);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    // Long after: no runaway ticks past the release.
    await tester.pump(const Duration(seconds: 5));
    expect(seeks.length, 1);
    expect(seeks.single, lessThan(120));
    expect(scrubEnds, 1);
  });

  testWidgets('a new press while disabled does nothing', (tester) async {
    await pumpBar(tester, disabled: true);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 1));
    expect(seeks, isEmpty);
    expect(scrubStarts, 0);
  });

  testWidgets('another key commits the pending scrub right away',
      (tester) async {
    await pumpBar(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    expect(seeks, [95]);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(seconds: 2));
    expect(seeks, [95]);
  });

  testWidgets('press/release bursts (CEC) keep accelerating', (tester) async {
    await pumpBar(tester);
    // 8 short press/release pairs, 360ms apart: each press lands within the
    // commit window, so the ramp's ticks carry over instead of restarting.
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 360));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(seeks.length, 1);
    // 8 presses × 5s + ticks 1..8 (5,5,10,10,10,30,30,30) = 40 + 130.
    expect(seeks.single, 270);
  });
}
