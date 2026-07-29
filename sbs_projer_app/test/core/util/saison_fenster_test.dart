import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _saisonbetrieb() => BetriebLocal()
  ..userId = 'test'
  ..name = 'Test'
  ..status = 'aktiv'
  ..istSaisonbetrieb = true;

void main() {
  group('istInAktiverSaison — offene Grenzen (Regel Daniel 29.07.2026)', () {
    test('kein Saisonbetrieb ist immer in Saison', () {
      final b = BetriebLocal()
        ..userId = 'test'
        ..name = 'Test'
        ..status = 'aktiv';
      expect(istInAktiverSaison(b, DateTime(2026, 1, 15)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2026, 7, 15)), isTrue);
    });

    test('Fall Grischa Davos: Sommer läuft, Ende noch offen', () {
      final b = _saisonbetrieb()
        ..winterSaisonAktiv = true
        ..winterStartDatum = null
        ..winterEndeDatum = DateTime(2026, 4, 6)
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 23)
        ..sommerEndeDatum = null;
      expect(istInAktiverSaison(b, DateTime(2026, 7, 29)), isTrue);
      // Vor Sommerstart und nach Winterende: geschlossen.
      expect(istInAktiverSaison(b, DateTime(2026, 5, 1)), isFalse);
      // Im Winter (offener Start) noch drin.
      expect(istInAktiverSaison(b, DateTime(2026, 2, 10)), isTrue);
    });

    test('fehlendes Enddatum: Saison läuft weiter', () {
      final b = _saisonbetrieb()
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = null;
      expect(istInAktiverSaison(b, DateTime(2026, 5, 1)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2030, 1, 1)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2026, 4, 30)), isFalse);
    });

    test('fehlendes Startdatum: Saison hat bereits begonnen', () {
      final b = _saisonbetrieb()
        ..winterSaisonAktiv = true
        ..winterStartDatum = null
        ..winterEndeDatum = DateTime(2026, 4, 12);
      expect(istInAktiverSaison(b, DateTime(2026, 4, 12)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2020, 1, 1)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2026, 4, 13)), isFalse);
    });

    test('aktive Saison ganz ohne Daten gilt als offen', () {
      final b = _saisonbetrieb()
        ..sommerSaisonAktiv = true
        ..winterSaisonAktiv = true;
      expect(istInAktiverSaison(b, DateTime(2026, 7, 29)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2026, 12, 24)), isTrue);
    });

    test('abgehakte Saison zählt nicht, auch mit Daten', () {
      final b = _saisonbetrieb()
        ..sommerSaisonAktiv = false
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = null;
      expect(istInAktiverSaison(b, DateTime(2026, 7, 29)), isFalse);
    });

    test('Saisonbetrieb ohne jede aktive Saison ist geschlossen', () {
      expect(istInAktiverSaison(_saisonbetrieb(), DateTime(2026, 7, 29)),
          isFalse);
    });
  });

  group('istInAktiverSaison — Fenster über den Jahreswechsel', () {
    // Wintersaison 01.12. bis 01.04.: Start liegt nach dem Ende.
    final winter = _saisonbetrieb()
      ..winterSaisonAktiv = true
      ..winterStartDatum = DateTime(2026, 12, 1)
      ..winterEndeDatum = DateTime(2026, 4, 1);

    test('Dezember liegt in der Saison', () {
      expect(istInAktiverSaison(winter, DateTime(2026, 12, 15)), isTrue);
    });

    test('Januar des Folgejahres liegt in der Saison', () {
      expect(istInAktiverSaison(winter, DateTime(2027, 1, 20)), isTrue);
    });

    test('Sommer liegt ausserhalb', () {
      expect(istInAktiverSaison(winter, DateTime(2026, 7, 29)), isFalse);
    });

    test('die Randtage zählen dazu', () {
      expect(istInAktiverSaison(winter, DateTime(2026, 12, 1)), isTrue);
      expect(istInAktiverSaison(winter, DateTime(2026, 4, 1)), isTrue);
      expect(istInAktiverSaison(winter, DateTime(2026, 4, 2)), isFalse);
      expect(istInAktiverSaison(winter, DateTime(2026, 11, 30)), isFalse);
    });

    test('normales Fenster bleibt unverändert', () {
      final sommer = _saisonbetrieb()
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(istInAktiverSaison(sommer, DateTime(2026, 7, 1)), isTrue);
      expect(istInAktiverSaison(sommer, DateTime(2026, 11, 1)), isFalse);
      expect(istInAktiverSaison(sommer, DateTime(2026, 1, 1)), isFalse);
    });
  });

  group('istInAktiverSaison — Uhrzeit', () {
    test('die Tageszeit spielt keine Rolle', () {
      final b = _saisonbetrieb()
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(istInAktiverSaison(b, DateTime(2026, 9, 30, 23, 59)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2026, 5, 1, 0, 1)), isTrue);
    });
  });
}
