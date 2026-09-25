import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/buchhaltung/heineken_buchung_service.dart';
import 'package:sbs_projer_app/services/camt/heineken_matcher.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart'
    show zuordnungGesperrt;

/// R3 (App-Analyse 25.09.2026): Die Heineken-Freigabe darf nicht übersprungen
/// werden — sonst fehlt die Ertragsbuchung 1100/3400 für immer.

Rechnung hr(
  String status, {
  String id = 'h1',
  double brutto = 13966.09,
  String typ = 'heineken_monat',
}) => Rechnung(
  id: id,
  userId: 'u',
  rechnungsnummer: 'RG-$id',
  rechnungstyp: typ,
  rechnungsdatum: DateTime(2026, 9, 1),
  faelligkeitsdatum: DateTime(2026, 9, 30),
  betragNetto: brutto / 1.081,
  mwstBetrag: brutto - brutto / 1.081,
  betragBrutto: brutto,
  zahlungsstatus: status,
);

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
        zuordnungGesperrt(hr('mahnung_1', typ: 'jahresrechnung')),
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

  group('HeinekenBuchungService.freigeben', () {
    test('erst buchen, dann Status setzen', () async {
      final ablauf = <String>[];
      await HeinekenBuchungService.freigeben(
        hr('gesendet'),
        buchen: (r) async {
          ablauf.add('buchen');
          return bu();
        },
        statusSetzen: (id, daten) async {
          ablauf.add('status:${daten['zahlungsstatus']}');
        },
      );
      expect(ablauf, ['buchen', 'status:freigegeben']);
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
