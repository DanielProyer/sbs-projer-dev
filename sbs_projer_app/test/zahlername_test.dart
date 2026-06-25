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
  test('zahlernameNorm: trim, lowercase, Mehrfach-Whitespace', () {
    expect(zahlernameNorm('  Hotel   Alpina AG '), 'hotel alpina ag');
    expect(zahlernameNorm('GASTRO\tLatina'), 'gastro latina');
    expect(zahlernameNorm(''), '');
  });
}
