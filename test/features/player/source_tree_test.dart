import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/source_tree.dart';

void main() {
  final paths = [
    ['Canale A', 'Automatico'],
    ['Canale A', 'Player 2'],
    ['Canale B', 'Automatico'],
    ['Canale B', 'Player 4'],
  ];
  final labels = [
    'Canale A · Automatico',
    'Canale A · Player 2',
    'Canale B · Automatico',
    'Canale B · Player 4',
  ];

  test('tutto aperto: intestazioni e sorgenti rientrate', () {
    final rows = sourceRows(paths, labels);
    expect(rows.map((r) => r.toString()).toList(), [
      '▸ Canale A (2)',
      '  Automatico #0',
      '  Player 2 #1',
      '▸ Canale B (2)',
      '  Automatico #2',
      '  Player 4 #3',
    ]);
  });

  test('solo il gruppo aperto mostra le sue sorgenti', () {
    final rows = sourceRows(paths, labels, open: ['Canale B']);
    expect(rows.map((r) => r.toString()).toList(), [
      '▸ Canale A (2)',
      '▸ Canale B (2)',
      '  Automatico #2',
      '  Player 4 #3',
    ]);
    expect(groupOf(paths, 3), ['Canale B']);
  });

  test('un livello solo: lista piatta con i nomi brevi', () {
    final rows = sourceRows([
      ['Automatico'],
      ['Player 2']
    ], [
      'Automatico',
      'Player 2'
    ], open: const []);
    expect(rows.map((r) => r.toString()).toList(),
        ['Automatico #0', 'Player 2 #1']);
    expect(hasSourceGroups([
      ['Automatico']
    ]), isFalse);
  });

  test('senza path: le etichette di sempre', () {
    final rows = sourceRows(const [], ['A', ''], open: const []);
    expect(rows.map((r) => r.toString()).toList(), ['A #0', 'Sorgente 2 #1']);
  });

  test('profondità diverse e gruppi annidati', () {
    final p = [
      ['Lega', 'Canale A', 'Player 1'],
      ['Lega', 'Canale A', 'Player 2'],
      ['Lega', 'Canale B', 'Player 1'],
      ['Extra'],
    ];
    final l = List.filled(4, '');
    expect(sourceRows(p, l, open: ['Lega', 'Canale B']).map((r) => '$r').toList(), [
      '▸ Lega (3)',
      '  ▸ Canale A (2)',
      '  ▸ Canale B (1)',
      '    Player 1 #2',
      'Extra #3',
    ]);
    expect(sourceRows(p, l, open: const []).map((r) => '$r').toList(),
        ['▸ Lega (3)', 'Extra #3']);
    expect(sourceTitle(p, l, 1), 'Lega · Canale A · Player 2');
  });
}
