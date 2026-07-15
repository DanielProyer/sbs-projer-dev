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
  test('IBAN mit Leerzeichen/Kleinschreibung trifft trotzdem', () {
    // Auf Rechnungen steht die IBAN gruppiert („CH04 3000 0001 …"), im camt
    // kompakt. Ohne Normalisierung würde die Regel nie greifen.
    final vid = RegelMatcher.matchVorlageId(
      partyName: 'Gemeinde Flims',
      partyIban: 'CH0430000001700007355',
      additionalInfo: null,
      regeln: [_r('zzz', 'V4', iban: 'ch04 3000 0001 7000 0735 5')]);
    expect(vid, 'V4');
  });
  test('andere IBAN trifft nicht', () {
    final vid = RegelMatcher.matchVorlageId(
      partyName: 'Gemeinde Flims',
      partyIban: 'CH0430000001700007355',
      additionalInfo: null,
      regeln: [_r('zzz', 'V5', iban: 'CH8830154001085747001')]);
    expect(vid, isNull);
  });
  test('Regel-IBAN gesetzt, Transaktion ohne IBAN → kein Treffer', () {
    final vid = RegelMatcher.matchVorlageId(
      partyName: 'Gemeinde Flims',
      partyIban: null,
      additionalInfo: null,
      regeln: [_r('zzz', 'V6', iban: 'CH0430000001700007355')]);
    expect(vid, isNull);
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
