import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';

CamtTransaction _gut({
  required double betrag,
  String? name,
  String? ref,
  String? vermerk,
  String txKey = 't1',
}) =>
    CamtTransaction(
      amount: betrag,
      currency: 'CHF',
      isCredit: true,
      bookingDate: DateTime(2026, 4, 10),
      txKey: txKey,
      partyName: name,
      strukturierteReferenz: ref,
      remittanceInfo: vermerk,
    );

Rechnung _ford({
  required String id,
  required String betriebId,
  required double betrag,
  String? qr,
}) =>
    Rechnung(
      id: id,
      userId: 'u',
      rechnungstyp: 'kundenrechnung',
      rechnungsdatum: DateTime(2026, 4, 1),
      faelligkeitsdatum: DateTime(2026, 5, 1),
      betriebId: betriebId,
      betragBrutto: betrag,
      qrReferenz: qr,
    );

void main() {
  final betriebe = [
    {'id': 'b_edel', 'name': 'Edelweiss', 'ort': 'Vals', 'aliase': '', 'nr': ''},
    {'id': 'b_alp', 'name': 'Hotel Alpina', 'ort': 'Chur', 'aliase': 'alpina gastro ag', 'nr': ''},
    {'id': 'b_dk', 'name': 'Bergrestaurant Weissfluh', 'ort': 'Davos', 'aliase': '', 'nr': '0151'},
  ];

  test('exakter Name + eindeutiger Betrag → AUTO', () {
    final erg = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(betrag: 100, name: 'Hotel Alpina')],
      offeneForderungen: [_ford(id: 'r1', betriebId: 'b_alp', betrag: 100)],
      betriebe: betriebe,
    );
    expect(erg.auto.length, 1);
    expect(erg.auto.first.forderungen.first.id, 'r1');
    expect(erg.manuell, isEmpty);
  });

  test('gelernter Alias + eindeutiger Betrag → AUTO', () {
    final erg = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(betrag: 100, name: 'Alpina Gastro AG')],
      offeneForderungen: [_ford(id: 'r1', betriebId: 'b_alp', betrag: 100)],
      betriebe: betriebe,
    );
    expect(erg.auto.length, 1);
    expect(erg.manuell, isEmpty);
  });

  test('UNSCHARFER Name (Betreiber) → NICHT auto, sondern MANUELL', () {
    // „Edelweiss Davos AG" enthält „Edelweiss" → findBestMatch träfe Vals,
    // darf aber NICHT automatisch verbucht werden.
    final erg = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(betrag: 138.35, name: 'Edelweiss Davos AG')],
      offeneForderungen: [_ford(id: 'r2', betriebId: 'b_edel', betrag: 138.35)],
      betriebe: betriebe,
    );
    expect(erg.auto, isEmpty);
    expect(erg.manuell.length, 1);
    expect(erg.manuell.first.betriebId, 'b_edel');
    expect(erg.manuell.first.forderungen.first.id, 'r2');
  });

  test('Betreiber-Sammelzahlung: Vermerk-Betriebnummer routet → MANUELL', () {
    // „Davos Klosters Bergbahnen" matcht keinen Betriebsnamen, aber der Vermerk
    // „0151_2026_04_04" nennt die Betriebnummer → Betrieb b_dk, manuell.
    final erg = ForderungsAbgleichService.abgleich(
      gutschriften: [
        _gut(betrag: 200, name: 'Davos Klosters Bergbahnen AG', vermerk: '0151_2026_04_04'),
      ],
      offeneForderungen: [_ford(id: 'r_dk', betriebId: 'b_dk', betrag: 200)],
      betriebe: betriebe,
    );
    expect(erg.auto, isEmpty);
    expect(erg.manuell.length, 1);
    expect(erg.manuell.first.betriebId, 'b_dk');
  });

  test('QR-/SCOR-Referenz → AUTO (unabhängig vom Namen)', () {
    const ref = '210000000003139471430009017';
    final erg = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(betrag: 55, name: 'Irgendwer AG', ref: ref)],
      offeneForderungen: [_ford(id: 'r3', betriebId: 'b_edel', betrag: 55, qr: ref)],
      betriebe: betriebe,
    );
    expect(erg.auto.length, 1);
    expect(erg.auto.first.forderungen.first.id, 'r3');
  });
}
