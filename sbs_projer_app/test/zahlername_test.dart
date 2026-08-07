import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';

void main() {
  test('nutzt partyName wenn vorhanden', () {
    expect(effektiverZahlername(partyName: 'Hotel X', additionalInfo: 'Gutschrift Y'), 'Hotel X');
  });
  test('extrahiert aus "Gutschrift <Name>"', () {
    expect(effektiverZahlername(partyName: null, additionalInfo: 'Gutschrift Gastro Latina GmbH'),
        'Gastro Latina GmbH');
  });
  test('null wenn nichts brauchbar', () {
    expect(effektiverZahlername(partyName: null, additionalInfo: 'Saldovortrag'), isNull);
  });
  test('Platzhalter "Schaltereinzahlung" zählt nicht als Name — Rohtext greift', () {
    // GKB setzt bei Schaltereinzahlungen den Zahlernamen wörtlich auf
    // «Schaltereinzahlung»; der echte Name steht im AddtlNtryInf.
    expect(
        effektiverZahlername(
            partyName: 'Schaltereinzahlung',
            additionalInfo: 'Gutschrift Nuriman Mustafi'),
        'Nuriman Mustafi');
    expect(
        effektiverZahlername(
            partyName: 'SCHALTEREINZAHLUNG ',
            additionalInfo: 'Gutschrift Sunset Bar'),
        'Sunset Bar');
  });
  test('Platzhalter ohne brauchbaren Rohtext → null (Rohtext wird angezeigt)', () {
    expect(
        effektiverZahlername(
            partyName: 'Schaltereinzahlung', additionalInfo: 'Einzahlung Bern'),
        isNull);
    expect(
        effektiverZahlername(partyName: 'Schaltereinzahlung', additionalInfo: null),
        isNull);
  });
  test('zahlernameNorm: trim, lowercase, Mehrfach-Whitespace', () {
    expect(zahlernameNorm('  Hotel   Alpina AG '), 'hotel alpina ag');
    expect(zahlernameNorm('GASTRO\tLatina'), 'gastro latina');
    expect(zahlernameNorm(''), '');
  });
}
