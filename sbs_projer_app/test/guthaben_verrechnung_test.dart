import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/guthaben_verrechnung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

Rechnung _rg(String id, double brutto, {double guthaben = 0}) => Rechnung(
      id: id,
      userId: 'u',
      rechnungsnummer: 'RG-$id',
      rechnungstyp: 'kundenrechnung',
      betriebId: 'b1',
      rechnungsdatum: DateTime(2026, 11, 20),
      faelligkeitsdatum: DateTime(2026, 12, 20),
      betragBrutto: brutto,
      zahlungsstatus: 'offen',
      guthabenVerrechnet: guthaben,
    );

Buchung _b({
  int soll = 2030,
  int haben = 1100,
  String belegTyp = 'sonstiges',
  bool storniert = false,
}) =>
    Buchung(
      id: 'x',
      userId: 'u',
      datum: DateTime(2026, 11, 20),
      sollKonto: soll,
      habenKonto: haben,
      betragNetto: 30,
      mwstSatz: 0,
      mwstBetrag: 0,
      betragBrutto: 30,
      beschreibung: 'Verrechnung Kundenguthaben',
      belegTyp: belegTyp,
      geschaeftsjahr: 2026,
      istStorniert: storniert,
    );

void main() {
  group('differenzPlan', () {
    test('ohne Guthaben, exakte Zahlung → wie bisher, keine Differenz', () {
      final p = differenzPlan([_rg('a', 143.75)], 143.75);
      expect(p.differenz, 0);
      expect(p.zeilen.single.bank, 143.75);
      expect(p.zeilen.single.verrechnung, 0);
      expect(p.guthabenVerrechnet, isFalse);
      expect(p.guthabenZuruecksetzen, isFalse);
      expect(p.hinweis, isNull);
      expect(p.gezahltFuer(p.zeilen.single.rechnung), 143.75);
    });

    test('ohne Guthaben, Minderzahlung → Bank gekürzt, Differenz negativ', () {
      final p = differenzPlan([_rg('a', 100), _rg('b', 50)], 149.50);
      expect(p.differenz, -0.5);
      expect(p.zeilen[0].bank, 100);
      expect(p.zeilen[1].bank, 49.5);
    });

    test('ohne Guthaben, Mehrzahlung → Differenz positiv, Bank = Brutto', () {
      final p = differenzPlan([_rg('a', 143.75)], 150);
      expect(p.differenz, 6.25);
      expect(p.zeilen.single.bank, 143.75);
    });

    test('Guthaben 30, Zahlung 113.75 → keine Differenz, eine Verrechnung', () {
      final p = differenzPlan([_rg('a', 143.75, guthaben: 30)], 113.75);
      expect(p.differenz, 0);
      expect(p.zeilen.single.bank, 113.75);
      expect(p.zeilen.single.verrechnung, 30);
      expect(p.guthabenVerrechnet, isTrue);
      expect(p.guthabenZuruecksetzen, isFalse);
      expect(p.summeVerrechnung, 30);
      expect(p.gezahltFuer(p.zeilen.single.rechnung), 113.75);
    });

    test('Guthaben 30, Minderzahlung 110 → Verlust 3.75 gegen zu zahlen', () {
      final p = differenzPlan([_rg('a', 143.75, guthaben: 30)], 110);
      expect(p.differenz, -3.75);
      expect(p.zeilen.single.bank, 110);
      expect(p.zeilen.single.verrechnung, 30);
    });

    test('Guthaben 30, Zahlung 113.80 (5 Rappen Toleranz) → verrechnet', () {
      final p = differenzPlan([_rg('a', 143.75, guthaben: 30)], 113.80);
      expect(p.guthabenVerrechnet, isTrue);
      expect(p.differenz, 0.05);
      expect(p.zeilen.single.verrechnung, 30);
    });

    test('Zahlung 143.75 trotz Guthaben → keine Verrechnung, Guthaben bleibt',
        () {
      final p = differenzPlan([_rg('a', 143.75, guthaben: 30)], 143.75);
      expect(p.guthabenVerrechnet, isFalse);
      expect(p.guthabenZuruecksetzen, isTrue);
      expect(p.differenz, 0);
      expect(p.zeilen.single.bank, 143.75);
      expect(p.zeilen.single.verrechnung, 0);
      expect(p.summeVerrechnung, 0);
      expect(p.hinweis, contains('30.00'));
      expect(p.gezahltFuer(p.zeilen.single.rechnung), 143.75);
    });

    test('Sammel: eine mit, eine ohne Guthaben → Verrechnung nur bei der einen',
        () {
      final p = differenzPlan(
          [_rg('a', 143.75, guthaben: 30), _rg('b', 100)], 213.75);
      expect(p.differenz, 0);
      expect(p.zeilen[0].bank, 113.75);
      expect(p.zeilen[0].verrechnung, 30);
      expect(p.zeilen[1].bank, 100);
      expect(p.zeilen[1].verrechnung, 0);
    });

    test('Rechnung ganz durch Guthaben gedeckt → Bankzeile 0', () {
      final p = differenzPlan(
          [_rg('a', 20, guthaben: 20), _rg('b', 100)], 100);
      expect(p.zeilen[0].bank, 0);
      expect(p.zeilen[0].verrechnung, 20);
      expect(p.differenz, 0);
    });
  });

  group('guthabenWirdVerrechnet (Review I1: Grenze = Brutto − 0.05)', () {
    test('ohne Guthaben nie', () {
      expect(
          guthabenWirdVerrechnet(
              zahlung: 10, summeBrutto: 10, summeGuthaben: 0),
          isFalse);
    });
    test('verrechnet, solange Zahlung < Brutto − 0.05', () {
      for (final z in [113.75, 113.85, 120.0, 143.65]) {
        expect(
            guthabenWirdVerrechnet(
                zahlung: z, summeBrutto: 143.75, summeGuthaben: 30),
            isTrue,
            reason: 'Zahlung $z');
      }
    });
    test('ab Brutto − 0.05 nicht verrechnet', () {
      for (final z in [143.70, 143.75, 150.0]) {
        expect(
            guthabenWirdVerrechnet(
                zahlung: z, summeBrutto: 143.75, summeGuthaben: 30),
            isFalse,
            reason: 'Zahlung $z');
      }
    });
  });

  group('Review I1: Zwischenbeträge', () {
    test('120 bei 143.75 / Guthaben 30 → 113.75 + 30 verrechnet + 6.25 Mehrzahlung', () {
      final p = differenzPlan([_rg('a', 143.75, guthaben: 30)], 120);
      expect(p.guthabenVerrechnet, isTrue);
      expect(p.zeilen.single.bank, 113.75);
      expect(p.zeilen.single.verrechnung, 30);
      expect(p.differenz, 6.25);
    });
    test('143.70 → nicht verrechnet, Minderzahlung 0.05, Guthaben bleibt', () {
      final p = differenzPlan([_rg('a', 143.75, guthaben: 30)], 143.70);
      expect(p.guthabenVerrechnet, isFalse);
      expect(p.guthabenZuruecksetzen, isTrue);
      expect(p.zeilen.single.verrechnung, 0);
      expect(p.zeilen.single.bank, 143.70);
      expect(p.differenz, -0.05);
      expect(p.zeilen.single.guthabenVorher, 30);
    });
    test('113.75 → verrechnet, keine Differenz', () {
      final p = differenzPlan([_rg('a', 143.75, guthaben: 30)], 113.75);
      expect(p.differenz, 0);
      expect(p.zeilen.single.verrechnung, 30);
      expect(p.zeilen.single.guthabenVorher, 0);
    });
    test('143.75 → nicht verrechnet, keine Differenz', () {
      final p = differenzPlan([_rg('a', 143.75, guthaben: 30)], 143.75);
      expect(p.differenz, 0);
      expect(p.guthabenVerrechnet, isFalse);
      expect(p.zeilen.single.bank, 143.75);
    });
  });

  group('Review I4: Kürzung von hinten verteilen', () {
    test('[a 100, b 30 mit Guthaben 30], Zahlung 95 → Bank 95', () {
      final p = differenzPlan(
          [_rg('a', 100), _rg('b', 30, guthaben: 30)], 95);
      expect(p.guthabenVerrechnet, isTrue);
      expect(p.differenz, -5);
      expect(p.zeilen[0].bank, 95);
      expect(p.zeilen[1].bank, 0);
      expect(p.zeilen[1].verrechnung, 30);
      final bank = p.zeilen.fold<double>(0, (s, z) => s + z.bank);
      expect(bank, 95);
    });
    test('Verlust grösser als die letzte Zeile → auf mehrere verteilt', () {
      final p = differenzPlan([_rg('a', 100), _rg('b', 10)], 80);
      expect(p.differenz, -30);
      expect(p.zeilen[1].bank, 0);
      expect(p.zeilen[0].bank, 80);
    });
  });

  group('Review I5: Guthaben-Stand in der Notiz', () {
    test('Notiz hin und zurück', () {
      expect(guthabenAusNotiz(guthabenNotiz(30)), 30);
    });
    test('fremde oder leere Notiz → null', () {
      expect(guthabenAusNotiz(null), isNull);
      expect(guthabenAusNotiz(''), isNull);
      expect(guthabenAusNotiz('Phase2c Abschreibung'), isNull);
      expect(guthabenAusNotiz('{"zahlungsstatus":"offen"}'), isNull);
      expect(guthabenAusNotiz('{"guthaben_verrechnet":-3}'), isNull);
    });
  });

  group('Review I2: ganz durch Guthaben gedeckt', () {
    test('zu zahlen 0 → voll gedeckt', () {
      expect(istVollMitGuthabenGedeckt(_rg('a', 20, guthaben: 20)), isTrue);
      expect(istVollMitGuthabenGedeckt(_rg('a', 20, guthaben: 10)), isFalse);
      expect(istVollMitGuthabenGedeckt(_rg('a', 20)), isFalse);
    });
  });

  group('istGuthabenVerrechnung', () {
    test('Soll 2030 / Haben 1100 / sonstiges', () {
      expect(istGuthabenVerrechnung(_b()), isTrue);
    });
    test('storniert zählt nicht', () {
      expect(istGuthabenVerrechnung(_b(storniert: true)), isFalse);
    });
    test('andere Konten oder Belegtyp nicht', () {
      expect(istGuthabenVerrechnung(_b(soll: 1020)), isFalse);
      expect(istGuthabenVerrechnung(_b(belegTyp: 'zahlung')), isFalse);
    });
  });

  group('forderungBetragText', () {
    test('ohne Guthaben: Brutto', () {
      expect(forderungBetragText(_rg('a', 143.75)), '143.75 CHF');
    });
    test('mit Guthaben: zu zahlen + Hinweis', () {
      expect(forderungBetragText(_rg('a', 143.75, guthaben: 30)),
          '113.75 CHF (nach Guthaben 30.00)');
    });
  });
}
