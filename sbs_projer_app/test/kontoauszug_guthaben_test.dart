import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/pdf/kontoauszug_pdf_service.dart';

/// Kontoauszug mit verrechnetem Kundenguthaben (v0.137.0): Die Rechnung
/// steht mit vollem Brutto im Soll, das Guthaben als eigene Haben-Zeile —
/// sonst sähe der Kunde 30.00 offen, die er längst bezahlt hat.
void main() {
  Rechnung rg(String id, double brutto,
          {double guthaben = 0,
          String status = 'offen',
          double? zahlung,
          DateTime? zahlungAm}) =>
      Rechnung(
        id: id,
        userId: 'u1',
        rechnungsnummer: id,
        rechnungstyp: 'kundenrechnung',
        betriebId: 'b1',
        rechnungsdatum: DateTime(2026, 11, 20),
        faelligkeitsdatum: DateTime(2026, 12, 20),
        betragBrutto: brutto,
        zahlungsstatus: status,
        guthabenVerrechnet: guthaben,
        zahlungBetrag: zahlung,
        zahlungEingegangenAm: zahlungAm,
      );

  test('offen mit Guthaben: Haben-Zeile «Verrechnung Guthaben», Saldo = zu zahlen', () {
    final a = KontoauszugPdfService.auszugZeilen([rg('R1', 143.75, guthaben: 30)]);
    expect(a.zeilen.map((z) => z.vorgang), ['Rechnung', 'Verrechnung Guthaben']);
    expect(a.zeilen[1].haben, 30);
    expect(a.offen, closeTo(113.75, 0.001));
  });

  test('bezahlt mit Guthaben: Saldo 0', () {
    final a = KontoauszugPdfService.auszugZeilen([
      rg('R1', 143.75,
          guthaben: 30,
          status: 'bezahlt',
          zahlung: 113.75,
          zahlungAm: DateTime(2026, 12, 1)),
    ]);
    expect(a.zeilen.map((z) => z.vorgang),
        ['Rechnung', 'Verrechnung Guthaben', 'Zahlung']);
    expect(a.offen, closeTo(0, 0.001));
  });

  test('bezahlt ohne vermerkten Betrag: Zahlung = zu zahlen', () {
    final a = KontoauszugPdfService.auszugZeilen(
        [rg('R1', 143.75, guthaben: 30, status: 'bezahlt')]);
    expect(a.offen, closeTo(0, 0.001));
  });

  test('ohne Guthaben unverändert', () {
    final a = KontoauszugPdfService.auszugZeilen([rg('R1', 94.05)]);
    expect(a.zeilen.map((z) => z.vorgang), ['Rechnung']);
    expect(a.offen, closeTo(94.05, 0.001));
  });
}
