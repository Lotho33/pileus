import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/player/cw_progress.dart';

void main() {
  test('device label loses quotes the server already added', () {
    expect(bareDeviceLabel('«TV salotto»'), 'TV salotto');
    expect(bareDeviceLabel(' "TV" '), 'TV');
    expect(bareDeviceLabel('TV salotto'), 'TV salotto');
    expect(bareDeviceLabel(''), '');
  });
}
