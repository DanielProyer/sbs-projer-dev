import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/rechnungsadresse_zeilen.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/services/pdf/qr_zahlteil.dart';

/// Die IBAN kommt seit Runde 4 aus GeschaeftEinstellungen. Ohne DB-Zeile
/// muss exakt herauskommen, was vorher fest im Code stand.
void main() {
  const fallback = GeschaeftEinstellungen();

  group('IBAN-Getter', () {
    test('Rückfall liefert die bisherigen Strings', () {
      expect(fallback.ibanFormatiert, 'CH66 0077 4010 3765 5060 1');
      expect(fallback.ibanKompakt, 'CH6600774010376550601');
    });

    test('firmenIban mit und ohne Leerzeichen wird normalisiert', () {
      const kompakt = GeschaeftEinstellungen(firmenIban: 'CH6600774010376550601');
      const gruppiert =
          GeschaeftEinstellungen(firmenIban: ' ch66 0077 4010 3765 5060 1 ');
      for (final g in [kompakt, gruppiert]) {
        expect(g.ibanKompakt, 'CH6600774010376550601');
        expect(g.ibanFormatiert, 'CH66 0077 4010 3765 5060 1');
      }
    });

    test('eine andere gültige IBAN aus der DB gilt', () {
      // Beispiel-IBAN der SIX-Dokumentation (gültige Prüfziffer).
      const g = GeschaeftEinstellungen(firmenIban: 'CH93 0076 2011 6238 5295 7');
      expect(g.ibanKompakt, 'CH9300762011623852957');
      expect(g.ibanFormatiert, 'CH93 0076 2011 6238 5295 7');
    });

    test('leer oder vertippt fällt auf die feste IBAN zurück', () {
      for (final roh in ['', '   ', 'CH66 0077 4010 3765 5060 2', 'DE89370400440532013000']) {
        final g = GeschaeftEinstellungen(firmenIban: roh);
        expect(g.ibanKompakt, 'CH6600774010376550601', reason: roh);
      }
    });
  });

  group('QR-Zahlteil mit Rückfall', () {
    final kreditor = QrKreditor.aus(fallback);

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

    test('QR-Daten tragen IBAN und Empfänger an der Norm-Position', () {
      final daten = QrZahlteil.qrDaten(
        150.25,
        const QrEmpfaenger(
          name: 'Muster AG',
          strasse: 'Hauptstrasse',
          nr: '1',
          plz: '7000',
          ort: 'Chur',
        ),
        kreditor,
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
    });
  });
}
