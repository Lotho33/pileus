import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/shared/player/player_loading_backdrop.dart';

void main() {
  test('resume position: m:ss, h:mm:ss past the hour', () {
    expect(PlayerLoadingBackdrop.formatPosition(5), '0:05');
    expect(PlayerLoadingBackdrop.formatPosition(754), '12:34');
    expect(PlayerLoadingBackdrop.formatPosition(3723), '1:02:03');
  });

  Future<void> pump(WidgetTester t, PlayerLoadingBackdrop w) =>
      t.pumpWidget(MaterialApp(home: Scaffold(body: w)));

  testWidgets('title, show and resume point', (t) async {
    await pump(
        t,
        const PlayerLoadingBackdrop(
            title: 'Episodio 5', subtitle: 'Serie', resumeAtSeconds: 754));
    expect(find.text('Episodio 5'), findsOneWidget);
    expect(find.text('Serie'), findsOneWidget);
    expect(find.text('Riprende da 12:34'), findsOneWidget);
  });

  testWidgets('from the start: no resume line; no image: still opaque',
      (t) async {
    await pump(t, const PlayerLoadingBackdrop(title: 'Film'));
    expect(find.textContaining('Riprende'), findsNothing);
    final box = t.widget<ColoredBox>(find
        .descendant(
            of: find.byType(PlayerLoadingBackdrop),
            matching: find.byType(ColoredBox))
        .first);
    expect(box.color, Colors.black);
  });
}
