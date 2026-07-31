import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/ferien_frage.dart';

void main() {
  group('ferienFrageZeigen', () {
    test('nie bestaetigt -> true', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: null,
          ruhtBis: null,
          heute: DateTime(2026, 7, 31),
        ),
        isTrue,
      );
    });

    test('vor 3 Monaten bestaetigt -> false', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: DateTime(2026, 5, 1),
          ruhtBis: null,
          heute: DateTime(2026, 7, 31),
        ),
        isFalse,
      );
    });

    test('vor ueber 12 Monaten bestaetigt -> true', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: DateTime(2025, 7, 1),
          ruhtBis: null,
          heute: DateTime(2026, 7, 31),
        ),
        isTrue,
      );
    });

    test('ruhtBis in der Zukunft -> false, unabhaengig vom Rest', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: DateTime(2026, 8, 20),
          ruhtBis: DateTime(2026, 8, 20),
          heute: DateTime(2026, 7, 31),
        ),
        isFalse,
      );
    });

    // Randfaelle

    test('exakt 12 Monate zurueck -> true (Grenze zaehlt schon)', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: DateTime(2025, 7, 31),
          ruhtBis: null,
          heute: DateTime(2026, 7, 31),
        ),
        isTrue,
      );
    });

    test('einen Tag vor der 12-Monats-Grenze -> false', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: DateTime(2025, 8, 1),
          ruhtBis: null,
          heute: DateTime(2026, 7, 31),
        ),
        isFalse,
      );
    });

    test('ruhtBis genau heute -> false', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: null,
          ruhtBis: DateTime(2026, 7, 31),
          heute: DateTime(2026, 7, 31),
        ),
        isFalse,
      );
    });

    test('ruhtBis liegt in der Vergangenheit -> zaehlt nicht mehr, '
        'Frage erscheint wieder wenn bestaetigtAm faellig ist', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: DateTime(2025, 7, 1),
          ruhtBis: DateTime(2026, 1, 1),
          heute: DateTime(2026, 7, 31),
        ),
        isTrue,
      );
    });

    test('ruhtBis liegt in der Vergangenheit und bestaetigtAm ist noch frisch '
        '-> false', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: DateTime(2026, 5, 1),
          ruhtBis: DateTime(2026, 1, 1),
          heute: DateTime(2026, 7, 31),
        ),
        isFalse,
      );
    });

    test('beide Werte gesetzt: ruhtBis in Zukunft gewinnt, obwohl bestaetigtAm '
        'faellig waere', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: DateTime(2024, 1, 1),
          ruhtBis: DateTime(2026, 8, 1),
          heute: DateTime(2026, 7, 31),
        ),
        isFalse,
      );
    });

    test('Uhrzeit im heute-Zeitpunkt verschiebt die Grenze nicht', () {
      expect(
        ferienFrageZeigen(
          bestaetigtAm: DateTime(2025, 7, 31),
          ruhtBis: null,
          heute: DateTime(2026, 7, 31, 23, 59),
        ),
        isTrue,
      );
    });
  });
}
