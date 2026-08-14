import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/event_technik.dart';

void main() {
  group('vergleicheLeitungsNummern', () {
    test('numerisch: 2 vor 10 (lexikographisch wäre 10 zuerst)', () {
      final l = ['10', '2', '1', '12'];
      l.sort(vergleicheLeitungsNummern);
      expect(l, ['1', '2', '10', '12']);
    });
    test('gemischt: Zahl vor Text, Suffix lexikographisch', () {
      final l = ['7b', '7a', 'B3', '7'];
      l.sort(vergleicheLeitungsNummern);
      expect(l, ['7', '7a', '7b', 'B3']);
    });
    test('reiner Text: lexikographischer Vergleich', () {
      final l = ['B3', 'A2'];
      l.sort(vergleicheLeitungsNummern);
      expect(l, ['A2', 'B3']);
    });
    test('>19-stellige Zahl wirft nicht, wird als Text behandelt', () {
      final l = ['99999999999999999999', '2'];
      l.sort(vergleicheLeitungsNummern);
      expect(l, ['2', '99999999999999999999']);
    });
  });

  group('leitungsNummernBereich', () {
    test('einfacher Bereich 1–4', () {
      expect(leitungsNummernBereich(1, 4), ['1', '2', '3', '4']);
    });
    test('umgekehrte Eingabe wird getauscht', () {
      expect(leitungsNummernBereich(4, 1), ['1', '2', '3', '4']);
    });
    test('bestehende Nummern werden übersprungen', () {
      expect(
        leitungsNummernBereich(1, 4, bestehend: {'2', '3'}),
        ['1', '4'],
      );
    });
    test('alle vorhanden → leer', () {
      expect(leitungsNummernBereich(1, 2, bestehend: {'1', '2'}), isEmpty);
    });
    test('Bereich über 500 wirft ArgumentError', () {
      expect(() => leitungsNummernBereich(1, 1000), throwsArgumentError);
    });
  });

  group('leitungsHinweiseFuerStand', () {
    // «Leitungen 7, 8, 9 ← Anstich A» — Gegenrichtung in der Stand-Karte.
    // g2 steht bewusst zuerst, damit die Erstauftritt-Reihenfolge geprüft
    // wird und nicht zufällig mit der alphabetischen übereinstimmt.
    final leitungen = [
      (nummer: '3', quelleId: 'g2', standId: 's1'),
      (nummer: '9', quelleId: 'g1', standId: 's1'),
      (nummer: '7', quelleId: 'g1', standId: 's1'),
      (nummer: '8', quelleId: 'g1', standId: 's2'),
      (nummer: '1', quelleId: 'g1', standId: null),
    ];
    final namen = {'g1': 'Anstich A', 'g2': 'Kühlzelt Nord'};

    test('gruppiert je Quelle, Nummern sortiert', () {
      expect(
        leitungsHinweiseFuerStand(
          standId: 's1', leitungen: leitungen, quelleNamen: namen,
        ),
        ['3 ← Kühlzelt Nord', '7, 9 ← Anstich A'],
      );
    });
    test('Stand ohne Leitungen → leer', () {
      expect(
        leitungsHinweiseFuerStand(
          standId: 's9', leitungen: leitungen, quelleNamen: namen,
        ),
        isEmpty,
      );
    });
    test('unbekannte Quelle fällt nicht um → «?»', () {
      expect(
        leitungsHinweiseFuerStand(
          standId: 's1',
          leitungen: [(nummer: '5', quelleId: 'gX', standId: 's1')],
          quelleNamen: namen,
        ),
        ['5 ← ?'],
      );
    });
  });

  group('leitungNummerPasst', () {
    test('trim + case-insensitiv', () {
      expect(leitungNummerPasst(' 7 ', '7'), isTrue);
      expect(leitungNummerPasst('b3', 'B3'), isTrue);
      expect(leitungNummerPasst('7', '17'), isFalse);
      expect(leitungNummerPasst('', '7'), isFalse);
    });
  });
}
