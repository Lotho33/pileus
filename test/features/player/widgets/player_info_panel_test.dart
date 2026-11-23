// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/player_info.dart';
import 'package:pileus/features/player/presentation/widgets/player_info_panel.dart';

void main() {
  final info = playerInfoBase(
    title: 'Il pilota',
    showTitle: 'Breaking Bad',
    seasonNumber: 1,
    episodeNumber: 1,
    year: 2008,
    genres: ['Drama'],
    plot: 'Walter White scopre di essere malato. ' * 20,
  ).copyWith(rows: [('Cast', 'Bryan Cranston, Aaron Paul')]);

  Future<void> pump(WidgetTester t, Size size,
      {bool tv = false, VoidCallback? onClose}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          PlayerInfoPanel(base: info, tv: tv, onClose: onClose ?? () {}),
        ]),
      ),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('TV 1080p and a phone: everything laid out, no overflow',
      (t) async {
    await pump(t, const Size(1920, 1080), tv: true);
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('S1 · E1'), findsOneWidget);
    expect(t.takeException(), isNull);
    await pump(t, const Size(844, 390));
    expect(find.text('Il pilota'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('TV: OK closes, ↓ scrolls', (t) async {
    var closed = false;
    await pump(t, const Size(1920, 1080),
        tv: true, onClose: () => closed = true);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    expect(closed, isFalse);
    await t.sendKeyEvent(LogicalKeyboardKey.select);
    expect(closed, isTrue);
  });
}
