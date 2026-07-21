import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

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

  group('getFaelligkeit mit Anker (Tgantieni-Szenario)', () {
    AnlageLocal anlage() => AnlageLocal()
      ..status = 'aktiv'
      ..typAnlage = 'Bier'
      ..reinigungRhythmus = '4-Wochen'
      ..letzteReinigung = DateTime(2026, 3, 30)
      ..naechsteReinigung = DateTime(2026, 4, 27); // alter, überholter Soll

    test('vor Saisonstart: nicht fällig (Pause)', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 5, 15),
              betrieb: saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.nichtFaellig);
    });
    test(
        '7 Tage vor Start, Endreinigung lag in der Pause: KEIN Eröffnungs-'
        'Hinweis (Regel Daniel 21.07.: jede Pausen-Reinigung unterdrückt ihn)',
        () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 6, 1),
              betrieb: saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.nichtFaellig);
    });
    test('7 Tage vor Start, Endreinigung am letzten Saisontag: Hinweis bleibt',
        () {
      final a = anlage()..letzteReinigung = DateTime(2026, 3, 29);
      expect(
          getFaelligkeit(a, DateTime(2026, 6, 1),
              betrieb: saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.eroeffnungFaellig);
    });
    test('nach Start, vor Soll (03.07.): nicht fällig — KEIN ewiges eroeffnungFaellig', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 7, 3),
              betrieb: saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.nichtFaellig);
    });
    test('Soll erreicht (05.07.): bald fällig', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 7, 5),
              betrieb: saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.baldFaellig);
    });
    test('Soll +1 Woche (12.07.): fällig', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 7, 12),
              betrieb: saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.faellig);
    });
    test('Soll +2 Wochen (19.07.): überfällig', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 7, 19),
              betrieb: saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.ueberfaellig);
    });
    test('istInSchliessung: Ferien und Saisonpause ja, offene Tage nein', () {
      final b = ganzjahresBetrieb(); // Ferien 01.05.–28.05.
      expect(istInSchliessung(b, DateTime(2026, 5, 10)), isTrue);
      expect(istInSchliessung(b, DateTime(2026, 6, 10)), isFalse);
      final s = saisonBetrieb(); // Pause 30.03.–05.06.
      expect(istInSchliessung(s, DateTime(2026, 3, 30)), isTrue);
      expect(istInSchliessung(s, DateTime(2026, 3, 29)), isFalse);
    });

    test('Eröffnungsreinigung in der Pause: kein Hinweis mehr, Uhr ab Start', () {
      final a = anlage()
        ..letzteReinigung = DateTime(2026, 6, 3)
        ..naechsteReinigung = null;
      expect(
          getFaelligkeit(a, DateTime(2026, 6, 4),
              betrieb: saisonBetrieb(), letzteServiceArt: 'eroeffnungsservice'),
          FaelligkeitsStatus.nichtFaellig);
      expect(
          getFaelligkeit(a, DateTime(2026, 7, 12),
              betrieb: saisonBetrieb(), letzteServiceArt: 'eroeffnungsservice'),
          FaelligkeitsStatus.faellig);
    });
  });

  group('Muloin-Szenario: Endreinigung IN den Betriebsferien (21.07.2026)', () {
    // Muloin Lenzerheide: Ferien 26.06.–27.07., Endreinigung am 30.06. —
    // also bereits in der Pause. Regel Daniel 17./21.07.: Eröffnungs-Hinweis
    // nur, wenn in der Pause NICHT gereinigt wurde; die Uhr zählt ab der
    // Wiedereröffnung (28.07.) + Rhythmus -> fällig Ende August.
    BetriebLocal muloin() => BetriebLocal()
      ..name = 'Muloin'
      ..status = 'aktiv'
      ..istSaisonbetrieb = false
      ..ferienStart = DateTime(2026, 6, 26)
      ..ferienEnde = DateTime(2026, 7, 27)
      ..ruhetage = [];

    AnlageLocal anlage() => AnlageLocal()
      ..status = 'aktiv'
      ..typAnlage = 'Warmanstich'
      ..reinigungRhythmus = '4-Wochen'
      ..letzteReinigung = DateTime(2026, 6, 30)
      ..naechsteReinigung = DateTime(2026, 7, 28);

    test('21.07. (7 Tage vor Öffnung): KEIN Eröffnungs-Hinweis, nicht fällig',
        () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 7, 21),
              betrieb: muloin(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.nichtFaellig);
    });
    test('25.08. (Öffnung 28.07. + 4 Wochen): bald fällig', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 8, 25),
              betrieb: muloin(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.baldFaellig);
    });
    test('Gegenprobe: Endreinigung am 25.06. VOR den Ferien -> Hinweis kommt',
        () {
      final a = anlage()..letzteReinigung = DateTime(2026, 6, 25);
      expect(
          getFaelligkeit(a, DateTime(2026, 7, 21),
              betrieb: muloin(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.eroeffnungFaellig);
    });
  });
}
