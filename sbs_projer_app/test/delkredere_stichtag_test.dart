import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/abschluss_belegnummer.dart';
import 'package:sbs_projer_app/core/util/delkredere.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschreibung_service.dart';

/// Delkredere im Jahresabschluss (Schritt E) per 31.12. — bis 29.09.2026
/// buchte der Knopf der Abschlussprüfung gegen den HEUTIGEN Debitorensaldo
/// und mit heutigem Datum; für den Abschluss eines Vorjahres die falsche
/// Basis und die falsche Periode.

var _id = 0;

Buchung _b(int soll, int haben, double betrag, DateTime datum) => Buchung(
  id: 'b${_id++}',
  userId: 'u',
  datum: datum,
  sollKonto: soll,
  habenKonto: haben,
  betragNetto: betrag,
  betragBrutto: betrag,
  beschreibung: 'Test',
  geschaeftsjahr: datum.year,
);

void main() {
  group('delkredereZiel / delkredereBuchung', () {
    test('5 % auf Rappen; ohne Debitoren 0', () {
      expect(delkredereZiel(105351.96), 5267.60);
      expect(delkredereZiel(0), 0);
      expect(delkredereZiel(-100), 0);
    });

    test('Abbau 2025 nach Jahrgang 2020: 5\'629.38 → 5\'267.60 = 361.78 '
        '(1109 an 3805)', () {
      // docs/buchhaltung/jahresabschluss-2025.md Abschnitt 9c.
      final b = delkredereBuchung(debitoren: 105351.96, bisher: 5629.38);
      expect(b.betrag, 361.78);
      expect(b.aufbau, isFalse);
    });

    test('Aufbau: 3805 an 1109', () {
      final b = delkredereBuchung(debitoren: 10000, bisher: 300);
      expect(b.betrag, 200);
      expect(b.aufbau, isTrue);
    });

    test('schon auf 5 % → nichts zu buchen', () {
      expect(delkredereBuchung(debitoren: 10000, bisher: 500).betrag, 0);
    });
  });

  test(
    'delkredereStichtag: Saldi per 31.12., Spätere Buchungen zählen nicht',
    () {
      final journal = [
        _b(1100, 3400, 110000, DateTime(2025, 5, 1)),
        _b(1020, 1100, 4648.04, DateTime(2025, 11, 30)), // Zahlung
        _b(3805, 1109, 5629.38, DateTime(2025, 12, 31)),
        // 2026: Zahlungseingang und neue Rechnung — gehören nicht zum 31.12.
        _b(1020, 1100, 30000, DateTime(2026, 2, 1)),
        _b(1100, 3400, 999, DateTime(2026, 1, 1)),
      ];
      final s = delkredereStichtag(journal, 2025);
      expect(s.debitoren, 105351.96);
      expect(s.wertberichtigung, 5629.38);
      expect(s.ziel, 5267.60);
    },
  );

  group('AbschreibungService.delkredereStichtagBuchung', () {
    test('Abbau per 31.12.: 1109 an 3805, JA-Belegnummer, abschluss', () {
      final z = AbschreibungService.delkredereStichtagBuchung(
        jahr: 2025,
        debitoren: 105351.96,
        bisher: 5629.38,
        belegnummer: 'JA2025_E2',
      )!;
      expect(z['datum'], '2025-12-31');
      expect(z['belegnummer'], 'JA2025_E2');
      expect(z['soll_konto'], 1109);
      expect(z['haben_konto'], 3805);
      expect(z['betrag_brutto'], 361.78);
      expect(z['betrag_netto'], 361.78);
      expect(z['mwst_betrag'], 0);
      expect(z['beleg_typ'], 'abschluss');
      expect(z['zahlungsweg'], 'intern');
      expect(z['geschaeftsjahr'], 2025);
      expect(
        z['beschreibung'],
        "Delkredere auf 5 % von 105'351.96 = 5'267.60 per 31.12.2025",
      );
      expect(z['notizen'], 'Jahresabschluss 2025 Schritt E (App)');
    });

    test('Aufbau: 3805 an 1109; null ohne Differenz', () {
      final z = AbschreibungService.delkredereStichtagBuchung(
        jahr: 2026,
        debitoren: 100000,
        bisher: 0,
        belegnummer: 'JA2026_E',
      )!;
      expect(z['soll_konto'], 3805);
      expect(z['haben_konto'], 1109);
      expect(z['betrag_brutto'], 5000);
      expect(
        AbschreibungService.delkredereStichtagBuchung(
          jahr: 2026,
          debitoren: 100000,
          bisher: 5000,
          belegnummer: 'JA2026_E2',
        ),
        isNull,
      );
    });
  });

  group('naechsteAbschlussBelegnummer', () {
    test('erste Buchung trägt die Basis', () {
      expect(naechsteAbschlussBelegnummer('JA2025_E', const []), 'JA2025_E');
      expect(abschlussBelegBasis(2025, 'E'), 'JA2025_E');
    });

    test('Nachführungen zählen hoch: _E → _E2 → _E3', () {
      expect(
        naechsteAbschlussBelegnummer('JA2025_E', ['JA2025_E']),
        'JA2025_E2',
      );
      expect(
        naechsteAbschlussBelegnummer('JA2025_E', ['JA2025_E2', 'JA2025_E']),
        'JA2025_E3',
      );
    });

    test('Umbuchungen JA2025_D_U1/U2 sind keine Nachführung', () {
      expect(
        naechsteAbschlussBelegnummer('JA2025_D', [
          'JA2025_D',
          'JA2025_D_U1',
          'JA2025_D_U2',
          null,
        ]),
        'JA2025_D2',
      );
    });

    test('LIKE-Beifang (anderes Zeichen statt «_») zählt nicht', () {
      expect(
        naechsteAbschlussBelegnummer('JA2025_E', ['JA2025XE']),
        'JA2025_E',
      );
    });

    test('eine gelöschte Nummer wird nicht wieder vergeben', () {
      // _E2 gelöscht, _E3 steht noch → _E4, nicht _E2.
      expect(
        naechsteAbschlussBelegnummer('JA2025_E', ['JA2025_E', 'JA2025_E3']),
        'JA2025_E4',
      );
    });
  });
}
