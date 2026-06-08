import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_regel.dart';
import 'package:sbs_projer_app/services/camt/regel_matcher.dart';

CamtRegel _r(String mn, String vid, {int prio = 0, String? iban}) =>
    CamtRegel(bezeichnung: mn, matchName: mn, matchIban: iban,
        buchungsVorlageId: vid, prioritaet: prio);

void main() {
  test('Name-Substring trifft (case-insensitive, auch in Zusatzinfo)', () {
    final vid = RegelMatcher.matchVorlageId(
      partyName: 'Swisscom (Schweiz) AG', additionalInfo: null,
      regeln: [_r('swisscom', 'V1')]);
    expect(vid, 'V1');
  });
  test('Treffer in additionalInfo wenn Name leer', () {
    final vid = RegelMatcher.matchVorlageId(
      partyName: null, additionalInfo: 'Abschluss',
      regeln: [_r('abschluss', 'V2')]);
    expect(vid, 'V2');
  });
  test('IBAN-Treffer', () {
    final vid = RegelMatcher.matchVorlageId(
      partyName: 'X', partyIban: 'CH123', additionalInfo: null,
      regeln: [_r('zzz', 'V3', iban: 'CH123')]);
    expect(vid, 'V3');
  });
  test('Kein Treffer → null', () {
    final vid = RegelMatcher.matchVorlageId(
      partyName: 'Unbekannt AG', additionalInfo: null,
      regeln: [_r('swisscom', 'V1')]);
    expect(vid, isNull);
  });
  test('Höhere Priorität gewinnt bei zwei Treffern', () {
    final vid = RegelMatcher.matchVorlageId(
      partyName: 'AXA Stiftung Berufliche Vorsorge', additionalInfo: null,
      regeln: [_r('axa', 'LOW', prio: 1), _r('axa stiftung', 'HIGH', prio: 20)]);
    expect(vid, 'HIGH');
  });
}
