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
  String? nr,
}) =>
    Rechnung(
      id: id,
      userId: 'u',
      rechnungsnummer: nr,
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
    {'id': 'b_dk', 'name': 'Armando', 'ort': 'Klosters', 'aliase': '', 'nr': '21', 'heineken_nr': '0151'},
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

  test('Bemerkung nennt Rechnungsnummer → Routing zum richtigen Betrieb (manuell)', () {
    // Davos Klosters Bergbahnen zahlt für Bolgen Plaza, Bemerkung enthält die
    // Rechnungsnummer 2026-04-0505 → Forderung r_bp → Betrieb b_bp.
    final erg = ForderungsAbgleichService.abgleich(
      gutschriften: [
        _gut(betrag: 145.95, name: 'Davos Klosters Bergbahnen AG', vermerk: '01.05.2026 2026-04-0505'),
      ],
      offeneForderungen: [
        _ford(id: 'r_bp', betriebId: 'b_bp', betrag: 145.95, nr: '2026-04-0505'),
      ],
      betriebe: [
        ...betriebe,
        {'id': 'b_bp', 'name': 'Bolgen Plaza', 'ort': 'Davos', 'aliase': '', 'nr': '26'},
      ],
    );
    expect(erg.auto, isEmpty);
    expect(erg.manuell.length, 1);
    expect(erg.manuell.first.betriebId, 'b_bp');
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

  test('Sammelzahler (Weisse Arena/Davos Klosters) nie AUTO — auch mit gelerntem Alias', () {
    // «Weisse Arena Hospitality AG» zahlt für mehrere Objekte. Selbst wenn ein
    // Alias auf einen Betrieb gelernt wurde, darf der Alias-Pfad nicht
    // automatisch verbuchen — die Zahlung gehört evtl. einem Schwester-Objekt.
    final betriebeMitAlias = [
      {'id': 'b_ikigai', 'name': 'IKIGAI', 'ort': 'Laax', 'aliase': 'weisse arena hospitality ag', 'nr': ''},
    ];
    final erg = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(betrag: 250, name: 'Weisse Arena Hospitality AG')],
      offeneForderungen: [_ford(id: 'r9', betriebId: 'b_ikigai', betrag: 250)],
      betriebe: betriebeMitAlias,
    );
    expect(erg.auto, isEmpty);
    expect(erg.manuell.length, 1, reason: 'als Vorschlag in die manuelle Prüfung');
  });
}
