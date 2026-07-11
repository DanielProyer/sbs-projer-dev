import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/erinnerung_util.dart';
import 'package:sbs_projer_app/data/models/termin_erinnerung.dart';

void main() {
  group('minutenLabel', () {
    test('0 → Zum Zeitpunkt', () => expect(minutenLabel(0), 'Zum Zeitpunkt'));
    test('10 Min', () => expect(minutenLabel(10), '10 Min. vorher'));
    test('60 → 1 Std', () => expect(minutenLabel(60), '1 Std. vorher'));
    test('120 → 2 Std', () => expect(minutenLabel(120), '2 Std. vorher'));
    test('1440 → 1 Tag', () => expect(minutenLabel(1440), '1 Tag vorher'));
    test('2880 → 2 Tage', () => expect(minutenLabel(2880), '2 Tage vorher'));
    test('90 bleibt Minuten', () => expect(minutenLabel(90), '90 Min. vorher'));
  });

  group('parseErinnerungen', () {
    test('aus Liste von Maps', () {
      final r = parseErinnerungen([
        {'methode': 'email', 'minuten': 60},
        {'methode': 'popup', 'minuten': 1440},
      ]);
      expect(r.length, 2);
      expect(r[0].methode, 'email');
      expect(r[0].minuten, 60);
      expect(r[1].methode, 'popup');
    });
    test('aus JSON-String', () {
      final r = parseErinnerungen('[{"methode":"popup","minuten":30}]');
      expect(r.single.minuten, 30);
    });
    test('leerer String → leer', () => expect(parseErinnerungen(''), isEmpty));
    test('null → leer', () => expect(parseErinnerungen(null), isEmpty));
    test('unbekannte Methode → popup', () {
      expect(parseErinnerungen([{'methode': 'x', 'minuten': 5}]).single.methode,
          'popup');
    });
    test('max 5', () {
      final r = parseErinnerungen(
          List.generate(8, (i) => {'methode': 'popup', 'minuten': i}));
      expect(r.length, 5);
    });
    test('negative/ungültige Minuten gefiltert', () {
      expect(parseErinnerungen([{'methode': 'popup'}]), isEmpty);
    });
  });

  group('erinnerungenToJson', () {
    test('round-trip', () {
      const list = [
        TerminErinnerung(methode: 'email', minuten: 60),
        TerminErinnerung(methode: 'popup', minuten: 0),
      ];
      final json = erinnerungenToJson(list);
      final back = parseErinnerungen(json);
      expect(back.length, 2);
      expect(back[0].methode, 'email');
      expect(back[1].minuten, 0);
    });
    test('kappt auf 5', () {
      final list = List.generate(
          7, (i) => TerminErinnerung(methode: 'popup', minuten: i));
      expect(parseErinnerungen(erinnerungenToJson(list)).length, 5);
    });
  });
}
