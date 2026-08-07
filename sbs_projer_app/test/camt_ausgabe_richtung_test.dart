import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/camt_ausgabe_booker.dart';

void main() {
  group('ausgabeBuchungsFelder — Richtung (B8-Fix)', () {
    test('Belastung: Konten wie Vorlage, MwSt-Split über mwst_konto', () {
      final f = ausgabeBuchungsFelder(
          betrag: 108.10, isCredit: false, mwstSatz: 8.1,
          vorlageSoll: 6200, vorlageHaben: 1020, vorlageMwstKonto: 1171);
      expect(f['soll_konto'], 6200);
      expect(f['haben_konto'], 1020);
      expect(f['mwst_konto'], 1171);
      expect(f['betrag_netto'], 100.00);
      expect(f['mwst_betrag'], 8.10);
      expect(f['betrag_brutto'], 108.10);
    });

    test('Gutschrift: Konten getauscht, brutto ohne MwSt-Split', () {
      // Eine Gutschrift (z. B. Prämien-Rückerstattung) auf einer
      // Ausgabe-Vorlage muss die Bank im SOLL treffen. Der Vorsteuer-Split
      // lässt sich in einer Zeile nicht invertieren (SaldoExpansion wählt
      // den Zweig nach Konto-Klasse) → brutto buchen, MwSt manuell prüfen.
      final f = ausgabeBuchungsFelder(
          betrag: 108.10, isCredit: true, mwstSatz: 8.1,
          vorlageSoll: 6200, vorlageHaben: 1020, vorlageMwstKonto: 1171);
      expect(f['soll_konto'], 1020);
      expect(f['haben_konto'], 6200);
      expect(f['mwst_konto'], isNull);
      expect(f['betrag_netto'], 108.10);
      expect(f['mwst_betrag'], 0);
      expect(f['mwst_satz'], 0);
      expect(f['betrag_brutto'], 108.10);
    });

    test('Invariante brutto = netto + mwst gilt in beiden Richtungen', () {
      for (final credit in [false, true]) {
        final f = ausgabeBuchungsFelder(
            betrag: 77.77, isCredit: credit, mwstSatz: 2.6,
            vorlageSoll: 5820, vorlageHaben: 1020, vorlageMwstKonto: 1171);
        expect(f['betrag_netto'] + f['mwst_betrag'],
            closeTo(f['betrag_brutto'], 0.004));
      }
    });
  });
}
