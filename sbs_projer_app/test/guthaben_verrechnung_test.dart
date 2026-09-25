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

  group('guthabenWirdVerrechnet', () {
    test('ohne Guthaben nie', () {
      expect(guthabenWirdVerrechnet(zahlung: 10, summeZuZahlen: 10, summeGuthaben: 0),
          isFalse);
    });
    test('Zahlung bis zu zahlen + 0.05', () {
      expect(
          guthabenWirdVerrechnet(
              zahlung: 113.80, summeZuZahlen: 113.75, summeGuthaben: 30),
          isTrue);
      expect(
          guthabenWirdVerrechnet(
              zahlung: 113.85, summeZuZahlen: 113.75, summeGuthaben: 30),
          isFalse);
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
