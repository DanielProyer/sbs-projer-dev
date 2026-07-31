import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz_faellig.dart';

void main() {
  final heute = DateTime(2026, 8, 1);

  group('einsatzGehoertZuTag', () {
    test('fuer diesen Tag geplant -> sichtbar', () {
      expect(
        einsatzGehoertZuTag(geplantAm: DateTime(2026, 8, 1), tag: heute),
        isTrue,
      );
    });

    test('fuer morgen geplant -> heute NICHT sichtbar', () {
      expect(
        einsatzGehoertZuTag(geplantAm: DateTime(2026, 8, 2), tag: heute),
        isFalse,
      );
    });

    test('ohne Plandatum -> immer sichtbar (Rueckstand)', () {
      // Ein ungeplanter Einsatz darf nie verschwinden — sonst vergisst
      // Daniel ihn. Er ist genau das, was noch eingeplant werden muss.
      expect(einsatzGehoertZuTag(geplantAm: null, tag: heute), isTrue);
    });

    test('Termin liegt in der Vergangenheit -> bleibt sichtbar', () {
      // Verpasst ist nicht erledigt: Ein Einsatz, der letzte Woche geplant
      // war und nicht gemacht wurde, muss weiter auftauchen.
      expect(
        einsatzGehoertZuTag(geplantAm: DateTime(2026, 7, 20), tag: heute),
        isTrue,
      );
    });

    test('Uhrzeit im Plandatum stoert nicht', () {
      expect(
        einsatzGehoertZuTag(
          geplantAm: DateTime(2026, 8, 1, 14, 30),
          tag: DateTime(2026, 8, 1, 6, 0),
        ),
        isTrue,
      );
    });

    test('Jahreswechsel wird korrekt behandelt', () {
      expect(
        einsatzGehoertZuTag(
          geplantAm: DateTime(2027, 1, 1),
          tag: DateTime(2026, 12, 31),
        ),
        isFalse,
      );
      expect(
        einsatzGehoertZuTag(
          geplantAm: DateTime(2026, 12, 31),
          tag: DateTime(2027, 1, 1),
        ),
        isTrue,
      );
    });
  });

  group('einsatzIstUeberfaellig', () {
    test('Plandatum vor heute -> ueberfaellig', () {
      expect(
        einsatzIstUeberfaellig(geplantAm: DateTime(2026, 7, 20), heute: heute),
        isTrue,
      );
    });

    test('heute geplant -> nicht ueberfaellig', () {
      expect(
        einsatzIstUeberfaellig(geplantAm: DateTime(2026, 8, 1), heute: heute),
        isFalse,
      );
    });

    test('ohne Plandatum -> nicht ueberfaellig, nur ungeplant', () {
      expect(einsatzIstUeberfaellig(geplantAm: null, heute: heute), isFalse);
    });
  });

  group('planungsText', () {
    test('mit Uhrzeit -> Datum und Zeit', () {
      expect(
        planungsText(geplantAm: DateTime(2026, 8, 1), geplantZeit: '14:00'),
        '01.08. 14:00',
      );
    });

    test('ohne Uhrzeit -> ganztaegig', () {
      expect(
        planungsText(geplantAm: DateTime(2026, 8, 1), geplantZeit: null),
        '01.08. ganztägig',
      );
    });

    test('ohne Plandatum -> nicht eingeplant', () {
      expect(planungsText(geplantAm: null, geplantZeit: null), 'nicht geplant');
    });
  });
}
