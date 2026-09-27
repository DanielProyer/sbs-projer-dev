import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/buchhaltung/heineken_buchung_service.dart';
import 'package:sbs_projer_app/services/camt/heineken_matcher.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart'
    show zuordnungGesperrt;

/// R3 (App-Analyse 25.09.2026): Die Heineken-Freigabe darf nicht übersprungen
/// werden — sonst fehlt die Ertragsbuchung 1100/3400 für immer.
///
/// Seit Migration 211 ist die Freigabe `freigegeben_am`, der Versand
/// `versendet_am`; der Status sagt nur noch offen/bezahlt/abgeschrieben.

/// Rechnung auf einer Stufe des Heineken-Ablaufs — aus FELDERN gebaut:
/// `offen` (nichts), `gesendet` (+ versendet_am), `freigegeben`
/// (+ freigegeben_am), `bezahlt`/`abgeschrieben` (Status), `gemahnt`
/// (Kunden-/Jahresrechnung mit Mahnstufe 2).
Rechnung hr(
  String stufe, {
  String id = 'h1',
  double brutto = 13966.09,
  String typ = 'heineken_monat',
}) {
  final versendet =
      stufe == 'offen' || stufe == 'abgeschrieben' ? null : DateTime(2026, 9, 2);
  final freigegeben = stufe == 'freigegeben' || stufe == 'bezahlt'
      ? DateTime(2026, 9, 5)
      : null;
  return Rechnung(
    id: id,
    userId: 'u',
    rechnungsnummer: 'RG-$id',
    rechnungstyp: typ,
    rechnungsdatum: DateTime(2026, 9, 1),
    faelligkeitsdatum: DateTime(2026, 9, 30),
    betragNetto: brutto / 1.081,
    mwstBetrag: brutto - brutto / 1.081,
    betragBrutto: brutto,
    zahlungsstatus: stufe == 'bezahlt' || stufe == 'abgeschrieben'
        ? stufe
        : 'offen',
    mahnungStufe: stufe == 'gemahnt' ? 2 : 0,
    versendetAm: versendet,
    freigegebenAm: freigegeben,
  );
}

Buchung bu({
  String belegTyp = 'rechnung',
  String? belegId = 'h1',
  int soll = 1100,
  int haben = 3400,
  bool storniert = false,
  String? stornoVonId,
}) => Buchung(
  id: 'b-$belegTyp-$haben',
  userId: 'u',
  datum: DateTime(2026, 9, 1),
  sollKonto: soll,
  habenKonto: haben,
  betragNetto: 100,
  betragBrutto: 108.1,
  beschreibung: 'x',
  belegTyp: belegTyp,
  belegId: belegId,
  geschaeftsjahr: 2026,
  istStorniert: storniert,
  stornoVonId: stornoVonId,
);

void main() {
  group('heinekenZahlbar', () {
    test('nur eine freigegebene Heineken-Monatsrechnung ist zahlbar', () {
      expect(heinekenZahlbar(hr('freigegeben')), isTrue);
    });

    test('gesendet/offen sind NICHT zahlbar (Freigabe fehlt)', () {
      expect(heinekenZahlbar(hr('gesendet')), isFalse);
      expect(heinekenZahlbar(hr('offen')), isFalse);
    });

    test('bezahlt ist ausgeschlossen', () {
      expect(heinekenZahlbar(hr('bezahlt')), isFalse);
    });

    test('Kundenrechnung ist nie eine zahlbare Heineken-Rechnung', () {
      expect(heinekenZahlbar(hr('freigegeben', typ: 'kundenrechnung')),
          isFalse);
    });

    test('Migration 211: Freigabe nur aus freigegeben_am, nie aus dem Status',
        () {
      // Ein Altwert «freigegeben» ohne Feld (vor 211) zählt nicht.
      final alt = Rechnung(
        id: 'h1',
        userId: 'u',
        rechnungstyp: 'heineken_monat',
        rechnungsdatum: DateTime(2026, 9, 1),
        faelligkeitsdatum: DateTime(2026, 9, 30),
        zahlungsstatus: 'freigegeben',
      );
      expect(heinekenZahlbar(alt), isFalse);
    });
  });

  group('heinekenSperrgrund (M2, frisch gelesen vor dem Buchen)', () {
    test('freigegeben → kein Sperrgrund', () {
      expect(heinekenSperrgrund(hr('freigegeben')), isNull);
    });
    test('gesendet → gesperrt, Meldung nennt Freigabe', () {
      expect(heinekenSperrgrund(hr('gesendet')), contains('nicht freigegeben'));
    });
    test('bezahlt → gesperrt', () {
      expect(heinekenSperrgrund(hr('bezahlt')), contains('schon bezahlt'));
    });
    test('gelöscht → gesperrt', () {
      expect(heinekenSperrgrund(null), isNotNull);
    });
  });

  group('zuordnungGesperrt (M3, Frisch-Prüfung im Forderungsabgleich)', () {
    test('offene Kundenrechnung ist frei', () {
      expect(zuordnungGesperrt(hr('offen', typ: 'kundenrechnung')), isFalse);
      expect(
        zuordnungGesperrt(hr('gemahnt', typ: 'jahresrechnung')),
        isFalse,
      );
    });
    test('bezahlt, abgeschrieben, weg oder Heineken → gesperrt', () {
      expect(zuordnungGesperrt(hr('bezahlt', typ: 'kundenrechnung')), isTrue);
      expect(
        zuordnungGesperrt(hr('abgeschrieben', typ: 'kundenrechnung')),
        isTrue,
      );
      expect(zuordnungGesperrt(null), isTrue);
      expect(zuordnungGesperrt(hr('freigegeben')), isTrue);
    });
  });

  group('HeinekenMatcher', () {
    test('eine gesendete Rechnung wird trotz passendem Betrag nicht getroffen',
        () {
      final m = HeinekenMatcher.match(
        zahlbetrag: 13966.09,
        heinekenRechnungen: [hr('gesendet')],
      );
      expect(m, isNull);
    });

    test('die freigegebene Rechnung wird getroffen', () {
      final m = HeinekenMatcher.match(
        zahlbetrag: 13966.09,
        heinekenRechnungen: [hr('gesendet', id: 'h0'), hr('freigegeben')],
      );
      expect(m?.id, 'h1');
    });
  });

  group('hatHeinekenErtragsbuchung', () {
    test('Buchung 1100/3400 mit beleg_typ rechnung zählt', () {
      expect(hatHeinekenErtragsbuchung([bu()], 'h1'), isTrue);
    });

    test('nur Zahlungseingang 1020/1100 zählt nicht', () {
      expect(
        hatHeinekenErtragsbuchung(
          [bu(belegTyp: 'zahlung', soll: 1020, haben: 1100)],
          'h1',
        ),
        isFalse,
      );
    });

    test('stornierte Buchung und Storno-Gegenbuchung zählen nicht', () {
      expect(hatHeinekenErtragsbuchung([bu(storniert: true)], 'h1'), isFalse);
      expect(hatHeinekenErtragsbuchung([bu(stornoVonId: 'x')], 'h1'), isFalse);
    });

    test('Buchung einer anderen Rechnung zählt nicht', () {
      expect(hatHeinekenErtragsbuchung([bu(belegId: 'h2')], 'h1'), isFalse);
    });
  });

  group('freigabeRuecknahmeSperre («Auf gesendet zurücksetzen»)', () {
    test('ohne Buchungen: darf', () {
      expect(freigabeRuecknahmeSperre(const [], 'h1'), isNull);
    });
    test('Zahlungsbuchung sperrt', () {
      expect(
        freigabeRuecknahmeSperre(
          [bu(belegTyp: 'zahlung', soll: 1020, haben: 1100)],
          'h1',
        ),
        contains('Zahlung'),
      );
    });
    test('stornierte Zahlung sperrt nicht', () {
      expect(
        freigabeRuecknahmeSperre(
          [bu(belegTyp: 'zahlung', soll: 1020, haben: 1100, storniert: true)],
          'h1',
        ),
        isNull,
      );
    });
    test('aktive Ertragsbuchung sperrt (M5)', () {
      expect(freigabeRuecknahmeSperre([bu()], 'h1'), contains('Ertragsbuchung'));
    });
  });

  group('HeinekenBuchungService.freigeben', () {
    test('erst buchen, dann freigegeben_am setzen (kein Status mehr)',
        () async {
      final ablauf = <String>[];
      Map<String, dynamic>? gesetzt;
      await HeinekenBuchungService.freigeben(
        hr('gesendet'),
        buchen: (r) async {
          ablauf.add('buchen');
          return bu();
        },
        statusSetzen: (id, daten) async {
          ablauf.add('freigabe');
          gesetzt = daten;
        },
        jetzt: DateTime.utc(2026, 9, 27, 10),
      );
      expect(ablauf, ['buchen', 'freigabe']);
      expect(gesetzt, {'freigegeben_am': '2026-09-27T10:00:00.000Z'});
      expect(gesetzt!.containsKey('zahlungsstatus'), isFalse);
    });

    test('scheitert die Buchung, bleibt der Status stehen', () async {
      var statusGesetzt = false;
      await expectLater(
        HeinekenBuchungService.freigeben(
          hr('gesendet'),
          buchen: (r) async => throw Exception('Netz weg'),
          statusSetzen: (id, daten) async => statusGesetzt = true,
        ),
        throwsException,
      );
      expect(statusGesetzt, isFalse);
    });

    test('Buchung existiert schon (null) → Status wird trotzdem gesetzt',
        () async {
      var statusGesetzt = false;
      await HeinekenBuchungService.freigeben(
        hr('gesendet'),
        buchen: (r) async => null,
        statusSetzen: (id, daten) async => statusGesetzt = true,
      );
      expect(statusGesetzt, isTrue);
    });
  });
}
