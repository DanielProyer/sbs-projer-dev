import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/rechnung/barzahlung_service.dart';

Rechnung _r({
  String status = 'mahnung_1',
  String? zahlungEingegangen,
  double? zahlungBetrag,
}) =>
    Rechnung.fromJson({
      'id': 'r1',
      'user_id': 'u',
      'rechnungsnummer': '2026-05-0001',
      'rechnungstyp': 'kundenrechnung',
      'betrieb_id': 'b1',
      'rechnungsdatum': '2026-05-01',
      'faelligkeitsdatum': '2026-05-31',
      'betrag_netto': 87.0,
      'mwst_betrag': 7.05,
      'betrag_brutto': 94.05,
      'zahlungsstatus': status,
      'mahnung_stufe': 1,
      'zahlung_eingegangen_am': zahlungEingegangen,
      'zahlung_betrag': zahlungBetrag,
    });

Buchung _b({
  String id = 'b1',
  int soll = 1000,
  int haben = 1100,
  String? weg = 'kasse',
  String? typ = 'zahlung',
  bool storniert = false,
  String? stornoVon,
}) =>
    Buchung.fromJson({
      'id': id,
      'user_id': 'u',
      'datum': '2026-09-24',
      'soll_konto': soll,
      'haben_konto': haben,
      'betrag_netto': 94.05,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': 94.05,
      'beschreibung': 'x',
      'zahlungsweg': weg,
      'beleg_typ': typ,
      'beleg_id': 'r1',
      'geschaeftsjahr': 2026,
      'ist_storniert': storniert,
      'storno_von_id': stornoVon,
    });

void main() {
  _meldungTests();
  _nachbesserungTests();
  group('vorherAusNotiz', () {
    test('gueltiges JSON aus vorherStand', () {
      final notiz = jsonEncode({
        'zahlungsstatus': 'mahnung_1',
        'mahnung_stufe': 1,
        'letzte_mahnung_am': '2026-07-20',
        'erinnerung_am': '2026-07-01',
        'mahnung_1_am': '2026-07-20',
        'mahnung_2_am': null,
        'mahn_frist_bis': '2026-07-30',
      });
      final v = BarzahlungService.vorherAusNotiz(notiz)!;
      expect(v['zahlungsstatus'], 'mahnung_1');
      expect(v['mahnung_1_am'], '2026-07-20');
      expect(v.containsKey('mahnung_2_am'), isTrue);
    });
    test('null, leer, kaputt, kein Objekt, ohne Status -> null', () {
      expect(BarzahlungService.vorherAusNotiz(null), isNull);
      expect(BarzahlungService.vorherAusNotiz(''), isNull);
      expect(BarzahlungService.vorherAusNotiz('{kaputt'), isNull);
      expect(BarzahlungService.vorherAusNotiz('[1,2]'), isNull);
      expect(BarzahlungService.vorherAusNotiz('{"mahnung_stufe":1}'), isNull);
      expect(BarzahlungService.vorherAusNotiz('{"zahlungsstatus":"bezahlt"}'), isNull);
    });
    test('fremde Schluessel werden verworfen', () {
      final v = BarzahlungService.vorherAusNotiz(
          '{"zahlungsstatus":"offen","betrag_brutto":0,"id":"x"}')!;
      expect(v.keys, ['zahlungsstatus']);
    });
  });

  group('darfKassieren', () {
    test('gemahnte offene Rechnung ohne Zahlung: ja', () {
      expect(BarzahlungService.darfKassieren(_r(), hatZahlung: false), isTrue);
    });
    test('bezahlt / abgeschrieben: nein', () {
      expect(BarzahlungService.darfKassieren(_r(status: 'bezahlt'), hatZahlung: false), isFalse);
      expect(BarzahlungService.darfKassieren(_r(status: 'abgeschrieben'), hatZahlung: false),
          isFalse);
    });
    test('gebuchte Zahlung: nein', () {
      expect(BarzahlungService.darfKassieren(_r(), hatZahlung: true), isFalse);
    });
    test('vermerkter Zahlungseingang oder -betrag: nein', () {
      expect(
          BarzahlungService.darfKassieren(_r(zahlungEingegangen: '2026-09-01'),
              hatZahlung: false),
          isFalse);
      expect(BarzahlungService.darfKassieren(_r(zahlungBetrag: 50), hatZahlung: false),
          isFalse);
    });
  });

  group('barzahlungAus', () {
    test('findet aktive Kassen-Zahlung 1000/1100', () {
      expect(BarzahlungService.barzahlungAus([_b()])?.id, 'b1');
    });
    test('Bank, Abschreibung, storniert, Storno-Gegenbuchung zaehlen nicht', () {
      expect(
        BarzahlungService.barzahlungAus([
          _b(id: 'bank', soll: 1020, weg: 'bank'),
          _b(id: 'abs', soll: 3805, typ: 'abschreibung', weg: 'intern'),
          _b(id: 'sto', storniert: true),
          _b(id: 'geg', stornoVon: 'sto'),
        ]),
        isNull,
      );
    });
  });

  test('kassierDatum ist ein UTC-Tag', () {
    final d = BarzahlungService.kassierDatum(DateTime(2026, 9, 24, 23, 30));
    expect(d, DateTime.utc(2026, 9, 24));
  });
}

void _nachbesserungTests() {
  group('kassierSperre (I-2)', () {
    test('bezahlt/abgeschrieben', () {
      expect(BarzahlungService.kassierSperre(_r(status: 'bezahlt'), hatZahlung: false),
          contains('bereits bezahlt/abgeschrieben'));
      expect(BarzahlungService.kassierSperre(_r(status: 'abgeschrieben'), hatZahlung: true),
          contains('bereits bezahlt/abgeschrieben'));
    });
    test('Zahlung gebucht, Rechnung nicht bezahlt -> Hinweis aufs Rechnungsdetail', () {
      expect(BarzahlungService.kassierSperre(_r(), hatZahlung: true),
          'Zahlung bereits gebucht (Rechnung noch nicht bezahlt) — im Rechnungsdetail prüfen');
    });
    test('vermerkter Zahlungseingang', () {
      expect(
          BarzahlungService.kassierSperre(_r(zahlungEingegangen: '2026-09-01'),
              hatZahlung: false),
          contains('im Rechnungsdetail prüfen'));
    });
    test('frei -> null', () {
      expect(BarzahlungService.kassierSperre(_r(), hatZahlung: false), isNull);
    });
  });

  test('kassierBetrag auf 5 Rappen (wie der Bankweg)', () {
    expect(BarzahlungService.kassierBetrag(94.07), 94.05);
    expect(BarzahlungService.kassierBetrag(94.08), 94.10);
  });

  group('fehlerText (I-1)', () {
    test('Teilfehler: X von Y kassiert (CHF …) — Grund', () {
      final f = BarzahlungFehler('Rechnung 2026-05-0002: wurde inzwischen geändert',
          kassiert: const [(nummer: '2026-05-0001', betrag: 1094.05)]);
      expect(BarzahlungService.fehlerText(f, gesamt: 3),
          "1 von 3 kassiert (CHF 1'094.05) — Rechnung 2026-05-0002: wurde inzwischen geändert");
    });
    test('nichts kassiert: nur der Grund', () {
      final f = BarzahlungFehler('Rechnung X: bereits bezahlt/abgeschrieben');
      expect(BarzahlungService.fehlerText(f, gesamt: 2),
          'Rechnung X: bereits bezahlt/abgeschrieben');
    });
  });

  group('rueckgaengigSperre (Minor a/b)', () {
    final heute = DateTime(2026, 9, 24);
    test('nur die Barzahlung, laufendes Jahr, bezahlt -> null', () {
      final bar = _b();
      expect(
          BarzahlungService.rueckgaengigSperre(
              bar: bar, buchungen: [bar], status: 'bezahlt', heute: heute),
          isNull);
    });
    test('weitere aktive Zahlung -> Sperre', () {
      final bar = _b();
      expect(
          BarzahlungService.rueckgaengigSperre(
              bar: bar,
              buchungen: [bar, _b(id: 'bank', soll: 1020, weg: 'bank')],
              status: 'bezahlt',
              heute: heute),
          contains('weitere Zahlung'));
    });
    test('stornierte weitere Zahlung und Abschreibung sperren nicht', () {
      final bar = _b();
      expect(
          BarzahlungService.rueckgaengigSperre(
              bar: bar,
              buchungen: [
                bar,
                _b(id: 's', soll: 1020, weg: 'bank', storniert: true),
                _b(id: 'a', soll: 3805, typ: 'abschreibung', weg: 'intern'),
              ],
              status: 'bezahlt',
              heute: heute),
          isNull);
    });
    test('Vorjahr -> Storno von Hand', () {
      final bar = _b();
      expect(
          BarzahlungService.rueckgaengigSperre(
              bar: bar, buchungen: [bar], status: 'bezahlt', heute: DateTime(2027, 1, 3)),
          'Barzahlung aus abgeschlossenem Jahr — Storno von Hand in der Buchhaltung');
    });
    test('nicht mehr bezahlt -> Sperre', () {
      final bar = _b();
      expect(
          BarzahlungService.rueckgaengigSperre(
              bar: bar, buchungen: [bar], status: 'mahnung_1', heute: heute),
          contains('nicht mehr bezahlt'));
    });
  });
}

void _meldungTests() {
  test('meldungFuer: BarzahlungFehler ungekuerzt, sonst kurzeFehlermeldung', () {
    final lang = 'x' * 120;
    expect(BarzahlungService.meldungFuer(BarzahlungFehler(lang)), lang);
    expect(BarzahlungService.meldungFuer(Exception('ClientException: Failed to fetch')),
        'keine Verbindung');
  });
}
