// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/clients/media_client.dart' show LogoMeta;
import 'package:pileus/core/perf_profile.dart';
import 'package:pileus/core/theme/app_theme.dart';
import 'package:pileus/core/widgets/smart_logo.dart';

LogoMeta _meta({
  String halo = '',
  double lumMid = 0.3,
  double lightShare = 0.1,
  double coverage = 0.5,
  int width = 600,
  int height = 200,
}) =>
    LogoMeta(
        width: width,
        height: height,
        halo: halo,
        lumMid: lumMid,
        lightShare: lightShare,
        coverage: coverage);

void main() {
  // The tints the widget asked for: one per halo copy, null = the sharp logo.
  Future<List<Color?>> pump(
    WidgetTester tester, {
    String url = 'https://x/logo.png',
    LogoMeta? meta,
    double? background,
  }) async {
    final tints = <Color?>[];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SmartLogo(
        url: url,
        meta: meta,
        maxWidth: 300,
        maxHeight: 100,
        backgroundLuminance: background ?? kDarkBackgroundLuminance,
        fallback: const SizedBox.shrink(),
        debugImage: (tint) {
          tints.add(tint);
          return const SizedBox(width: 300, height: 100);
        },
      ),
    ));
    return tints;
  }

  tearDown(() => lowPowerUi = false);

  testWidgets('halo "light" on a dark background: blurred light copy',
      (tester) async {
    final tints = await pump(tester, meta: _meta(halo: 'light'));
    expect(tints, hasLength(2));
    expect(tints.first!.toARGB32() & 0xFFFFFF,
        AppTheme.textHigh.toARGB32() & 0xFFFFFF);
    expect(tints.last, isNull);
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byType(RepaintBoundary), findsWidgets);
  });

  testWidgets('no halo asked for: just the logo', (tester) async {
    final tints = await pump(tester, meta: _meta());
    expect(tints, [null]);
    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('light background: dark halo only for a light logo',
      (tester) async {
    var tints = await pump(tester, meta: _meta(lumMid: 0.8), background: 0.9);
    expect(tints, hasLength(2));
    expect(tints.first!.toARGB32() & 0xFFFFFF, 0);

    tints = await pump(tester, meta: _meta(lightShare: 0.35), background: 0.9);
    expect(tints, hasLength(2));

    // halo "light" is advice for dark backgrounds only.
    tints = await pump(tester,
        meta: _meta(halo: 'light', lumMid: 0.2), background: 0.9);
    expect(tints, [null]);
  });

  testWidgets('no logo_meta: the legacy dark flag decides', (tester) async {
    const dark = 'https://x/logo.png|800|200|1';
    var tints = await pump(tester, url: dark);
    expect(tints, hasLength(2));

    tints = await pump(tester, url: dark, meta: LogoMeta()); // unset proto
    expect(tints, hasLength(2));

    tints = await pump(tester, url: 'https://x/logo.png|800|200|0');
    expect(tints, [null]);

    tints = await pump(tester, url: 'https://x/logo.png');
    expect(tints, [null]);
  });

  testWidgets('low power: outline of shifted copies, no blur', (tester) async {
    lowPowerUi = true;
    var tints = await pump(tester, meta: _meta(halo: 'light'));
    expect(tints.where((t) => t != null), hasLength(4));
    expect(find.byType(ImageFiltered), findsNothing);

    // Thin strokes: a fuller outline.
    tints = await pump(tester, meta: _meta(halo: 'light', coverage: 0.1));
    expect(tints.where((t) => t != null), hasLength(8));
  });

  test('thin strokes make the halo stronger', () {
    expect(logoHaloFor('u', _meta(halo: 'light', coverage: 0.1)).strong, isTrue);
    expect(logoHaloFor('u', _meta(halo: 'light')).strong, isFalse);
  });

  test('size: measured ratio, then the legacy one, then 3:1', () {
    const box = (maxWidth: 300.0, maxHeight: 100.0);
    final measured = logoDisplaySize('u|800|800|0', _meta(width: 600, height: 150),
        maxWidth: box.maxWidth, maxHeight: box.maxHeight);
    expect((measured.w, measured.h), (300.0, 75.0));
    final legacy = logoDisplaySize('u|800|400|0', null,
        maxWidth: box.maxWidth, maxHeight: box.maxHeight);
    expect((legacy.w, legacy.h), (200.0, 100.0));
    final none = logoDisplaySize('u', LogoMeta(),
        maxWidth: box.maxWidth, maxHeight: box.maxHeight);
    expect((none.w, none.h), (300.0, 100.0));
  });

  test('the URL drops the legacy suffix', () {
    expect(logoUrlOnly('https://x/a.png|800|200|1'), 'https://x/a.png');
    expect(logoUrlOnly('https://x/a.png'), 'https://x/a.png');
  });
}
