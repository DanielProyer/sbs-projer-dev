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
    test('nur Morgen', () {
      expect(servicezeitText('08:00', '12:00', null, null), '08:00–12:00');
    });
    test('nur Nachmittag', () {
      expect(servicezeitText(null, null, '13:30', '17:00'), '13:30–17:00');
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
}
