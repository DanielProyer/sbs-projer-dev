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
}
