import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnfall_regeln.dart';
import 'package:sbs_projer_app/data/models/mahnfall.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Reine Anzeige-Regeln des Mahnfalls (Task 6): Status-Text (gemeinsam für
/// Mahnlauf, Mahnverlauf und Fall-Screen) und Zinsbeginn im Datenblatt.
void main() {
  Mahnfall fall(String status, {DateTime? fristBis, String? erledigung}) => Mahnfall(
        id: 'f1',
        userId: 'u',
        betriebId: 'b',
        rechnungIds: const ['r1'],
        eroeffnetAm: DateTime.utc(2026, 10, 1),
        status: status,
        test: true,
        heinekenFristBis: fristBis,
        erledigung: erledigung,
        erstelltAm: DateTime.utc(2026, 10, 1),
        aktualisiertAm: DateTime.utc(2026, 10, 1),
      );

  Rechnung r(String id, DateTime datum, {DateTime? erinnerung}) => Rechnung(
        id: id,
        userId: 'u',
        rechnungsnummer: 'RE-$id',
        rechnungstyp: 'kundenrechnung',
        rechnungsdatum: datum,
        faelligkeitsdatum: datum.add(const Duration(days: 30)),
        betragBrutto: 100,
        zahlungsstatus: 'mahnung_2',
        mahnungStufe: 3,
        erinnerungAm: erinnerung,
      );

  group('mahnfallStatusText', () {
    test('je Status', () {
      expect(mahnfallStatusText(fall('heineken')), 'Bei Heineken');
      expect(mahnfallStatusText(fall('heineken_frist', fristBis: DateTime.utc(2026, 11, 3))),
          'Kunde zahlt bis 03.11.2026');
      expect(mahnfallStatusText(fall('heineken_frist')), 'Kunde zahlt bis …');
      expect(mahnfallStatusText(fall('betreibung')), 'Betreibung');
    });

    test('erledigt nennt die Erledigung', () {
      expect(mahnfallStatusText(fall('erledigt', erledigung: 'bezahlt')), 'Erledigt: bezahlt');
      expect(mahnfallStatusText(fall('erledigt', erledigung: 'uebernommen')),
          'Erledigt: Heineken übernimmt');
      expect(mahnfallStatusText(fall('erledigt')), 'Erledigt');
    });
  });

  group('zinsZeile (M-1: je Rechnung)', () {
    test('mit Erinnerung dieser Rechnung', () {
      expect(zinsZeile(r('a', DateTime.utc(2026, 3, 1), erinnerung: DateTime.utc(2026, 5, 2))),
          'nebst 5 % Zins seit 02.05.2026');
    });
    test('ohne Erinnerung ein Hinweis', () {
      expect(zinsZeile(r('a', DateTime.utc(2026, 3, 1))), contains('nicht vermerkt'));
    });
  });

  group('sperrtRechnungen (I-3)', () {
    test('offene Fälle sperren', () {
      expect(sperrtRechnungen(fall('heineken')), isTrue);
      expect(sperrtRechnungen(fall('betreibung')), isTrue);
    });
    test('übernommen / zurückgezogen sperren weiter', () {
      expect(sperrtRechnungen(fall('erledigt', erledigung: 'uebernommen')), isTrue);
      expect(sperrtRechnungen(fall('erledigt', erledigung: 'zurueckgezogen')), isTrue);
    });
    test('bezahlt / abgeschrieben geben frei', () {
      expect(sperrtRechnungen(fall('erledigt', erledigung: 'bezahlt')), isFalse);
      expect(sperrtRechnungen(fall('erledigt', erledigung: 'abgeschrieben')), isFalse);
    });
  });

  group('kontoauszugJahre (I-5)', () {
    test('ein Jahr', () {
      expect(kontoauszugJahre([r('a', DateTime.utc(2026, 3, 1)), r('b', DateTime.utc(2026, 7, 1))]),
          [2026]);
    });
    test('über den Jahreswechsel: je Jahr aufsteigend', () {
      expect(
        kontoauszugJahre([r('b', DateTime.utc(2026, 1, 5)), r('a', DateTime.utc(2025, 11, 3))]),
        [2025, 2026],
      );
    });
  });
}
