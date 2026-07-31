import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/saison_jahr.dart';

void main() {
  group('saisonFenster — normales Fenster (kein Jahreswechsel)', () {
    test('Sommerfenster 15.6.–20.10. bei heute=31.07.2026', () {
      final f = saisonFenster(
        vonTag: 15,
        vonMonat: 6,
        bisTag: 20,
        bisMonat: 10,
        heute: DateTime(2026, 7, 31),
      );
      expect(f.von, DateTime(2026, 6, 15));
      expect(f.bis, DateTime(2026, 10, 20));
    });
  });

  group('saisonFenster — Fenster über den Jahreswechsel', () {
    test(
      'Winterfenster 1.12.–1.4. bei heute=31.07.2026 (Fenster liegt voraus)',
      () {
        final f = saisonFenster(
          vonTag: 1,
          vonMonat: 12,
          bisTag: 1,
          bisMonat: 4,
          heute: DateTime(2026, 7, 31),
        );
        expect(f.von, DateTime(2026, 12, 1));
        expect(f.bis, DateTime(2027, 4, 1));
      },
    );

    test(
      'Winterfenster 1.12.–1.4. bei heute=10.02.2027 (heute steckt bereits im Fenster)',
      () {
        final f = saisonFenster(
          vonTag: 1,
          vonMonat: 12,
          bisTag: 1,
          bisMonat: 4,
          heute: DateTime(2027, 2, 10),
        );
        // Der Start darf NICHT ins nächste Jahr rutschen — heute liegt zwischen
        // 01.12.2026 und 01.04.2027, also bleibt das Fenster genau dort.
        expect(f.von, DateTime(2026, 12, 1));
        expect(f.bis, DateTime(2027, 4, 1));
      },
    );

    test(
      'Winterfenster 1.12.–1.4.: Randtag genau am Fensterende (heute=01.04.2027)',
      () {
        final f = saisonFenster(
          vonTag: 1,
          vonMonat: 12,
          bisTag: 1,
          bisMonat: 4,
          heute: DateTime(2027, 4, 1),
        );
        expect(f.von, DateTime(2026, 12, 1));
        expect(f.bis, DateTime(2027, 4, 1));
      },
    );

    test(
      'Winterfenster 1.12.–1.4.: kurz nach Fensterende springt es aufs nächste Jahr',
      () {
        final f = saisonFenster(
          vonTag: 1,
          vonMonat: 12,
          bisTag: 1,
          bisMonat: 4,
          heute: DateTime(2027, 4, 2),
        );
        expect(f.von, DateTime(2027, 12, 1));
        expect(f.bis, DateTime(2028, 4, 1));
      },
    );
  });

  group('saisonFenster — Randfälle', () {
    test('gleicher Tag für von und bis: volles Jahresfenster', () {
      final f = saisonFenster(
        vonTag: 15,
        vonMonat: 6,
        bisTag: 15,
        bisMonat: 6,
        heute: DateTime(2026, 7, 31),
      );
      expect(f.von, DateTime(2026, 6, 15));
      expect(f.bis, DateTime(2027, 6, 15));
    });

    test(
      '29. Februar bei einem Nicht-Schaltjahr: Dart normalisiert auf 1. März',
      () {
        // 2027 ist kein Schaltjahr (Februar hat nur 28 Tage). DateTime(2027, 2, 29)
        // rollt automatisch auf DateTime(2027, 3, 1) — das ist Standard-Dart-Verhalten
        // und wird hier bewusst mitgetestet, damit es niemand als Bug hält.
        final f = saisonFenster(
          vonTag: 29,
          vonMonat: 2,
          bisTag: 31,
          bisMonat: 10,
          heute: DateTime(2027, 7, 1),
        );
        expect(f.von, DateTime(2027, 3, 1));
        expect(f.bis, DateTime(2027, 10, 31));
      },
    );
  });

  group('jahreszahlenRichten', () {
    test('bis vor von: bis wird ein Jahr nach vorne verschoben', () {
      final f = jahreszahlenRichten(
        von: DateTime(2026, 12, 1),
        bis: DateTime(2026, 4, 1),
      );
      expect(f.von, DateTime(2026, 12, 1));
      expect(f.bis, DateTime(2027, 4, 1));
    });

    test('bis nach von: bleibt unverändert', () {
      final f = jahreszahlenRichten(
        von: DateTime(2026, 6, 15),
        bis: DateTime(2026, 10, 20),
      );
      expect(f.von, DateTime(2026, 6, 15));
      expect(f.bis, DateTime(2026, 10, 20));
    });

    test(
      'von und bis am gleichen Tag: gilt nicht als "davor", bleibt unverändert',
      () {
        final f = jahreszahlenRichten(
          von: DateTime(2026, 6, 15),
          bis: DateTime(2026, 6, 15),
        );
        expect(f.von, DateTime(2026, 6, 15));
        expect(f.bis, DateTime(2026, 6, 15));
      },
    );

    test('bis bereits im Folgejahr: bleibt unverändert', () {
      final f = jahreszahlenRichten(
        von: DateTime(2026, 12, 1),
        bis: DateTime(2027, 4, 1),
      );
      expect(f.von, DateTime(2026, 12, 1));
      expect(f.bis, DateTime(2027, 4, 1));
    });
  });
}
