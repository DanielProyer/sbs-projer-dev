import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/saison_abmachung.dart';

/// Abmachung mit dem Wirt über die nächste Saisonreinigung.
///
/// WARUM: Beim Reinigen vor Ort wird abgemacht, wann Daniel zur Eröffnungs-
/// oder Endreinigung kommen darf — und das ist oft kein fixer Termin.
/// «Die ganze Woche geht» darf im Tourenplan nicht wie ein einzelner Tag
/// aussehen, sonst steht er womöglich vor verschlossener Tür, obwohl drei
/// andere Tage gepasst hätten.
void main() {
  final heute = DateTime(2026, 9, 20);

  group('nächste Zwischensaison', () {
    // Hörnlihütte: Sommer 27.06.–18.10.2026, Winter 01.11.2026–01.04.2027.
    Zeitraum? hoernli({DateTime? jetzt}) => naechsteZwischensaison(
      winterAktiv: true,
      winterStart: DateTime(2026, 11, 1),
      winterEnde: DateTime(2027, 4, 1),
      sommerAktiv: true,
      sommerStart: DateTime(2026, 6, 27),
      sommerEnde: DateTime(2026, 10, 18),
      heute: jetzt ?? heute,
    );

    test('im September kommt die Herbstpause zuerst', () {
      final z = hoernli();
      expect(z, isNotNull);
      expect(z!.von, DateTime(2026, 10, 19));
      expect(z.bis, DateTime(2026, 10, 31));
    });

    test('eine laufende Zwischensaison zählt noch', () {
      final z = hoernli(jetzt: DateTime(2026, 10, 25));
      expect(z!.von, DateTime(2026, 10, 19));
      expect(z.bis, DateTime(2026, 10, 31));
    });

    test('Herbstpause vorbei und Sommer 2027 unbekannt: keine Angabe', () {
      // Die Grenze der Datenlage: Der Betrieb hält je Saison nur EIN Fenster.
      // Nach der Herbstpause 2026 wäre die Frühlingspause 2027 dran — dafür
      // müsste der Sommerstart 2027 bekannt sein, erfasst ist aber noch der
      // Sommer 2026. Lieber keine Angabe als eine erfundene.
      final z = naechsteZwischensaison(
        winterAktiv: true,
        winterStart: DateTime(2026, 11, 1),
        winterEnde: DateTime(2027, 4, 1),
        sommerAktiv: true,
        sommerStart: DateTime(2026, 6, 27),
        sommerEnde: DateTime(2026, 10, 18),
        heute: DateTime(2026, 11, 5),
      );
      expect(z, isNull);
    });

    test('mit erfasstem Folgesommer klappt die Frühlingspause', () {
      final z = naechsteZwischensaison(
        winterAktiv: true,
        winterStart: DateTime(2026, 11, 1),
        winterEnde: DateTime(2027, 4, 1),
        sommerAktiv: true,
        sommerStart: DateTime(2027, 6, 26),
        sommerEnde: DateTime(2027, 10, 17),
        heute: DateTime(2026, 11, 5),
      );
      expect(z!.von, DateTime(2027, 4, 2));
      expect(z.bis, DateTime(2027, 6, 25));
    });

    test('nahtloser Übergang ergibt keine Zwischensaison', () {
      // «Keine Herbstpause»: Sommerende 31.10., Winterstart 01.11.
      final z = naechsteZwischensaison(
        winterAktiv: true,
        winterStart: DateTime(2026, 11, 1),
        winterEnde: DateTime(2027, 4, 1),
        sommerAktiv: true,
        sommerStart: DateTime(2027, 5, 20),
        sommerEnde: DateTime(2026, 10, 31),
        heute: heute,
      );
      // Herbst faellt weg, die Fruehlingspause bleibt.
      expect(z!.von, DateTime(2027, 4, 2));
      expect(z.bis, DateTime(2027, 5, 19));
    });

    test('nur eine Saison angehakt: keine Zwischensaison berechenbar', () {
      expect(
        naechsteZwischensaison(
          winterAktiv: true,
          winterStart: DateTime(2026, 11, 1),
          winterEnde: DateTime(2027, 4, 1),
          sommerAktiv: false,
          sommerStart: null,
          sommerEnde: null,
          heute: heute,
        ),
        isNull,
      );
    });

    test('fehlendes Datum: keine Zwischensaison berechenbar', () {
      expect(
        naechsteZwischensaison(
          winterAktiv: true,
          winterStart: null,
          winterEnde: DateTime(2027, 4, 1),
          sommerAktiv: true,
          sommerStart: null,
          sommerEnde: DateTime(2026, 10, 18),
          heute: heute,
        ),
        isNull,
      );
    });
  });

  group('Zeitraum des Termins', () {
    const zwi = (von: null, bis: null);
    test('fix: ein Tag, kein Enddatum nötig', () {
      final z = terminZeitraum(
        spielraum: Spielraum.fix,
        datum: DateTime(2026, 10, 6),
        zwischensaison: null,
      );
      expect(z!.von, DateTime(2026, 10, 6));
      expect(z.bis, DateTime(2026, 10, 6));
    });

    test('Woche: sieben Tage ab dem gewählten Tag', () {
      final z = terminZeitraum(
        spielraum: Spielraum.woche,
        datum: DateTime(2026, 10, 5),
        zwischensaison: null,
      );
      expect(z!.von, DateTime(2026, 10, 5));
      expect(z.bis, DateTime(2026, 10, 11));
    });

    test('Zwischensaison: der berechnete Zeitraum', () {
      final z = terminZeitraum(
        spielraum: Spielraum.zwischensaison,
        datum: null,
        zwischensaison: (
          von: DateTime(2026, 10, 19),
          bis: DateTime(2026, 10, 31),
        ),
      );
      expect(z!.von, DateTime(2026, 10, 19));
      expect(z.bis, DateTime(2026, 10, 31));
    });

    test('Zwischensaison ohne Zeitraum: nichts zu speichern', () {
      expect(
        terminZeitraum(
          spielraum: Spielraum.zwischensaison,
          datum: DateTime(2026, 10, 6),
          zwischensaison: null,
        ),
        isNull,
      );
      expect(zwi.von, isNull);
    });

    test('fix/Woche ohne Datum: nichts zu speichern', () {
      for (final s in [Spielraum.fix, Spielraum.woche]) {
        expect(
          terminZeitraum(spielraum: s, datum: null, zwischensaison: null),
          isNull,
          reason: s.name,
        );
      }
    });
  });

  test('Titel nennt Art und Spielraum', () {
    expect(
      abmachungTitel(endreinigung: true, s: Spielraum.fix),
      'Endreinigung',
    );
    expect(
      abmachungTitel(endreinigung: true, s: Spielraum.woche),
      'Endreinigung (ganze Woche)',
    );
    expect(
      abmachungTitel(endreinigung: false, s: Spielraum.zwischensaison),
      'Eröffnungsreinigung (ganze Zwischensaison)',
    );
  });

  test('dbWert passt zum CHECK der Migration 199', () {
    expect(Spielraum.values.map((s) => s.dbWert).toList(), [
      'fix',
      'woche',
      'zwischensaison',
    ]);
  });
}
