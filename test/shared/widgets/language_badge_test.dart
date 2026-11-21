import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/shared/widgets/language_badge.dart';

void main() {
  test('what each plugin value shows', () {
    expect(languageBadge('ita')!.label, 'ITA');
    expect(languageBadge('jap')!.label, 'JAP');
    expect(languageBadge('eng')!.label, 'ENG');
    expect(languageBadge('chn')!.label, 'CHN');
    expect(languageBadge('kor')!.label, 'KOR');
    expect(languageBadge('eng', subs: 'ita')!.label, 'ENG · SUB ITA');
    // Both versions, or nothing known: no badge.
    expect(languageBadge('both'), isNull);
    expect(languageBadge(''), isNull);
    expect(languageBadge('xyz'), isNull);
  });

  List<String> labels(String lang, {String subs = ''}) =>
      [for (final b in languageBadges(lang, subs: subs)) b.label];

  test('several languages, each its own colour, in order', () {
    expect(labels('ita,jap, chn'), ['ITA', 'JAP', 'CHN']);
    expect(labels('jap'), ['JAP']);
    expect(labels('both'), isEmpty);
    final colours = {
      for (final b in languageBadges('ita,jap,chn,kor,eng')) b.color
    };
    expect(colours, hasLength(5));
  });

  test('unknown and repeated values are skipped; at most five', () {
    expect(labels('ITA,xyz,ita,both'), ['ITA']);
    expect(labels('ita,jap,chn,kor,eng,ita'), hasLength(kMaxLanguageBadges));
  });
}
