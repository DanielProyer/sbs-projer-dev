import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';

Rechnung _rg(String id, String betriebId, double betrag) => Rechnung(
      id: id, userId: 'u', rechnungsnummer: id, rechnungstyp: 'kundenrechnung',
      betriebId: betriebId, rechnungsdatum: DateTime(2025, 1, 1),
      faelligkeitsdatum: DateTime(2025, 2, 1), betragNetto: betrag, mwstBetrag: 0,
      betragBrutto: betrag, zahlungsstatus: 'offen');

CamtTransaction _gut(double amt, String party, [String? info]) => CamtTransaction(
      amount: amt, currency: 'CHF', isCredit: true, bookingDate: DateTime(2026, 1, 5),
      partyName: party, additionalInfo: info, txKey: '$party-$amt');

void main() {
  final betriebe = [
    {'id': 'b1', 'name': 'Hotel Alpina'},
    {'id': 'b2', 'name': 'Gastro Latina GmbH'},
  ];

  test('eindeutige Einzelzahlung → auto', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.length, 1);
    expect(r.auto.first.forderungen.single.id, 'r1');
    expect(r.auto.first.gutschrift.amount, 67.85);
    expect(r.manuell, isEmpty);
    expect(r.keineZahlung, isEmpty);
  });

  test('Sammelzahlung über zwei Forderungen → auto', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(135.70, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85), _rg('r2', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.length, 1);
    expect(r.auto.first.forderungen.map((f) => f.id).toSet(), {'r1', 'r2'});
  });

  test('Zahlername aus AddtlNtryInf wird genutzt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(50.0, '', 'Gutschrift Gastro Latina GmbH')],
      offeneForderungen: [_rg('r3', 'b2', 50.0)],
      betriebe: betriebe,
    );
    expect(r.auto.single.forderungen.single.id, 'r3');
  });

  test('kein Betrieb-Match → Gutschrift ignoriert, Forderung bleibt offen', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(99.0, 'Unbekannt AG')],
      offeneForderungen: [_rg('r4', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto, isEmpty);
    expect(r.keineZahlung.single.id, 'r4');
  });

  test('Betrieb mit offener Forderung, Betrag passt nicht → manuell', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(40.0, 'Hotel Alpina')],
      offeneForderungen: [_rg('r5', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto, isEmpty);
    expect(r.manuell.single.betriebId, 'b1');
    expect(r.manuell.single.gutschriften.single.amount, 40.0);
    expect(r.manuell.single.forderungen.single.id, 'r5');
  });

  test('Gutschrift nur einmal verbraucht', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85), _rg('r2', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto, isEmpty);
    expect(r.manuell.single.forderungen.length, 2);
  });

  test('Gutschrift ohne offene Forderung wird verworfen', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: const [], // keine offene Forderung für b1 (oder irgendeinen Betrieb)
      betriebe: betriebe,
    );
    expect(r.auto, isEmpty);
    expect(r.manuell, isEmpty);
    expect(r.keineZahlung, isEmpty);
  });

  test('ein Treffer auto, übrige Gutschrift → manuell', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina'), _gut(99.0, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85), _rg('r2', 'b1', 40.0)],
      betriebe: betriebe,
    );
    // 67.85 matcht eindeutig r1 → auto; 99.0 matcht keine (Rest-)Forderung → manuell.
    expect(r.auto.length, 1);
    expect(r.auto.single.forderungen.map((f) => f.id).toSet(), {'r1'});
    expect(r.manuell.length, 1);
    expect(r.manuell.single.betriebId, 'b1');
    expect(r.manuell.single.gutschriften.map((g) => g.amount), contains(99.0));
    expect(r.manuell.single.forderungen.map((f) => f.id), contains('r2'));
    expect(r.keineZahlung, isEmpty);
  });

  test('alle Gutschriften verbraucht, Forderung bleibt → keineZahlung', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85), _rg('r2', 'b1', 40.0)],
      betriebe: betriebe,
    );
    expect(r.auto.length, 1);
    expect(r.auto.single.forderungen.map((f) => f.id).toSet(), {'r1'});
    expect(r.manuell, isEmpty);
    expect(r.keineZahlung.map((f) => f.id), contains('r2'));
  });

  test('benannte Gutschrift ohne Betrieb-Match → unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(99.0, 'Unbekannt AG')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.unbekannteGutschriften.single.amount, 99.0);
    expect(r.auto, isEmpty);
    expect(r.keineZahlung.single.id, 'r1');
  });

  test('Betrieb ohne offene Forderung, Gutschrift vorhanden → unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(50.0, 'Gastro Latina GmbH')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.unbekannteGutschriften.single.amount, 50.0);
  });

  test('Rest-Gutschrift nach Auto-Match (Forderungen leer) → unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina'), _gut(200.0, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.single.forderungen.single.id, 'r1');
    expect(r.unbekannteGutschriften.single.amount, 200.0);
  });

  test('namenlose Gutschrift (Saldovortrag) → NICHT unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(10.0, '', 'Saldovortrag')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.unbekannteGutschriften, isEmpty);
  });

  test('zugeordnete (auto) Gutschrift nicht doppelt in unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.single.gutschrift.amount, 67.85);
    expect(r.unbekannteGutschriften, isEmpty);
  });
}
