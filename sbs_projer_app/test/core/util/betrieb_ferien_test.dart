import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _betrieb() => BetriebLocal()
  ..userId = 'test'
  ..name = 'Test';

void main() {
  group('ferienSlots', () {
    test('ohne Ferien: 5 leere Slots', () {
      final slots = ferienSlots(_betrieb());
      expect(slots.length, 5);
      expect(slots.every((s) => s.start == null && s.ende == null), isTrue);
    });

    test('liefert alle 5 Slots in Reihenfolge', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 1, 1)
        ..ferien4Start = DateTime(2026, 4, 1)
        ..ferien5Ende = DateTime(2026, 5, 31);
      final slots = ferienSlots(b);
      expect(slots[0].start, DateTime(2026, 1, 1));
      expect(slots[3].start, DateTime(2026, 4, 1));
      expect(slots[4].ende, DateTime(2026, 5, 31));
    });
  });

  group('ferienStarts / ferienEnden', () {
    test('nur belegte Werte, auch aus Slot 4+5', () {
      final b = _betrieb()
        ..ferien2Start = DateTime(2026, 2, 1)
        ..ferien5Start = DateTime(2026, 5, 1)
        ..ferien3Ende = DateTime(2026, 3, 15);
      expect(ferienStarts(b), [DateTime(2026, 2, 1), DateTime(2026, 5, 1)]);
      expect(ferienEnden(b), [DateTime(2026, 3, 15)]);
    });
  });

  group('istInFerien', () {
    test(
      'innerhalb Ferien 2 -> true (Bugfix: bisher nur Ferien 1 geprueft)',
      () {
        final b = _betrieb()
          ..ferien2Start = DateTime(2026, 7, 10)
          ..ferien2Ende = DateTime(2026, 7, 20);
        expect(istInFerien(b, DateTime(2026, 7, 15)), isTrue);
      },
    );

    test('Randtage inklusive', () {
      final b = _betrieb()
        ..ferien4Start = DateTime(2026, 8, 1)
        ..ferien4Ende = DateTime(2026, 8, 14);
      expect(istInFerien(b, DateTime(2026, 8, 1)), isTrue);
      expect(istInFerien(b, DateTime(2026, 8, 14)), isTrue);
      expect(istInFerien(b, DateTime(2026, 7, 31)), isFalse);
      expect(istInFerien(b, DateTime(2026, 8, 15)), isFalse);
    });

    test('unvollstaendiger Slot (nur Start) zaehlt nicht', () {
      final b = _betrieb()..ferien3Start = DateTime(2026, 9, 1);
      expect(istInFerien(b, DateTime(2026, 9, 5)), isFalse);
    });
  });

  group('ferienPerioden (Tabelle betrieb_ferien)', () {
    test('istInFerien findet Periode, die nur in ferienPerioden steht', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 10, 1), bis: DateTime(2026, 10, 10)),
        ];
      expect(istInFerien(b, DateTime(2026, 10, 5)), isTrue);
    });

    test('Randtage inklusive', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 10, 1), bis: DateTime(2026, 10, 10)),
        ];
      expect(istInFerien(b, DateTime(2026, 10, 1)), isTrue);
      expect(istInFerien(b, DateTime(2026, 10, 10)), isTrue);
    });

    test('Tag ausserhalb ergibt false', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 10, 1), bis: DateTime(2026, 10, 10)),
        ];
      expect(istInFerien(b, DateTime(2026, 9, 30)), isFalse);
      expect(istInFerien(b, DateTime(2026, 10, 11)), isFalse);
    });

    test('Rueckfall: ferienPerioden nicht geladen -> alte Spalten greifen', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 7, 10)
        ..ferienEnde = DateTime(2026, 7, 20);
      // null = noch nicht geladen (Default) — Rueckfall auf alte Spalten.
      expect(b.ferienPerioden, isNull);
      expect(istInFerien(b, DateTime(2026, 7, 15)), isTrue);
    });

    test(
      'geladen und leer: alte Spalten schweigen (geloeschte Ferien bleiben weg)',
      () {
        // Der Zombie-Fall: Daniel loescht eine falsch erfasste Periode. Waere
        // die leere Liste gleichbedeutend mit "nicht geladen", kaeme die
        // Periode ueber die alte Spalte zurueck und liesse sich nie entfernen.
        final b = _betrieb()
          ..ferienStart = DateTime(2026, 7, 10)
          ..ferienEnde = DateTime(2026, 7, 20)
          ..ferienPerioden = const [];
        expect(istInFerien(b, DateTime(2026, 7, 15)), isFalse);
        expect(ferienStarts(b), isEmpty);
      },
    );

    test(
      'gefuellte ferienPerioden ignorieren alte Spalten (kein Vermischen)',
      () {
        final b = _betrieb()
          ..ferienStart = DateTime(2026, 7, 10)
          ..ferienEnde = DateTime(2026, 7, 20)
          ..ferienPerioden = [
            (von: DateTime(2026, 10, 1), bis: DateTime(2026, 10, 10)),
          ];
        // Alte Spalte waere hier true, muss aber ignoriert werden.
        expect(istInFerien(b, DateTime(2026, 7, 15)), isFalse);
        // Nur die neue Periode zaehlt.
        expect(istInFerien(b, DateTime(2026, 10, 5)), isTrue);
      },
    );

    test('ferienStarts/ferienEnden liefern Werte aus ferienPerioden', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 10, 1), bis: DateTime(2026, 10, 10)),
          (von: DateTime(2026, 11, 1), bis: DateTime(2026, 11, 5)),
        ];
      expect(ferienStarts(b), [DateTime(2026, 10, 1), DateTime(2026, 11, 1)]);
      expect(ferienEnden(b), [DateTime(2026, 10, 10), DateTime(2026, 11, 5)]);
    });

    test('mehrere Perioden werden alle geprueft', () {
      final b = _betrieb()
        ..ferienPerioden = [
          (von: DateTime(2026, 1, 1), bis: DateTime(2026, 1, 5)),
          (von: DateTime(2026, 6, 1), bis: DateTime(2026, 6, 5)),
          (von: DateTime(2026, 12, 20), bis: DateTime(2026, 12, 31)),
        ];
      expect(istInFerien(b, DateTime(2026, 1, 3)), isTrue);
      expect(istInFerien(b, DateTime(2026, 6, 3)), isTrue);
      expect(istInFerien(b, DateTime(2026, 12, 25)), isTrue);
      expect(istInFerien(b, DateTime(2026, 7, 1)), isFalse);
    });
  });
}
