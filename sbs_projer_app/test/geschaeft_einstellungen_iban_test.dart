import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/rechnungsadresse_zeilen.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/services/pdf/qr_zahlteil.dart';

/// Zahlungsdaten (IBAN, QR-Zahlungsempfänger) sind bewusst Konstanten und
/// kommen nie aus der DB-Zeile — eine geänderte Einstellung darf Kundengeld
/// nicht auf ein anderes Konto lenken (Entscheid Runde 4, 26.09.2026).
void main() {
  group('Feste Zahlungsdaten', () {
    test('liefern exakt die bisherigen Strings', () {
      expect(GeschaeftEinstellungen.zahlungsIbanFormatiert,
          'CH66 0077 4010 3765 5060 1');
      expect(GeschaeftEinstellungen.zahlungsIbanKompakt,
          'CH6600774010376550601');
      expect(GeschaeftEinstellungen.zahlungsEmpfaengerName, 'SBS Projer GmbH');
      expect(GeschaeftEinstellungen.zahlungsEmpfaengerStrasse,
          ('Via Rezia', '8'));
      expect(GeschaeftEinstellungen.zahlungsEmpfaengerPlzOrt,
          ('7013', 'Domat/Ems'));
    });
  });

  group('QR-Zahlteil', () {
    final kreditor = QrKreditor.fest();

    test('Empfängerdaten wie die früheren Konstanten', () {
      expect(kreditor.iban, 'CH6600774010376550601');
      expect(kreditor.ibanFormatiert, 'CH66 0077 4010 3765 5060 1');
      expect(kreditor.name, 'SBS Projer GmbH');
      expect(kreditor.strasse, 'Via Rezia');
      expect(kreditor.nr, '8');
      expect(kreditor.plz, '7013');
      expect(kreditor.ort, 'Domat/Ems');
      expect(kreditor.land, 'CH');
    });

    test('QR-Daten tragen die feste IBAN — auch bei abweichender '
        'Einstellung in der DB', () {
      // Eine andere (gültige) IBAN und Adresse in der Einstellungs-Zeile darf
      // den Zahlteil nicht beeinflussen.
      const abweichend = GeschaeftEinstellungen(
        firmaName: 'Andere GmbH',
        strasse: 'Bahnhofstrasse 1',
        plzOrt: '8000 Zürich',
        firmenIban: 'CH93 0076 2011 6238 5295 7',
      );
      expect(abweichend.firma, 'Andere GmbH'); // Briefkopf darf abweichen
      final daten = QrZahlteil.qrDaten(
        150.25,
        const QrEmpfaenger(
          name: 'Muster AG',
          strasse: 'Hauptstrasse',
          nr: '1',
          plz: '7000',
          ort: 'Chur',
        ),
        QrKreditor.fest(),
        mitteilung: 'Rechnung 2026-09-26-0001',
      );
      final zeilen = daten.split('\n');
      // SPC-Header: SPC, 0200, 1, dann IBAN; danach Kreditor (Typ S).
      expect(zeilen.sublist(0, 11), [
        'SPC',
        '0200',
        '1',
        'CH6600774010376550601',
        'S',
        'SBS Projer GmbH',
        'Via Rezia',
        '8',
        '7013',
        'Domat/Ems',
        'CH',
      ]);
      expect(daten.contains('CH9300762011623852957'), isFalse);
    });
  });
}
