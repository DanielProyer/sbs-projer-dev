import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';

void main() {
  group('istRuhetag', () {
    // 2026-07-06 ist ein Montag, 2026-07-11 ein Samstag, 2026-07-12 Sonntag
    test('Montag als Ruhetag → true an einem Montag', () {
      expect(istRuhetag(['Montag'], DateTime(2026, 7, 6)), isTrue);
    });
    test('Montag als Ruhetag → false an einem Dienstag', () {
      expect(istRuhetag(['Montag'], DateTime(2026, 7, 7)), isFalse);
    });
    test('mehrere Ruhetage', () {
      expect(istRuhetag(['Montag', 'Samstag'], DateTime(2026, 7, 11)), isTrue);
    });
    test('Sonntag', () {
      expect(istRuhetag(['Sonntag'], DateTime(2026, 7, 12)), isTrue);
    });
    test('leere Liste → false', () {
      expect(istRuhetag([], DateTime(2026, 7, 6)), isFalse);
    });
    test("['keine'] → false", () {
      expect(istRuhetag(['keine'], DateTime(2026, 7, 6)), isFalse);
    });
  });

  group('ruhetageText', () {
    test('kürzt volle Namen', () {
      expect(ruhetageText(['Montag', 'Dienstag']), 'Mo, Di');
    });
    test('Sonntag', () {
      expect(ruhetageText(['Sonntag']), 'So');
    });
    test('leer → leerer String', () {
      expect(ruhetageText([]), '');
    });
    test("['keine'] → leerer String", () {
      expect(ruhetageText(['keine']), '');
    });
  });

  group('servicezeitText', () {
    test('beide Blöcke', () {
      expect(
        servicezeitText('08:00', '12:00', '13:30', '17:00'),
        '08:00–12:00 · 13:30–17:00',
      );
    });
    test('nur Morgen → Nachmittag ausdrücklich kein Service', () {
      expect(
        servicezeitText('08:00', '12:00', null, null),
        '08:00–12:00 · nachmittags kein Service',
      );
    });
    test('nur Nachmittag → Morgen ausdrücklich kein Service', () {
      expect(
        servicezeitText(null, null, '13:30', '17:00'),
        '13:30–17:00 · morgens kein Service',
      );
    });
    test('Fall Conditorei Fischer', () {
      expect(
        servicezeitText('06:30', '11:00', null, null),
        '06:30–11:00 · nachmittags kein Service',
      );
    });
    test('leere Strings zählen als nicht gesetzt', () {
      expect(servicezeitText('', '', '', ''), '');
    });
    test('alles null → leerer String', () {
      expect(servicezeitText(null, null, null, null), '');
    });
    test('halber Block (nur Ab) → ignoriert', () {
      expect(servicezeitText('08:00', null, null, null), '');
    });
  });

  group('servicezeitErfasst', () {
    test('ein voller Block genügt', () {
      expect(servicezeitErfasst('06:30', '11:00', null, null), isTrue);
      expect(servicezeitErfasst(null, null, '13:30', '17:00'), isTrue);
    });
    test('gar nichts erfasst', () {
      expect(servicezeitErfasst(null, null, null, null), isFalse);
      expect(servicezeitErfasst('', '', '', ''), isFalse);
    });
    test('halber Block zählt nicht als erfasst', () {
      expect(servicezeitErfasst('06:30', null, null, null), isFalse);
    });
  });

  group('liegtInServicefenster (Zeitachse, Spec 2026-07-29)', () {
    // Betrieb mit zwei Fenstern: 08:00–12:00 und 13:30–17:00.
    const mAb = '08:00', mBis = '12:00', nAb = '13:30', nBis = '17:00';

    test('Ankunft in beiden Fenstern → true', () {
      expect(liegtInServicefenster(9 * 60, mAb, mBis, nAb, nBis), isTrue);
      expect(liegtInServicefenster(14 * 60, mAb, mBis, nAb, nBis), isTrue);
    });
    test('Ankunft zwischen den Fenstern → false', () {
      expect(
        liegtInServicefenster(12 * 60 + 30, mAb, mBis, nAb, nBis),
        isFalse,
      );
    });
    test('Ankunft vor dem ersten Fenster → false', () {
      expect(liegtInServicefenster(7 * 60, mAb, mBis, nAb, nBis), isFalse);
    });
    test('Ankunft nach dem letzten Fenster → false', () {
      expect(liegtInServicefenster(18 * 60, mAb, mBis, nAb, nBis), isFalse);
    });
    test('kein (vollständiges) Fenster erfasst → true', () {
      expect(liegtInServicefenster(3 * 60, null, null, null, null), isTrue);
      // Halbes Fenster zählt nicht — gleiche Regel wie servicezeitText.
      expect(liegtInServicefenster(3 * 60, '08:00', null, null, null), isTrue);
    });
  });

  group('besuchAusserhalbServicezeit (Ankunft–Ende, Spec §4)', () {
    const mAb = '08:00', mBis = '12:00', nAb = '13:30', nBis = '17:00';

    test('Besuch komplett im Fenster → kein Konflikt', () {
      expect(
        besuchAusserhalbServicezeit(9 * 60, 10 * 60, mAb, mBis, nAb, nBis),
        isFalse,
      );
    });
    test('startet im Fenster, läuft hinaus → Konflikt', () {
      // 11:45 ist noch drin, 12:30 nicht mehr.
      expect(
        besuchAusserhalbServicezeit(
          11 * 60 + 45,
          12 * 60 + 30,
          mAb,
          mBis,
          nAb,
          nBis,
        ),
        isTrue,
      );
    });
    test('Ankunft ausserhalb → Konflikt', () {
      expect(
        besuchAusserhalbServicezeit(7 * 60, 9 * 60, mAb, mBis, nAb, nBis),
        isTrue,
      );
    });
    test('ohne erfasste Fenster nie ein Konflikt', () {
      expect(
        besuchAusserhalbServicezeit(3 * 60, 5 * 60, null, null, null, null),
        isFalse,
      );
    });
  });

  group('naechsterFensterStart', () {
    const mAb = '08:00', mBis = '12:00', nAb = '13:30', nBis = '17:00';

    test('vor dem Morgenfenster → Morgenbeginn', () {
      expect(naechsterFensterStart(7 * 60, mAb, mBis, nAb, nBis), 8 * 60);
    });
    test('zwischen den Fenstern → Nachmittagsbeginn', () {
      expect(
        naechsterFensterStart(12 * 60 + 30, mAb, mBis, nAb, nBis),
        13 * 60 + 30,
      );
    });
    test('nach dem letzten Fenster → null', () {
      expect(naechsterFensterStart(18 * 60, mAb, mBis, nAb, nBis), isNull);
    });
  });

  group('minutenAusHhmm / hhmmAusMinuten', () {
    test('Hin- und Rückweg', () {
      expect(minutenAusHhmm('06:20'), 6 * 60 + 20);
      expect(hhmmAusMinuten(6 * 60 + 20), '06:20');
    });
    test('ungültige Eingaben → null', () {
      expect(minutenAusHhmm(null), isNull);
      expect(minutenAusHhmm(''), isNull);
      expect(minutenAusHhmm('25:00'), isNull);
    });
  });

  group('Ruhetage als Kürzel (so stehen sie in der Datenbank)', () {
    test('Kürzel werden erkannt', () {
      // 06.07.2026 ist ein Montag, 12.07. ein Sonntag.
      expect(istRuhetag(['Mo'], DateTime(2026, 7, 6)), isTrue);
      expect(istRuhetag(['So'], DateTime(2026, 7, 12)), isTrue);
      expect(istRuhetag(['Mo'], DateTime(2026, 7, 7)), isFalse);
    });
    test('Fall Conditorei Fischer: Ruhetag Sonntag', () {
      expect(istRuhetag(['So'], DateTime(2026, 7, 26)), isTrue);
      expect(istRuhetag(['So'], DateTime(2026, 7, 27)), isFalse);
    });
    test('Kürzel und volle Namen gemischt', () {
      expect(istRuhetag(['Mo', 'Samstag'], DateTime(2026, 7, 11)), isTrue);
      expect(istRuhetag(['Montag', 'Sa'], DateTime(2026, 7, 6)), isTrue);
    });
    test('Anzeige liefert Kürzel in Wochentagsreihenfolge', () {
      expect(ruhetageText(['Mo', 'Di']), 'Mo, Di');
      expect(ruhetageText(['So', 'Mo']), 'Mo, So');
      expect(ruhetageText(['Sonntag', 'Mo']), 'Mo, So');
    });
    test('keine/Unbekanntes wird ignoriert', () {
      expect(ruhetageText(['keine']), '');
      expect(ruhetageText(['Ruhetag']), '');
      expect(istRuhetag(['keine'], DateTime(2026, 7, 6)), isFalse);
    });
  });
}
