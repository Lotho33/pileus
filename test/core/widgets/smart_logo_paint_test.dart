import 'dart:ui' as ui;

// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/clients/media_client.dart' show LogoMeta;
import 'package:pileus/core/perf_profile.dart';
import 'package:pileus/core/widgets/smart_logo.dart';

// A black block on transparency: a dark wordmark.
Future<ui.Image> _blackLogo() {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(const Rect.fromLTWH(40, 20, 120, 40),
      Paint()..color = const Color(0xFF000000));
  return rec.endRecording().toImage(200, 80);
}

void main() {
  Future<int> brightnessBesideLogo(WidgetTester tester, ui.Image logo) async {
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF101010),
            child: SizedBox(
              width: 200,
              height: 80,
              child: SmartLogo(
                url: 'https://x/logo.png',
                meta: LogoMeta(
                    width: 200, height: 80, halo: 'light', coverage: 0.3),
                maxWidth: 200,
                maxHeight: 80,
                fallback: const SizedBox.shrink(),
                debugImage: (tint) => RawImage(
                    image: logo,
                    width: 200,
                    height: 80,
                    color: tint,
                    colorBlendMode: tint == null ? null : BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    ));
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = (await tester.runAsync(() async {
      final img = await boundary.toImage();
      return img.toByteData(format: ui.ImageByteFormat.rawRgba);
    }))!;
    // The pixel just left of the block, mid height.
    final red = bytes.buffer.asUint8List(bytes.offsetInBytes)[(40 * 200 + 39) * 4];
    return red;
  }

  tearDown(() => lowPowerUi = false);

  testWidgets('a black logo really gets light pixels around it',
      (tester) async {
    final logo = (await tester.runAsync(_blackLogo))!;
    final normal = await brightnessBesideLogo(tester, logo);
    lowPowerUi = true;
    final outline = await brightnessBesideLogo(tester, logo);
    expect(normal, greaterThan(0x30));
    expect(outline, greaterThan(0x30));
  });
}
