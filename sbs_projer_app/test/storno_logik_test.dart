import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';

Buchung _buchung({
  String id = 'b1',
  DateTime? datum,
  int soll = 1100,
  int haben = 3400,
  int? mwstKonto = 2200,
  double netto = 100.0,
  double mwst = 8.10,
  double brutto = 108.10,
  String? belegTyp = 'rechnung',
  String? belegId = 'beleg-1',
  bool istStorniert = false,
  String? stornoVonId,
}) =>
    Buchung(
      id: id,
      userId: 'u1',
      datum: datum ?? DateTime(2026, 4, 30),
      belegnummer: '2026-05-0630',
      sollKonto: soll,
      habenKonto: haben,
      mwstKonto: mwstKonto,
      betragNetto: netto,
      mwstSatz: 8.1,
      mwstBetrag: mwst,
      betragBrutto: brutto,
      beschreibung: 'Heineken Monatsrechnung 04/2026',
      belegTyp: belegTyp,
      belegId: belegId,
      geschaeftsjahr: 2026,
      istStorniert: istStorniert,
      stornoVonId: stornoVonId,
    );

void main() {
  group('gegenbuchungFuer', () {
    test('datiert aufs Original — nicht auf heute (B6.2)', () {
      final g = gegenbuchungFuer(_buchung(datum: DateTime(2025, 12, 31)));
      expect(g['datum'], '2025-12-31');
      expect(g['geschaeftsjahr'], 2025);
    });

    test('tauscht Soll/Haben und traegt KEIN mwst_konto (B6.1)', () {
      final g = gegenbuchungFuer(_buchung(soll: 1100, haben: 3400));
      expect(g['soll_konto'], 3400);
      expect(g['haben_konto'], 1100);
      expect(g['mwst_konto'], isNull);
      expect(g['storno_von_id'], 'b1');
      expect(g['betrag_brutto'], 108.10);
    });

    test('SaldoExpansion-Invariante: Gegenbuchung ohne mwst_konto braucht netto = brutto', () {
      // Ohne mwst_konto bucht die Expansion nur brutto — netto/mwst der
      // Gegenbuchung muessen dazu konsistent sein (brutto = netto + mwst).
      final g = gegenbuchungFuer(_buchung());
      expect(g['betrag_netto'] + g['mwst_betrag'], closeTo(g['betrag_brutto'], 0.004));
    });
  });

  group('istZugehoerigeTrennbuchung', () {
    final haupt = _buchung();

    test('erkennt die MwSt-Trennbuchung desselben Belegs am selben Tag (B6.3)', () {
      final trenn = _buchung(
          id: 'b2', soll: 3400, haben: 2200, mwstKonto: null,
          netto: 8.10, mwst: 0, brutto: 8.10, belegTyp: 'mwst');
      expect(istZugehoerigeTrennbuchung(original: haupt, kandidat: trenn), isTrue);
    });

    test('ignoriert Zahlungen, fremde Belege, stornierte und Gegenbuchungen', () {
      final zahlung = _buchung(id: 'b3', belegTyp: 'zahlung');
      final fremd = _buchung(id: 'b4', belegTyp: 'mwst', belegId: 'anderer');
      final storniert = _buchung(id: 'b5', belegTyp: 'mwst', istStorniert: true);
      final gegen = _buchung(id: 'b6', belegTyp: 'mwst', stornoVonId: 'x');
      final andererTag =
          _buchung(id: 'b7', belegTyp: 'mwst', datum: DateTime(2026, 5, 1));
      for (final k in [zahlung, fremd, storniert, gegen, andererTag]) {
        expect(istZugehoerigeTrennbuchung(original: haupt, kandidat: k), isFalse,
            reason: k.id);
      }
    });

    test('eine Trennbuchung zieht nicht sich selbst oder weitere Trennbuchungen nach', () {
      final trennA = _buchung(id: 'b2', belegTyp: 'mwst');
      final trennB = _buchung(id: 'b8', belegTyp: 'mwst');
      expect(istZugehoerigeTrennbuchung(original: trennA, kandidat: trennB), isFalse);
      expect(istZugehoerigeTrennbuchung(original: trennA, kandidat: trennA), isFalse);
    });
  });

  group('zaehltFuerSaldo', () {
    test('Original zaehlt, storniertes Original und Gegenbuchung nicht', () {
      expect(zaehltFuerSaldo(istStorniert: false, stornoVonId: null), isTrue);
      expect(zaehltFuerSaldo(istStorniert: true, stornoVonId: null), isFalse);
      expect(zaehltFuerSaldo(istStorniert: false, stornoVonId: 'x'), isFalse);
    });
  });
}
