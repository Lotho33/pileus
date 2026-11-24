// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/source_tree_list.dart';

void main() {
  testWidgets('un gruppo si apre col tocco e la sorgente parte', (t) async {
    int? picked;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SourceTreeList(
            paths: const [
              ['Canale A', 'Automatico'],
              ['Canale A', 'Player 2'],
              ['Canale B', 'Automatico'],
              ['Canale B', 'Player 4'],
            ],
            labels: const ['', '', '', ''],
            onPick: (i) => picked = i,
          ),
        ),
      ),
    ));
    // Aperto il gruppo della prima sorgente; l'altro chiuso.
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('Player 4'), findsNothing);
    await t.tap(find.text('Canale B'));
    await t.pump();
    expect(find.text('Player 4'), findsOneWidget);
    expect(find.text('Player 2'), findsNothing);
    await t.tap(find.text('Player 4'));
    expect(picked, 3);
  });
}
