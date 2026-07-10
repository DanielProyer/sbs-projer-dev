import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/swiss_qr_bill.dart';

void main() {
  group('swissQrPayload', () {
    List<String> lines(String p) => p.split('\n');

    test('Grundstruktur: 31 Zeilen, Header/Trailer, IBAN, Creditor', () {
      final p = swissQrPayload(
        iban: 'CH6600774010376550601',
        creditorName: 'SBS Projer GmbH',
        creditorStreet: 'Via Rezia',
        creditorNr: '8',
        creditorPlz: '7013',
        creditorOrt: 'Domat/Ems',
        betrag: 120.5,
      );
      final l = lines(p);
      expect(l.length, 31);
      expect(l[0], 'SPC');
      expect(l[1], '0200');
      expect(l[2], '1');
      expect(l[3], 'CH6600774010376550601');
      expect(l[4], 'S');
      expect(l[5], 'SBS Projer GmbH');
      expect(l[18], '120.50'); // Betrag
      expect(l[19], 'CHF');
      expect(l.last, 'EPD');
    });

    test('Betrag null/<=0 -> leere Betragszeile (offen)', () {
      final p = swissQrPayload(
        iban: 'CH00', creditorName: 'X', creditorStreet: 'Y', creditorNr: '1',
        creditorPlz: '1000', creditorOrt: 'Z', betrag: null,
      );
      expect(lines(p)[18], '');
    });

    test('kein Debitor -> leerer Address-Type + leeres Land; Referenztyp NON', () {
      final l = lines(swissQrPayload(
        iban: 'CH00', creditorName: 'X', creditorStreet: 'Y', creditorNr: '1',
        creditorPlz: '1000', creditorOrt: 'Z', betrag: 10,
      ));
      expect(l[20], ''); // Debtor Address Type
      expect(l[26], ''); // Debtor Country
      expect(l[27], 'NON'); // Reference Type
    });

    test('mit Debitor + Referenz + Mitteilung', () {
      final l = lines(swissQrPayload(
        iban: 'CH00', creditorName: 'X', creditorStreet: 'Y', creditorNr: '1',
        creditorPlz: '1000', creditorOrt: 'Z', betrag: 10,
        debtorName: 'Bar Sonne', debtorStreet: 'Weg', debtorNr: '2',
        debtorPlz: '7000', debtorOrt: 'Chur',
        referenz: 'RF12', mitteilung: 'Reinigung',
      ));
      expect(l[20], 'S');
      expect(l[21], 'Bar Sonne');
      expect(l[26], 'CH'); // Debtor Country = creditorLand
      expect(l[27], 'SCOR');
      expect(l[28], 'RF12');
      expect(l[29], 'Reinigung');
    });

    test('Mitteilung > 140 Zeichen wird gekürzt', () {
      final lang = 'x' * 200;
      final l = lines(swissQrPayload(
        iban: 'CH00', creditorName: 'X', creditorStreet: 'Y', creditorNr: '1',
        creditorPlz: '1000', creditorOrt: 'Z', betrag: 10, mitteilung: lang,
      ));
      expect(l[29].length, 140);
    });
  });
}
