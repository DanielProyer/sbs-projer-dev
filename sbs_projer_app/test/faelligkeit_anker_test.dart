import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal saisonBetrieb() => BetriebLocal()
  ..name = 'Test'
  ..status = 'aktiv'
  ..istSaisonbetrieb = true
  ..winterSaisonAktiv = true
  ..winterStartDatum = DateTime(2025, 12, 5)
  ..winterEndeDatum = DateTime(2026, 3, 29)
  ..sommerSaisonAktiv = true
  ..sommerStartDatum = DateTime(2026, 6, 6)
  ..sommerEndeDatum = DateTime(2026, 10, 21)
  ..ruhetage = ['Montag'];

BetriebLocal ganzjahresBetrieb() => BetriebLocal()
  ..name = 'Test'
  ..status = 'aktiv'
  ..istSaisonbetrieb = false
  ..ferienStart = DateTime(2026, 5, 1)
  ..ferienEnde = DateTime(2026, 5, 28)
  ..ruhetage = [];

void main() {
  group('faelligkeitsAnker', () {
    test('Endreinigung am Tag nach Saisonschluss -> Anker = Saisonstart', () {
      final anker = faelligkeitsAnker(saisonBetrieb(), DateTime(2026, 3, 30));
      expect(anker, DateTime(2026, 6, 6));
    });
    test('Eröffnungsreinigung VOR Saisonstart -> Anker = Saisonstart', () {
      final anker = faelligkeitsAnker(saisonBetrieb(), DateTime(2026, 6, 3));
      expect(anker, DateTime(2026, 6, 6));
    });
    test('Reinigung mitten in der Saison -> Anker = Reinigungsdatum', () {
      final anker = faelligkeitsAnker(saisonBetrieb(), DateTime(2026, 7, 10));
      expect(anker, DateTime(2026, 7, 10));
    });
    test('Ruhetag nach der Reinigung verschiebt den Anker NICHT', () {
      // 12.07.2026 = Sonntag -> 13.07. Montag = Ruhetag, aber in Saison.
      final anker = faelligkeitsAnker(saisonBetrieb(), DateTime(2026, 7, 12));
      expect(anker, DateTime(2026, 7, 12));
    });
    test('Endreinigung, aber kein künftiger Saisonstart gepflegt -> null', () {
      final b = saisonBetrieb()
        ..sommerSaisonAktiv = false
        ..sommerStartDatum = null
        ..sommerEndeDatum = null;
      expect(faelligkeitsAnker(b, DateTime(2026, 3, 30)), isNull);
    });
    test(
      'Betriebsferien: Reinigung vor den Ferien -> Anker = Ferienende + 1',
      () {
        final anker = faelligkeitsAnker(
          ganzjahresBetrieb(),
          DateTime(2026, 4, 30),
        );
        expect(anker, DateTime(2026, 5, 29));
      },
    );
    test('Ganzjahresbetrieb ohne Schliessung -> Anker = Reinigungsdatum', () {
      final b = ganzjahresBetrieb()
        ..ferienStart = null
        ..ferienEnde = null;
      expect(
        faelligkeitsAnker(b, DateTime(2026, 4, 30)),
        DateTime(2026, 4, 30),
      );
    });
  });
}
