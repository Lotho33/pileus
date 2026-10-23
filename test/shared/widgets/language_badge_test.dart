import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/shared/widgets/language_badge.dart';

void main() {
  test('what each plugin value shows', () {
    expect(languageBadge('ita')!.label, 'ITA');
    expect(languageBadge('jap')!.label, 'JAP');
    expect(languageBadge('eng')!.label, 'ENG');
    expect(languageBadge('eng', subs: 'ita')!.label, 'ENG · SUB ITA');
    // Both versions, or nothing known: no badge.
    expect(languageBadge('both'), isNull);
    expect(languageBadge(''), isNull);
    expect(languageBadge('xyz'), isNull);
  });
}
