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
      expect(servicezeitText('08:00', '12:00', '13:30', '17:00'),
          '08:00–12:00 · 13:30–17:00');
    });
    test('nur Morgen → Nachmittag ausdrücklich kein Service', () {
      expect(servicezeitText('08:00', '12:00', null, null),
          '08:00–12:00 · nachmittags kein Service');
    });
    test('nur Nachmittag → Morgen ausdrücklich kein Service', () {
      expect(servicezeitText(null, null, '13:30', '17:00'),
          '13:30–17:00 · morgens kein Service');
    });
    test('Fall Conditorei Fischer', () {
      expect(servicezeitText('06:30', '11:00', null, null),
          '06:30–11:00 · nachmittags kein Service');
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
