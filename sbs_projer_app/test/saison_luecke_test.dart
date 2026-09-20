import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/saison_luecke.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Saison-Angaben, die einen Betrieb dauerhaft aus dem Tourenplan werfen.
///
/// WARUM: Am 20.09.2026 waren 25 von 96 operativen Saisonbetrieben betroffen —
/// 21 mit einem Fenster ohne Startdatum (Alpenblick, Sartons, Vincenz,
/// Madrisa Lodge …), 4 ganz ohne angehakte Saison (Alpina Vals, Pellas
/// Vignogn, Rätia Filisur, Weiss Kreuz Preda). Beide Fälle laufen still: Die
/// Betriebe tauchen einfach nicht mehr auf, es wird nirgends rot.
///
/// Die vier ohne Saison sind keine eigenen Kunden; der Provider filtert sie
/// weg, gemeldet werden 21. Diese Tests prüfen die Angabe selbst, ohne Filter.
///
/// Die Tests halten die Lückenprüfung an [istInAktiverSaison] fest — eine
/// gemeldete Lücke muss auch wirklich zum Verschwinden führen.
BetriebLocal _b({
  bool saison = true,
  bool winter = false,
  DateTime? wStart,
  DateTime? wEnde,
  bool sommer = false,
  DateTime? sStart,
  DateTime? sEnde,
}) => BetriebLocal()
  ..serverId = 'x'
  ..name = 'Testbetrieb'
  ..istSaisonbetrieb = saison
  ..winterSaisonAktiv = winter
  ..winterStartDatum = wStart
  ..winterEndeDatum = wEnde
  ..sommerSaisonAktiv = sommer
  ..sommerStartDatum = sStart
  ..sommerEndeDatum = sEnde;

void main() {
  final heute = DateTime(2026, 9, 20);

  group('keine Saison angehakt', () {
    test('gemeldet — und der Betrieb ist tatsächlich nie in Saison', () {
      final b = _b();
      expect(saisonLuecken(b), [SaisonLuecke.keineSaisonAngehakt]);
      expect(saisonLueckeWirkung(b, heute), 'erscheint an keinem einzigen Tag');
      for (final tag in [
        DateTime(2026, 1, 15),
        DateTime(2026, 7, 1),
        DateTime(2027, 2, 2),
      ]) {
        expect(
          istInAktiverSaison(b, tag),
          isFalse,
          reason: 'am ${tag.day}.${tag.month}.${tag.year}',
        );
      }
    });

    test('kein Saisonbetrieb ist nie ein Fall', () {
      expect(saisonLuecken(_b(saison: false)), isEmpty);
    });
  });

  group('Fenster ohne Startdatum', () {
    test('Winter: Ende gesetzt, Start leer — nach dem Ende für immer weg', () {
      final b = _b(winter: true, wEnde: DateTime(2026, 4, 12));
      expect(saisonLuecken(b), [SaisonLuecke.winterOhneStart]);
      expect(saisonDeckungBis(b), DateTime(2026, 4, 12));
      expect(saisonLueckeWirkung(b, heute), 'seit 13.04.2026 aus dem Plan');
      expect(istInAktiverSaison(b, DateTime(2026, 3, 1)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2026, 12, 20)), isFalse);
      expect(istInAktiverSaison(b, DateTime(2030, 1, 1)), isFalse);
    });

    test('Sommer: gleiche Regel', () {
      final b = _b(sommer: true, sEnde: DateTime(2026, 11, 5));
      expect(saisonLuecken(b), [SaisonLuecke.sommerOhneStart]);
      // Ende liegt noch vorn: gemeldet, wirkt aber erst danach.
      expect(saisonLueckeWirkung(b, heute), 'fällt am 06.11.2026 aus dem Plan');
      expect(istInAktiverSaison(b, heute), isTrue);
      expect(istInAktiverSaison(b, DateTime(2026, 11, 6)), isFalse);
    });

    test('beide Fenster lückenhaft — beide gemeldet', () {
      final b = _b(
        winter: true,
        wEnde: DateTime(2026, 4, 12),
        sommer: true,
        sEnde: DateTime(2026, 10, 18),
      );
      expect(saisonLuecken(b), [
        SaisonLuecke.winterOhneStart,
        SaisonLuecke.sommerOhneStart,
      ]);
      // Das spätere Ende entscheidet: noch sichtbar bis 18.10.
      expect(saisonDeckungBis(b), DateTime(2026, 10, 18));
      expect(saisonLueckeWirkung(b, heute), 'fällt am 19.10.2026 aus dem Plan');
    });
  });

  group('Wirkung der Lücke — was sie praktisch bedeutet', () {
    test(
      'offenes Sommerfenster trägt weiter: nicht draussen, aber ohne Pause',
      () {
        // Sartons: Winter ohne Start (Ende 29.03.2026), Sommer ab 14.05.2026
        // ohne Ende. Bis zum 20.09.2026 meldete die App «bereits weg» — falsch,
        // das offene Sommerfenster trägt ihn.
        final b = _b(
          winter: true,
          wEnde: DateTime(2026, 3, 29),
          sommer: true,
          sStart: DateTime(2026, 5, 14),
        );
        expect(saisonLuecken(b), [SaisonLuecke.winterOhneStart]);
        expect(saisonDeckungBis(b), isNull);
        expect(istInAktiverSaison(b, heute), isTrue);
        expect(
          saisonLueckeWirkung(b, heute),
          'Pause fehlt — wird auch in der Sperrzeit eingeplant',
        );
      },
    );

    test('beide Fenster unbefristet offen: trägt ebenfalls weiter', () {
      // Alpenblick: Sommer ganz ohne Daten.
      final b = _b(winter: true, wEnde: DateTime(2026, 4, 6), sommer: true);
      expect(saisonDeckungBis(b), isNull);
      expect(istInAktiverSaison(b, heute), isTrue);
    });

    test('Fenster über den Jahreswechsel läuft nie ab', () {
      final b = _b(
        winter: true,
        wStart: DateTime(2026, 12, 17),
        wEnde: DateTime(2026, 4, 12),
        sommer: true,
        sEnde: DateTime(2026, 11, 5),
      );
      expect(saisonDeckungBis(b), isNull);
    });
  });

  group('Keine Herbstpause', () {
    // Hörnlihütte Arosa: Sommer 27.06.–18.10., Winter 01.11.–01.04. Ohne den
    // Merker klafft im Herbst ein Loch von dreizehn Tagen.
    BetriebLocal hoernli({required bool keineHerbstpause}) => _b(
      winter: true,
      wStart: DateTime(2026, 11, 1),
      wEnde: DateTime(2027, 4, 1),
      sommer: true,
      sStart: DateTime(2026, 6, 27),
      sEnde: DateTime(2026, 10, 18),
    )..keineHerbstpause = keineHerbstpause;

    test('ohne Merker: dreizehn Tage im Herbst fehlen', () {
      final b = hoernli(keineHerbstpause: false);
      expect(istInAktiverSaison(b, DateTime(2026, 10, 18)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2026, 10, 25)), isFalse);
      expect(istInAktiverSaison(b, DateTime(2026, 11, 1)), isTrue);
    });

    test('mit Merker: der Herbst ist durchgehend Saison', () {
      final b = hoernli(keineHerbstpause: true);
      for (final tag in [
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 31),
      ]) {
        expect(istInAktiverSaison(b, tag), isTrue, reason: '${tag.day}.10.');
      }
    });

    test('die Frühlingspause bleibt — dort machen sie immer zu', () {
      final b = hoernli(keineHerbstpause: true);
      expect(istInAktiverSaison(b, DateTime(2027, 4, 1)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2027, 4, 20)), isFalse);
      expect(istInAktiverSaison(b, DateTime(2027, 5, 30)), isFalse);
    });

    test('greift nur, wenn beide Saisons angehakt sind', () {
      final b = hoernli(keineHerbstpause: true)..sommerSaisonAktiv = false;
      expect(istInAktiverSaison(b, DateTime(2026, 10, 25)), isFalse);
    });

    test('veraltetes Winterdatum öffnet die Brücke nicht', () {
      // Winterstart noch aus der Vorsaison: Die Spanne wäre rückwärts.
      final b = hoernli(keineHerbstpause: true)
        ..winterStartDatum = DateTime(2025, 11, 1)
        ..winterEndeDatum = DateTime(2026, 4, 1);
      expect(istInAktiverSaison(b, DateTime(2026, 10, 25)), isFalse);
    });

    test('ohne Merker unveraendert — kein Einfluss auf normale Betriebe', () {
      final b = _b(
        winter: true,
        wStart: DateTime(2026, 12, 4),
        wEnde: DateTime(2027, 4, 6),
      );
      expect(istInAktiverSaison(b, DateTime(2026, 10, 25)), isFalse);
    });
  });

  group('Vorschlag «ein Jahr weiter»', () {
    test('vergangenes Datum rückt auf die kommende Saison', () {
      expect(
        saisonVorschlag(DateTime(2025, 11, 28), heute),
        DateTime(2026, 11, 28),
      );
      expect(
        saisonVorschlag(DateTime(2026, 4, 11), heute),
        DateTime(2027, 4, 11),
      );
    });

    test('künftiges Datum bleibt unangetastet', () {
      expect(
        saisonVorschlag(DateTime(2026, 12, 4), heute),
        DateTime(2026, 12, 4),
      );
      expect(
        saisonVorschlag(DateTime(2027, 4, 1), heute),
        DateTime(2027, 4, 1),
      );
    });

    test('mehrere Jahre alt: springt bis in die Zukunft, Tag bleibt', () {
      final v = saisonVorschlag(DateTime(2021, 12, 19), heute);
      expect(v, DateTime(2026, 12, 19));
      expect(v!.day, 19);
      expect(v.month, 12);
    });

    test('ohne Datum kein Vorschlag — ein Fenster ohne Start bleibt offen', () {
      expect(saisonVorschlag(null, heute), isNull);
    });

    test('heute selbst gilt als nicht vergangen', () {
      expect(
        saisonVorschlag(DateTime(2026, 9, 20), heute),
        DateTime(2026, 9, 20),
      );
    });

    test('die fünf Betriebe aus der Endreinigungs-Warnung', () {
      // Ihre Winterfenster stehen noch auf 2025/26 — genau der Fall, für den
      // der Vorschlag gebaut ist (Stand 20.09.2026).
      final faelle = {
        'Bolgenschanze': (DateTime(2025, 11, 28), DateTime(2026, 4, 11)),
        'Chesa': (DateTime(2025, 12, 12), DateTime(2026, 4, 7)),
        'Hotel Sport': (DateTime(2025, 12, 12), DateTime(2026, 4, 6)),
        'Indy Bar': (DateTime(2025, 12, 12), DateTime(2026, 4, 12)),
        'Kartitscha': (DateTime(2025, 12, 19), DateTime(2026, 4, 6)),
      };
      faelle.forEach((name, fenster) {
        final start = saisonVorschlag(fenster.$1, heute)!;
        final ende = saisonVorschlag(fenster.$2, heute)!;
        expect(start.year, 2026, reason: name);
        expect(ende.year, 2027, reason: name);
        expect(start.isBefore(ende), isTrue, reason: name);
      });
    });
  });

  group('kein Fall', () {
    test('Fenster ganz ohne Daten heisst «unbefristet offen»', () {
      final b = _b(winter: true);
      expect(saisonLuecken(b), isEmpty);
      expect(istInAktiverSaison(b, DateTime(2027, 6, 1)), isTrue);
    });

    test('Start ohne Ende laeuft weiter', () {
      final b = _b(winter: true, wStart: DateTime(2026, 12, 4));
      expect(saisonLuecken(b), isEmpty);
    });

    test('Fenster über den Jahreswechsel (Start nach Ende)', () {
      // Dischma: 04.12.2026 – 06.04.2026 — gilt jedes Jahr um Neujahr.
      final b = _b(
        winter: true,
        wStart: DateTime(2026, 12, 4),
        wEnde: DateTime(2026, 4, 6),
      );
      expect(saisonLuecken(b), isEmpty);
      expect(istInAktiverSaison(b, DateTime(2027, 1, 15)), isTrue);
    });

    test('abgelaufenes, aber vollständiges Fenster ist keine Lücke', () {
      // Winter 2025/26 noch nicht nachgeführt — normale Herbstarbeit.
      final b = _b(
        winter: true,
        wStart: DateTime(2025, 11, 30),
        wEnde: DateTime(2026, 3, 29),
      );
      expect(saisonLuecken(b), isEmpty);
    });

    test('inaktive Saison zaehlt nicht, auch wenn Daten fehlen', () {
      final b = _b(
        winter: false,
        wEnde: DateTime(2026, 4, 12),
        sommer: true,
        sStart: DateTime(2026, 5, 1),
      );
      expect(saisonLuecken(b), isEmpty);
    });
  });
}
