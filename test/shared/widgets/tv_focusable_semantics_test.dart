import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/shared/widgets/tv_focusable.dart';

void main() {
  Future<void> pump(WidgetTester t, Widget w) =>
      t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: w))));

  testWidgets('icon-only control: its own label, as a button', (t) async {
    final h = t.ensureSemantics();
    await pump(
        t,
        TvFocusable(
          semanticLabel: 'Avanti di 10 secondi',
          onActivate: () {},
          builder: (_, __) => const Icon(Icons.forward_10),
        ));
    expect(find.bySemanticsLabel('Avanti di 10 secondi'), findsOneWidget);
    expect(
        t.getSemantics(find.bySemanticsLabel('Avanti di 10 secondi')),
        matchesSemantics(
            label: 'Avanti di 10 secondi',
            isButton: true,
            hasTapAction: true,
            isFocusable: true));
    h.dispose();
  });

  testWidgets('control with text: the texts become one spoken control',
      (t) async {
    final h = t.ensureSemantics();
    await pump(
        t,
        TvFocusable(
          onActivate: () {},
          builder: (_, __) => const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Lingua'), Text(' Italiano')]),
        ));
    expect(find.bySemanticsLabel(RegExp('Lingua.*Italiano', dotAll: true)),
        findsOneWidget);
    h.dispose();
  });
}
