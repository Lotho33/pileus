import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/shared/utils/tap_guard.dart';

void main() {
  test('swallows a second open inside the window, allows one after it',
      () async {
    // Let any slot taken by another test lapse first.
    await Future<void>.delayed(TapGuard.window);
    expect(TapGuard.acquire(), isTrue);
    expect(TapGuard.acquire(), isFalse, reason: 'the double tap');
    await Future<void>.delayed(
        TapGuard.window + const Duration(milliseconds: 20));
    expect(TapGuard.acquire(), isTrue);
  });
}
