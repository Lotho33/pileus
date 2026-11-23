import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/auth/presentation/profile_selection_screen.dart';

void main() {
  // Same values as pileus-vega's accentFor (ProfilesScreen.tsx).
  test('profile accent matches the Vega hash', () {
    int vega(String s) {
      var h = 0;
      for (final c in s.codeUnits) {
        h = (h * 31 + c).toSigned(32);
      }
      return h.abs() % 5;
    }

    for (final n in ['Lotho', 'Famiglia', 'test', 'anna', 'bruno', '']) {
      expect(profileAccentIndex(n, 5), vega(n), reason: n);
    }
    expect(profileAccentIndex('Lotho', 5), 3); // #26A69A on Vega
  });
}
