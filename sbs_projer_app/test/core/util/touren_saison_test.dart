import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _betrieb() => BetriebLocal()
  ..userId = 'test'
  ..name = 'Test'
  ..status = 'aktiv';

void main() {
  group('istOffenerTag', () {
    test('aktiv, kein Ruhetag, keine Ferien, kein Saisonbetrieb → true', () {
      expect(istOffenerTag(_betrieb(), DateTime(2026, 7, 10)), isTrue);
    });
    test('Ruhetag → false', () {
      final b = _betrieb()..ruhetage = ['Samstag'];
      expect(istOffenerTag(b, DateTime(2026, 7, 11)), isFalse);
    });
    test('in Ferien → false', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 7, 6)
        ..ferienEnde = DateTime(2026, 7, 20);
      expect(istOffenerTag(b, DateTime(2026, 7, 10)), isFalse);
    });
    test('Saisonbetrieb ausserhalb Saison → false', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(istOffenerTag(b, DateTime(2026, 11, 1)), isFalse);
    });
    test('Saisonbetrieb innerhalb Saison → true', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(istOffenerTag(b, DateTime(2026, 7, 10)), isTrue);
    });
    test('status != aktiv → false', () {
      final b = _betrieb()..status = 'inaktiv';
      expect(istOffenerTag(b, DateTime(2026, 7, 10)), isFalse);
    });
  });

  group('naechsterOffenerTag', () {
    test('überspringt Ruhetage vorwärts', () {
      final b = _betrieb()..ruhetage = ['Samstag', 'Sonntag'];
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 11)),
          DateTime(2026, 7, 13));
    });
    test('überspringt Ferien vorwärts', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 7, 13)
        ..ferienEnde = DateTime(2026, 7, 17);
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 13)),
          DateTime(2026, 7, 18));
    });
    test('rückwärts findet letzten offenen Tag', () {
      final b = _betrieb()..ruhetage = ['Samstag', 'Sonntag'];
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 11), rueckwaerts: true),
          DateTime(2026, 7, 10));
    });
    test('nie offen → null nach 60 Tagen', () {
      final b = _betrieb()..status = 'inaktiv';
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 10)), isNull);
    });
  });

  group('qualifizierteSchliessung', () {
    test('Saisonende → erster geschlossener Tag = Ende+1, istSaisonende', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      final s = qualifizierteSchliessung(b, DateTime(2026, 9, 1));
      expect(s, isNotNull);
      expect(s!.datum, DateTime(2026, 10, 1));
      expect(s.istSaisonende, isTrue);
    });
    test('lange Ferien (≥21 Tage) → Start; kurze werden ignoriert', () {
      final lang = _betrieb()
        ..ferienStart = DateTime(2026, 7, 1)
        ..ferienEnde = DateTime(2026, 7, 21);
      final s = qualifizierteSchliessung(lang, DateTime(2026, 6, 1));
      expect(s!.datum, DateTime(2026, 7, 1));
      expect(s.istSaisonende, isFalse);

      final kurz = _betrieb()
        ..ferienStart = DateTime(2026, 7, 1)
        ..ferienEnde = DateTime(2026, 7, 20);
      expect(qualifizierteSchliessung(kurz, DateTime(2026, 6, 1)), isNull);
    });
    test('nächste Schliessung gewinnt (Ferien vor Saisonende)', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30)
        ..ferienStart = DateTime(2026, 7, 1)
        ..ferienEnde = DateTime(2026, 7, 21);
      final s = qualifizierteSchliessung(b, DateTime(2026, 6, 1));
      expect(s!.datum, DateTime(2026, 7, 1));
      expect(s.istSaisonende, isFalse);
    });
  });

  group('darfTrotzSchliessungGeplantWerden', () {
    // Löwen-Muster (04.08.2026): Ferien 18.07.–06.08., Eröffnungstermin am
    // letzten Ferientag — muss trotz Schliessung planbar sein.
    BetriebLocal ferienBetrieb() => _betrieb()
      ..ferienStart = DateTime(2026, 7, 18)
      ..ferienEnde = DateTime(2026, 8, 6);

    test('Eröffnung am letzten Ferientag → true', () {
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 8, 6),
        ),
        isTrue,
      );
    });
    test('Eröffnung mitten in den Ferien → false', () {
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 7, 25),
        ),
        isFalse,
      );
    });

    // Eröffnungsfenster statt Einzeltag (Regel Daniel 08.08.2026, Fall
    // Pizzeria Paradies): Daniel plant den Service dann, wenn er in die Tour
    // passt — der letzte Schliessungstag ist oft ein Ruhetag oder liegt quer.
    test('Eröffnung 7 Tage vor der Wiedereröffnung → true', () {
      // Ferien bis 06.08. → offen ab 07.08.; 31.07. ist der 7. Tag davor.
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 7, 31),
        ),
        isTrue,
      );
    });
    test('Eröffnung 8 Tage vor der Wiedereröffnung → false', () {
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 7, 30),
        ),
        isFalse,
      );
    });
    test('Endreinigung am 7. Schliessungstag → true', () {
      // Erster geschlossener Tag 18.07. → 24.07. ist der 7.
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'endreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 7, 24),
        ),
        isTrue,
      );
    });
    test('Endreinigung am 8. Schliessungstag → false', () {
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'endreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 7, 25),
        ),
        isFalse,
      );
    });
    test('Eröffnung am ersten Ferientag → false', () {
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 7, 18),
        ),
        isFalse,
      );
    });
    test('offener Tag → false (normale Regeln greifen)', () {
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 8, 7),
        ),
        isFalse,
      );
    });
    test('Endreinigung am ersten Ferientag → true', () {
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'endreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 7, 18),
        ),
        isTrue,
      );
    });
    test('Endreinigung am letzten Ferientag → false', () {
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'endreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 8, 6),
        ),
        isFalse,
      );
    });
    test('inaktiver Betrieb → false, auch am letzten Ferientag', () {
      final b = ferienBetrieb()..status = 'inaktiv';
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: b,
          tag: DateTime(2026, 8, 6),
        ),
        isFalse,
      );
    });
    test('letzter Ferientag zugleich Ruhetag → true (Ruhetage zählen nicht)',
        () {
      // 06.08.2026 ist ein Donnerstag.
      final b = ferienBetrieb()..ruhetage = ['Donnerstag'];
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: b,
          tag: DateTime(2026, 8, 6),
        ),
        isTrue,
      );
    });
    test('blosser Ruhetag ohne Schliessung → false', () {
      final b = _betrieb()..ruhetage = ['Donnerstag'];
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: b,
          tag: DateTime(2026, 8, 6),
        ),
        isFalse,
      );
    });

    // Zwischensaison: Sommer 01.05.–30.09.
    BetriebLocal saisonBetrieb() => _betrieb()
      ..istSaisonbetrieb = true
      ..sommerSaisonAktiv = true
      ..sommerStartDatum = DateTime(2026, 5, 1)
      ..sommerEndeDatum = DateTime(2026, 9, 30);

    test('Endreinigung am ersten Tag nach Saisonende → true', () {
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'endreinigung',
          betrieb: saisonBetrieb(),
          tag: DateTime(2026, 10, 1),
        ),
        isTrue,
      );
    });
    test('Eröffnung am letzten Tag vor Saisonstart → true', () {
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: saisonBetrieb(),
          tag: DateTime(2026, 4, 30),
        ),
        isTrue,
      );
    });
    test('mitten in der Zwischensaison → false für beide Arten', () {
      final b = saisonBetrieb();
      final tag = DateTime(2026, 12, 15);
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'eroeffnungsreinigung',
          betrieb: b,
          tag: tag,
        ),
        isFalse,
      );
      expect(
        darfTrotzSchliessungGeplantWerden(
          art: 'endreinigung',
          betrieb: b,
          tag: tag,
        ),
        isFalse,
      );
    });
  });

  group('saisonPlanungsHinweis', () {
    BetriebLocal ferienBetrieb() => _betrieb()
      ..ferienStart = DateTime(2026, 7, 18)
      ..ferienEnde = DateTime(2026, 8, 6);
    BetriebLocal saisonBetrieb() => _betrieb()
      ..istSaisonbetrieb = true
      ..sommerSaisonAktiv = true
      ..sommerStartDatum = DateTime(2026, 5, 1)
      ..sommerEndeDatum = DateTime(2026, 9, 30);

    test('Eröffnung am letzten Ferientag → «Letzter Ferientag — Eröffnung»',
        () {
      expect(
        saisonPlanungsHinweis(
          art: 'eroeffnungsreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 8, 6),
        ),
        'Letzter Ferientag — Eröffnung',
      );
    });
    test('Endreinigung am ersten Ferientag → «Erster Ferientag — Endreinigung»',
        () {
      expect(
        saisonPlanungsHinweis(
          art: 'endreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 7, 18),
        ),
        'Erster Ferientag — Endreinigung',
      );
    });
    test('Zwischensaison nennt Schliessungstag statt Ferientag', () {
      expect(
        saisonPlanungsHinweis(
          art: 'eroeffnungsreinigung',
          betrieb: saisonBetrieb(),
          tag: DateTime(2026, 4, 30),
        ),
        'Letzter Schliessungstag — Eröffnung',
      );
      expect(
        saisonPlanungsHinweis(
          art: 'endreinigung',
          betrieb: saisonBetrieb(),
          tag: DateTime(2026, 10, 1),
        ),
        'Erster Schliessungstag — Endreinigung',
      );
    });
    test('kein Anspruch → null', () {
      expect(
        saisonPlanungsHinweis(
          art: 'eroeffnungsreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 7, 25),
        ),
        isNull,
      );
    });
    test('im Fenster, aber nicht am letzten Tag → nennt die Restdauer', () {
      expect(
        saisonPlanungsHinweis(
          art: 'eroeffnungsreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 8, 3),
        ),
        'Öffnet in 4 Tagen — Eröffnung',
      );
      expect(
        saisonPlanungsHinweis(
          art: 'endreinigung',
          betrieb: ferienBetrieb(),
          tag: DateTime(2026, 7, 21),
        ),
        '4. Ferientag — Endreinigung',
      );
    });
  });

  group('oeffnungNach', () {
    test('Saisonstart nach ab', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(oeffnungNach(b, DateTime(2026, 1, 1)), DateTime(2026, 5, 1));
    });
    test('Ferienende+1, nimmt die frühere Öffnung', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30)
        ..ferienStart = DateTime(2026, 2, 1)
        ..ferienEnde = DateTime(2026, 2, 10);
      expect(oeffnungNach(b, DateTime(2026, 1, 1)), DateTime(2026, 2, 11));
    });
  });

  group('qualifizierteOeffnungNach', () {
    test('kurze Ferien (<21 Tage) zählen nicht als Wiedereröffnung', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 2, 1)
        ..ferienEnde = DateTime(2026, 2, 10);
      expect(qualifizierteOeffnungNach(b, DateTime(2026, 1, 1)), isNull);
    });
    test('lange Ferien (≥21 Tage) → Ende+1', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 2, 1)
        ..ferienEnde = DateTime(2026, 2, 21);
      expect(
        qualifizierteOeffnungNach(b, DateTime(2026, 1, 1)),
        DateTime(2026, 2, 22),
      );
    });
    test('Saisonstart zählt immer, kurze Ferien davor werden übersprungen', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30)
        ..ferienStart = DateTime(2026, 2, 1)
        ..ferienEnde = DateTime(2026, 2, 10);
      expect(
        qualifizierteOeffnungNach(b, DateTime(2026, 1, 1)),
        DateTime(2026, 5, 1),
      );
    });
  });

  // Auto-Vorschläge im Tourenplan (Regel Daniel 08.08.2026). Auslöser ist
  // allein die qualifizierte Schliessung — NICHT, ob die letzte Reinigung als
  // 'endreinigung' erfasst wurde. Fall Flora Landquart: Ferien 20.07.–10.08.,
  // letzte Reinigung als «Service» erfasst, trotzdem Eröffnung nötig.
  group('eroeffnungsVorschlagsTag', () {
    // Ferien 20.07.–10.08. (22 Tage, qualifiziert) → offen ab 11.08.
    BetriebLocal flora() => _betrieb()
      ..ferienStart = DateTime(2026, 7, 20)
      ..ferienEnde = DateTime(2026, 8, 10);

    test('letzter Ferientag → Vorschlag an diesem Tag', () {
      expect(
        eroeffnungsVorschlagsTag(
          betrieb: flora(),
          tag: DateTime(2026, 8, 10),
          letzteReinigung: DateTime(2026, 7, 15),
        ),
        DateTime(2026, 8, 10),
      );
    });
    test('7 Tage vor der Wiedereröffnung → Vorschlag an diesem Tag', () {
      expect(
        eroeffnungsVorschlagsTag(
          betrieb: flora(),
          tag: DateTime(2026, 8, 4),
          letzteReinigung: DateTime(2026, 7, 15),
        ),
        DateTime(2026, 8, 4),
      );
    });
    test('8 Tage vor der Wiedereröffnung → kein Vorschlag', () {
      expect(
        eroeffnungsVorschlagsTag(
          betrieb: flora(),
          tag: DateTime(2026, 8, 3),
          letzteReinigung: DateTime(2026, 7, 15),
        ),
        isNull,
      );
    });
    test('erster offener Tag ab Wiedereröffnung → Vorschlag', () {
      expect(
        eroeffnungsVorschlagsTag(
          betrieb: flora(),
          tag: DateTime(2026, 8, 11),
          letzteReinigung: DateTime(2026, 7, 15),
        ),
        DateTime(2026, 8, 11),
      );
    });
    test('Muloin-Regel: Reinigung lag in der Schliessung → kein Vorschlag', () {
      expect(
        eroeffnungsVorschlagsTag(
          betrieb: flora(),
          tag: DateTime(2026, 8, 10),
          letzteReinigung: DateTime(2026, 7, 25),
        ),
        isNull,
      );
    });
    test('kurze Ferien (<21 Tage) lösen keinen Vorschlag aus', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 7, 20)
        ..ferienEnde = DateTime(2026, 7, 29);
      expect(
        eroeffnungsVorschlagsTag(
          betrieb: b,
          tag: DateTime(2026, 7, 29),
          letzteReinigung: DateTime(2026, 7, 15),
        ),
        isNull,
      );
    });
    test('inaktiver Betrieb → kein Vorschlag', () {
      final b = flora()..status = 'geschlossen';
      expect(
        eroeffnungsVorschlagsTag(
          betrieb: b,
          tag: DateTime(2026, 8, 10),
          letzteReinigung: DateTime(2026, 7, 15),
        ),
        isNull,
      );
    });
  });

  group('endreinigungsVorschlagsTag', () {
    // Ferien 20.07.–10.08.; letzter offener Tag davor = 19.07.
    BetriebLocal flora() => _betrieb()
      ..ferienStart = DateTime(2026, 7, 20)
      ..ferienEnde = DateTime(2026, 8, 10);

    test('letzter offener Tag vor der Schliessung → Vorschlag', () {
      expect(
        endreinigungsVorschlagsTag(
          betrieb: flora(),
          tag: DateTime(2026, 7, 19),
          letzteServiceArt: 'Service',
        ),
        DateTime(2026, 7, 19),
      );
    });
    test('7. Schliessungstag → Vorschlag an diesem Tag', () {
      expect(
        endreinigungsVorschlagsTag(
          betrieb: flora(),
          tag: DateTime(2026, 7, 26),
          letzteServiceArt: 'Service',
        ),
        DateTime(2026, 7, 26),
      );
    });
    test('8. Schliessungstag → kein Vorschlag', () {
      expect(
        endreinigungsVorschlagsTag(
          betrieb: flora(),
          tag: DateTime(2026, 7, 27),
          letzteServiceArt: 'Service',
        ),
        isNull,
      );
    });
    test('Endreinigung bereits erledigt → kein Vorschlag', () {
      expect(
        endreinigungsVorschlagsTag(
          betrieb: flora(),
          tag: DateTime(2026, 7, 19),
          letzteServiceArt: 'endreinigung',
        ),
        isNull,
      );
    });
    test('Alt-Daten schreiben «Endreinigung» gross — zählt genauso', () {
      expect(
        endreinigungsVorschlagsTag(
          betrieb: flora(),
          tag: DateTime(2026, 7, 19),
          letzteServiceArt: 'Endreinigung',
        ),
        isNull,
      );
    });
  });
}
