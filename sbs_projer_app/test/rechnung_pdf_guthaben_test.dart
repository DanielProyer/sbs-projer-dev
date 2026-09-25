import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/models/rechnungs_position.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_service.dart';

Rechnung _rechnung({double guthaben = 0}) => Rechnung(
  id: 'r1',
  userId: 'u1',
  rechnungsnummer: '2026-11-28-0513',
  rechnungstyp: 'kundenrechnung',
  betriebId: 'b1',
  rechnungsdatum: DateTime(2026, 11, 28),
  faelligkeitsdatum: DateTime(2026, 12, 28),
  betragNetto: 132.95,
  mwstBetrag: 10.80,
  betragBrutto: 143.75,
  guthabenVerrechnet: guthaben,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('summenZeilen', () {
    test('ohne Guthaben: Netto, MwSt, Total — keine Zu-zahlen-Zeile', () {
      final zeilen = RechnungPdfService.summenZeilen(_rechnung());
      expect(zeilen.map((z) => z.label).toList(), [
        'Netto',
        'MwSt 8.1%',
        'Total CHF',
      ]);
      expect(zeilen.last.betrag, 143.75);
      expect(zeilen.last.fett, isTrue);
    });

    test('mit Guthaben 30: Abzug und fett «Zu zahlen» 113.75', () {
      final zeilen = RechnungPdfService.summenZeilen(_rechnung(guthaben: 30));
      expect(zeilen.map((z) => z.label).toList(), [
        'Netto',
        'MwSt 8.1%',
        'Total CHF',
        'abzüglich Kundenguthaben',
        'Zu zahlen CHF',
      ]);
      expect(zeilen[3].betrag, -30.0);
      expect(zeilen[3].fett, isFalse);
      expect(zeilen[4].betrag, 113.75);
      expect(zeilen[4].fett, isTrue);
      expect(zeilen[4].linieDavor, isTrue);
    });

    test('QR-Betrag = zu zahlen, auf 5 Rappen', () {
      expect(RechnungPdfService.qrBetrag(_rechnung()), 143.75);
      expect(RechnungPdfService.qrBetrag(_rechnung(guthaben: 30)), 113.75);
    });
  });

  test('PDF mit Guthaben wird erzeugt (Smoke)', () async {
    final betrieb = BetriebLocal()
      ..serverId = 'b1'
      ..name = 'Chesa'
      ..strasse = 'Promenade'
      ..nr = '1'
      ..plz = '7270'
      ..ort = 'Davos Platz';
    final bytes = await RechnungPdfService.generate(
      rechnung: _rechnung(guthaben: 30),
      positionen: [
        RechnungsPosition(
          id: 'p1',
          userId: 'u1',
          rechnungId: 'r1',
          position: 1,
          beschreibung: 'Reinigung',
          betragNetto: 132.95,
          mwstBetrag: 10.80,
          betragBrutto: 143.75,
        ),
      ],
      betrieb: betrieb,
    );
    expect(bytes.length, greaterThan(1000));
  });
}
