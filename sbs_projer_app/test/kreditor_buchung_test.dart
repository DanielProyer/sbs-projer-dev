import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/kreditor_buchung.dart';

void main() {
  test('MwSt-pflichtig: Aufwand brutto an 2000 + Vorsteuer-Korrektur (8.1%)', () {
    final r = kreditorBuchungsZeilen(brutto: 108.10, mwstSatz: 8.1, aufwandskonto: 6301, vorsteuerKonto: 1170, beschreibung: 'Heineken');
    expect(r.length, 2);
    expect(r[0].sollKonto, 6301); expect(r[0].habenKonto, 2000);
    expect(r[0].betragBrutto, 108.10); expect(r[0].betragNetto, 100.00); expect(r[0].mwstBetrag, 8.10);
    expect(r[0].mwstKonto, 1170);
    expect(r[1].sollKonto, 1170); expect(r[1].habenKonto, 6301); expect(r[1].betragBrutto, 8.10);
    expect(r[1].mwstKonto, null);
  });
  test('MwSt-frei: nur Aufwand brutto an 2000', () {
    final r = kreditorBuchungsZeilen(brutto: 40.00, mwstSatz: 0, aufwandskonto: 6275, vorsteuerKonto: null, beschreibung: 'Fahrbewilligung');
    expect(r.length, 1);
    expect(r[0].sollKonto, 6275); expect(r[0].habenKonto, 2000); expect(r[0].betragBrutto, 40.00);
    expect(r[0].mwstKonto, null);
  });
}
