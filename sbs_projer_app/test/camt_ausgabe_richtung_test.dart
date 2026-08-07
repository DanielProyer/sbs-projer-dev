import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/services/camt/camt_ausgabe_booker.dart';

BuchungsVorlage _vorlage({String art = 'fix', int? hauptkonto, int? soll, int? haben, int? mwstKonto}) =>
    BuchungsVorlage(
      id: 'v1', userId: 'u1', geschaeftsfallId: 'g1', bezeichnung: 'Test',
      art: art, hauptkonto: hauptkonto, sollKonto: soll, habenKonto: haben,
      mwstKonto: mwstKonto,
    );

void main() {
  group('kontenFuerCamt — Geschäftsfall-Vorlagen auflösen', () {
    test('fix-Vorlage: Konten direkt', () {
      final k = kontenFuerCamt(_vorlage(art: 'fix', soll: 6200, haben: 1020, mwstKonto: 1171));
      expect(k.sollKonto, 6200);
      expect(k.habenKonto, 1020);
      expect(k.mwstKonto, 1171);
    });

    test('ausgabe-Vorlage (Phase 0a, Konten NULL): hauptkonto an Bank', () {
      // Fall «Bussen» (6280) / «Fahrbewilligung» (6275): soll/haben sind NULL,
      // das Konto steht in hauptkonto — camt zahlt immer über die Bank.
      final k = kontenFuerCamt(_vorlage(art: 'ausgabe', hauptkonto: 6280));
      expect(k.sollKonto, 6280);
      expect(k.habenKonto, 1020);
    });

    test('einnahme-Vorlage: Bank an hauptkonto', () {
      final k = kontenFuerCamt(_vorlage(art: 'einnahme', hauptkonto: 3400));
      expect(k.sollKonto, 1020);
      expect(k.habenKonto, 3400);
    });
  });

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

    test('Gutschrift auf Einzahlungs-Vorlage (Bank schon im Soll): NICHT tauschen',
        () {
      // Doppel-Tausch-Bug 07.08.2026: «Bargeldeinzahlung» ist als 1020 an 1000
      // definiert — der pauschale Gutschrift-Tausch machte daraus «Kasse an
      // Bank» (2 Automaten-Einzahlungen, 8'050.00, von Hand korrigiert).
      final f = ausgabeBuchungsFelder(
          betrag: 5300.00, isCredit: true, mwstSatz: 0,
          vorlageSoll: 1020, vorlageHaben: 1000);
      expect(f['soll_konto'], 1020);
      expect(f['haben_konto'], 1000);
      expect(f['betrag_brutto'], 5300.00);
    });

    test('kontenWerdenGetauscht: nur Gutschrift auf Nicht-Einzahlungs-Vorlage', () {
      expect(kontenWerdenGetauscht(isCredit: true, vorlageSoll: 6200), isTrue);
      expect(kontenWerdenGetauscht(isCredit: true, vorlageSoll: 1020), isFalse);
      expect(kontenWerdenGetauscht(isCredit: false, vorlageSoll: 6200), isFalse);
      expect(kontenWerdenGetauscht(isCredit: false, vorlageSoll: 1020), isFalse);
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
