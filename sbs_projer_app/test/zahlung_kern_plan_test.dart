import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlung_kern_plan.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

Rechnung _r(String id, double brutto,
        {double mwst = 0, double guthaben = 0, String status = 'gesendet', int stufe = 0}) =>
    Rechnung.fromJson({
      'id': id,
      'user_id': 'u',
      'rechnungsnummer': 'RG-$id',
      'rechnungstyp': 'kundenrechnung',
      'betrieb_id': 'b1',
      'rechnungsdatum': '2026-09-01',
      'faelligkeitsdatum': '2026-10-01',
      'betrag_netto': brutto - mwst,
      'mwst_betrag': mwst,
      'betrag_brutto': brutto,
      'zahlungsstatus': status,
      'mahnung_stufe': stufe,
      'guthaben_verrechnet': guthaben,
    });

void main() {
  final tag = DateTime(2026, 9, 26);

  test('exakte Bankzahlung: eine Zeile 1020/1100, Update mit tatsaechlichem Betrag', () {
    final p = zahlungKernPlan(
        rechnungen: [_r('a', 108.10, mwst: 8.10)], betrag: 108.10, datum: tag, weg: ZahlungWeg.bank);
    expect(p.buchungen.length, 1);
    expect(p.buchungen.single['soll_konto'], 1020);
    expect(p.buchungen.single['haben_konto'], 1100);
    expect(p.buchungen.single['betrag_brutto'], 108.10);
    expect(p.buchungen.single['beleg_typ'], 'zahlung');
    expect(p.updates['a']!['zahlung_betrag'], 108.10);
    expect(p.updates['a']!['zahlung_eingegangen_am'], '2026-09-26');
    expect(p.vorher['a']!['zahlungsstatus'], 'gesendet');
    expect(p.erwartet['a'], 'gesendet');
  });

  test('Kasse: Soll 1000, zahlungsweg kasse', () {
    final p = zahlungKernPlan(
        rechnungen: [_r('a', 94.05)], betrag: 94.05, datum: tag, weg: ZahlungWeg.kasse);
    expect(p.buchungen.single['soll_konto'], 1000);
    expect(p.buchungen.single['zahlungsweg'], 'kasse');
    // Mahn-Stand zusätzlich in der Notiz (Journal; Rücknahme nutzt zahlungsgruppen.vorher).
    expect(p.buchungen.single['notizen'], contains('"zahlungsstatus":"gesendet"'));
  });

  test('Minderzahlung: 3805 netto + 2200 MWST im Satz der Rechnung, Bank gekuerzt', () {
    final p = zahlungKernPlan(
        rechnungen: [_r('a', 108.10, mwst: 8.10)], betrag: 100.00, datum: tag, weg: ZahlungWeg.bank);
    final konten = p.buchungen.map((b) => '${b['soll_konto']}/${b['haben_konto']}').toList();
    expect(konten, ['1020/1100', '3805/1100', '2200/1100']);
    expect(p.buchungen[0]['betrag_brutto'], 100.00);
    expect((p.buchungen[1]['betrag_brutto'] as double) + (p.buchungen[2]['betrag_brutto'] as double),
        closeTo(8.10, 0.011));
    expect(p.buchungen[2]['betrag_brutto'], closeTo(0.61, 0.006));
    // view_entgeltsminderung (Migration 196) zaehlt nur beleg_typ 'abschreibung'.
    expect(p.buchungen[0]['beleg_typ'], 'zahlung');
    expect(p.buchungen[1]['beleg_typ'], 'abschreibung');
    expect(p.buchungen[2]['beleg_typ'], 'abschreibung');
    expect(p.updates['a']!['zahlung_betrag'], 108.10);
  });

  test('Minderzahlung ohne MWST auf der Rechnung: nur 3805', () {
    final p = zahlungKernPlan(
        rechnungen: [_r('a', 100.00)], betrag: 95.00, datum: tag, weg: ZahlungWeg.bank);
    expect(p.buchungen.map((b) => b['soll_konto']).toList(), [1020, 3805]);
    expect(p.buchungen[1]['betrag_brutto'], 5.00);
  });

  test('Mehrzahlung klein: 8000; gross: 2030 (Standard), Wahl ueberschreibt', () {
    final klein = zahlungKernPlan(
        rechnungen: [_r('a', 100.00)], betrag: 103.00, datum: tag, weg: ZahlungWeg.bank);
    expect(klein.buchungen.last['haben_konto'], 8000);
    expect(klein.buchungen.last['soll_konto'], 1020);
    expect(klein.mehrzahlungZiel, MehrzahlungZiel.aoErtrag);
    final gross = zahlungKernPlan(
        rechnungen: [_r('a', 100.00)], betrag: 130.00, datum: tag, weg: ZahlungWeg.bank);
    expect(gross.buchungen.last['haben_konto'], 2030);
    expect(gross.buchungen.last['beleg_typ'], 'zahlung');
    expect(gross.buchungen.last['beleg_id'], 'a');
    expect(gross.mehrzahlungZiel, MehrzahlungZiel.guthaben);
    final gewaehlt = zahlungKernPlan(
        rechnungen: [_r('a', 100.00)],
        betrag: 130.00,
        datum: tag,
        weg: ZahlungWeg.bank,
        mehrzahlung: MehrzahlungZiel.aoErtrag);
    expect(gewaehlt.buchungen.last['haben_konto'], 8000);
    expect(mehrzahlungStandard(5.00), MehrzahlungZiel.aoErtrag);
    expect(mehrzahlungStandard(5.05), MehrzahlungZiel.guthaben);
  });

  test('Guthaben verrechnet: 1020 ueber zu zahlen + 2030/1100, zahlung_betrag = Brutto', () {
    final p = zahlungKernPlan(
        rechnungen: [_r('a', 143.75, guthaben: 30)], betrag: 113.75, datum: tag, weg: ZahlungWeg.bank);
    final konten = p.buchungen.map((b) => '${b['soll_konto']}/${b['haben_konto']}').toList();
    expect(konten, ['1020/1100', '2030/1100']);
    expect(p.buchungen[0]['betrag_brutto'], 113.75);
    expect(p.buchungen[1]['betrag_brutto'], 30.00);
    expect(p.updates['a']!['zahlung_betrag'], 143.75);
  });

  test('Guthaben voll (Weg verrechnung): nur 2030/1100, zahlung_betrag 0, Datum = Rechnungsdatum', () {
    final p = zahlungKernPlan(
        rechnungen: [_r('a', 30.00, guthaben: 30)],
        betrag: 0,
        datum: DateTime(2026, 9, 26),
        weg: ZahlungWeg.verrechnung);
    expect(p.buchungen.single['soll_konto'], 2030);
    expect(p.buchungen.single['datum'], '2026-09-01');
    expect(p.updates['a']!['zahlung_betrag'], 0);
  });

  test('Sammelzahlung: Verlust von hinten, Differenzzeilen an der letzten Rechnung, Datum/Key je Rechnung', () {
    final p = zahlungKernPlan(
      rechnungen: [_r('a', 100.00), _r('b', 50.00)],
      betrag: 140.00,
      datum: tag,
      weg: ZahlungWeg.bank,
      datumProRechnung: {'b': DateTime(2026, 9, 20)},
      camtTxKeyProRechnung: {'a': 'tx1', 'b': 'tx2'},
    );
    expect(p.buchungen[0]['betrag_brutto'], 100.00);
    expect(p.buchungen[1]['betrag_brutto'], 40.00);
    expect(p.buchungen[1]['datum'], '2026-09-20');
    expect(p.buchungen[1]['camt_tx_key'], 'tx2');
    expect(p.buchungen[2]['soll_konto'], 3805);
    expect(p.buchungen[2]['beleg_id'], 'b');
    expect(p.updates['a']!['zahlung_betrag'], 100.00);
    expect(p.updates['b']!['zahlung_betrag'], 50.00);
    expect(p.camtTxKeys.toSet(), {'tx1', 'tx2'});
  });

  test('Vorher-Stand traegt Mahnfelder und Guthaben', () {
    final p = zahlungKernPlan(
        rechnungen: [_r('a', 100.00, status: 'mahnung_1', stufe: 2)],
        betrag: 100,
        datum: tag,
        weg: ZahlungWeg.kasse);
    expect(p.vorher['a']!['mahnung_stufe'], 2);
    expect(p.vorher['a']!.containsKey('mahn_frist_bis'), isTrue);
    expect(p.vorher['a']!['guthaben_verrechnet'], 0);
  });

  group('Bankbetrag rappengenau (Review Runde 3)', () {
    test('94.03 auf 94.05: Bankzeile 94.03, nur 3805 0.02, keine 2200-Zeile',
        () {
      final p = zahlungKernPlan(
          rechnungen: [_r('a', 94.05)], betrag: 94.03, datum: tag, weg: ZahlungWeg.bank);
      expect(p.buchungen.map((b) => b['soll_konto']).toList(), [1020, 3805]);
      expect(p.buchungen[0]['betrag_brutto'], closeTo(94.03, 1e-9));
      expect(p.buchungen[1]['betrag_brutto'], closeTo(0.02, 1e-9));
      expect(p.updates['a']!['zahlung_betrag'], closeTo(94.05, 1e-9));
    });

    test('94.07 auf 94.05: 1020 94.05 + Mehrzahlung 0.02 auf 8000', () {
      final p = zahlungKernPlan(
          rechnungen: [_r('a', 94.05)], betrag: 94.07, datum: tag, weg: ZahlungWeg.bank);
      final konten = p.buchungen.map((b) => '${b['soll_konto']}/${b['haben_konto']}').toList();
      expect(konten, ['1020/1100', '1020/8000']);
      expect(p.buchungen[0]['betrag_brutto'], closeTo(94.05, 1e-9));
      expect(p.buchungen[1]['betrag_brutto'], closeTo(0.02, 1e-9));
    });
  });

  test('Vollzahlung trotz Guthaben: keine 2030-Zeile, guthaben_verrechnet 0, Notiz an der Bankzeile',
      () {
    final p = zahlungKernPlan(
        rechnungen: [_r('a', 143.75, guthaben: 30)],
        betrag: 143.75,
        datum: tag,
        weg: ZahlungWeg.bank);
    expect(p.buchungen.length, 1);
    expect(p.buchungen.single['soll_konto'], 1020);
    expect(p.buchungen.single['haben_konto'], 1100);
    expect(p.updates['a']!['guthaben_verrechnet'], 0);
    expect(p.buchungen.single['notizen'], contains('"guthaben_verrechnet":30'));
  });

  test('94.05 / Zahlung 94.00: nur 1020 94.00 + 3805 0.05, keine 2200-Zeile',
      () {
    final p = zahlungKernPlan(
        rechnungen: [_r('a', 94.05)], betrag: 94.00, datum: tag, weg: ZahlungWeg.bank);
    expect(p.buchungen.map((b) => b['soll_konto']).toList(), [1020, 3805]);
    expect(p.buchungen[0]['betrag_brutto'], closeTo(94.00, 1e-9));
    expect(p.buchungen[1]['betrag_brutto'], closeTo(0.05, 1e-9));
  });

  test('Sammelzahlung: updates.keys entspricht den Ids aller Rechnungen', () {
    final p = zahlungKernPlan(
      rechnungen: [_r('a', 100.00), _r('b', 50.00), _r('c', 25.00)],
      betrag: 175.00,
      datum: tag,
      weg: ZahlungWeg.bank,
    );
    expect(p.updates.keys.toSet(), {'a', 'b', 'c'});
  });

  group('Heineken (ungerundet, Befund B2)', () {
    Rechnung hei(double brutto) => Rechnung.fromJson({
          'id': 'h',
          'user_id': 'u',
          'rechnungsnummer': 'HEI-1',
          'rechnungstyp': 'heineken_monat',
          'rechnungsdatum': '2026-08-31',
          'faelligkeitsdatum': '2026-09-30',
          'heineken_monat': '2026-08-01',
          'betrag_netto': 1000,
          'mwst_betrag': brutto - 1000,
          'betrag_brutto': brutto,
          'zahlungsstatus': 'freigegeben',
        });

    test('exakt auf den Rappen, keine 5-Rappen-Rundung, keine Differenz', () {
      final p = zahlungKernPlan(
          rechnungen: [hei(1081.02)], betrag: 1081.02, datum: tag,
          weg: ZahlungWeg.bank, camtTxKey: 'tx1');
      expect(p.buchungen.length, 1);
      final b = p.buchungen.single;
      expect(b['betrag_brutto'], 1081.02);
      expect(b['soll_konto'], 1020);
      expect(b['haben_konto'], 1100);
      expect(b['beschreibung'], 'Zahlungseingang Heineken 08/2026');
      expect(b['camt_tx_key'], 'tx1');
      expect(p.updates['h']!['zahlung_betrag'], 1081.02);
      expect(p.erwartet['h'], 'freigegeben');
      expect(p.camtTxKeys, ['tx1']);
      expect(p.differenz, 0);
    });

    test('abweichender Betrag, Sammlung oder Kasse: Fehler statt Plan', () {
      // Review Runde 3: lesbarer ZahlungPlanFehler statt roher ArgumentError.
      expect(() => zahlungKernPlan(rechnungen: [hei(1081.02)], betrag: 1081.00,
          datum: tag, weg: ZahlungWeg.bank), throwsA(isA<ZahlungPlanFehler>()));
      expect(() => zahlungKernPlan(rechnungen: [hei(1081.02), _r('a', 10)],
          betrag: 1091.02, datum: tag, weg: ZahlungWeg.bank), throwsA(isA<ZahlungPlanFehler>()));
      expect(() => zahlungKernPlan(rechnungen: [hei(1081.02)], betrag: 1081.02,
          datum: tag, weg: ZahlungWeg.kasse), throwsA(isA<ZahlungPlanFehler>()));
    });
  });
}
