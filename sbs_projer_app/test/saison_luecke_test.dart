import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/saison_luecke.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Saison-Angaben, die einen Betrieb dauerhaft aus dem Tourenplan werfen.
///
/// WARUM: Am 20.09.2026 waren 25 von 96 operativen Saisonbetrieben betroffen —
/// 21 mit einem Fenster ohne Startdatum (Alpenblick, Sartons, Vincenz,
/// Madrisa Lodge …), 4 ganz ohne angehakte Saison (Alpina, Pellas, Rätia,
/// Weiss Kreuz). Beide Fälle laufen still: Die Betriebe tauchen einfach nicht
/// mehr auf, es wird nirgends rot.
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
      expect(saisonLueckeWirktSchon(b, heute), isTrue);
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
      expect(saisonLueckeWirktSchon(b, heute), isTrue);
      expect(istInAktiverSaison(b, DateTime(2026, 3, 1)), isTrue);
      expect(istInAktiverSaison(b, DateTime(2026, 12, 20)), isFalse);
      expect(istInAktiverSaison(b, DateTime(2030, 1, 1)), isFalse);
    });

    test('Sommer: gleiche Regel', () {
      final b = _b(sommer: true, sEnde: DateTime(2026, 11, 5));
      expect(saisonLuecken(b), [SaisonLuecke.sommerOhneStart]);
      // Ende liegt noch vorn: gemeldet, wirkt aber noch nicht.
      expect(saisonLueckeWirktSchon(b, heute), isFalse);
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
      expect(saisonLueckeWirktSchon(b, heute), isFalse);
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
