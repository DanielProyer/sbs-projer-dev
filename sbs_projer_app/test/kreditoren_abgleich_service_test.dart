import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/kreditoren_abgleich_service.dart';

CamtTransaction _tx({
  bool isCredit = false,
  double amount = 100.0,
  String? ref,
  String? iban,
  String? name,
}) =>
    CamtTransaction(
      amount: amount,
      currency: 'CHF',
      isCredit: isCredit,
      bookingDate: DateTime(2026, 6, 20),
      txKey: 'K1',
      strukturierteReferenz: ref,
      partyIban: iban,
      partyName: name,
    );

Eingangsrechnung _er({
  String id = 'e1',
  String? ref,
  String? iban,
  String? name,
  double betrag = 100.0,
}) =>
    Eingangsrechnung(
      id: id,
      userId: 'u',
      qrReferenz: ref,
      lieferantIban: iban,
      ausstellerName: name,
      betragBrutto: betrag,
      status: 'exportiert',
      buchungStufe1Id: 'b1',
    );

void main() {
  test('Referenz (normalisiert) + Betrag -> Treffer', () {
    // QRR mit Leerzeichen vs. ohne -> nach scorRefNorm identisch
    final tx = _tx(ref: '21 00000 00000 03139 47143 00009', amount: 100);
    final e = _er(ref: '210000000000031394714300009', betrag: 100);
    expect(KreditorenAbgleichService.match(tx, [e])?.id, 'e1');
  });

  test('Gutschrift (CRDT) -> kein Treffer', () {
    final tx = _tx(isCredit: true, iban: 'CH9300762011623852957', amount: 100);
    final e = _er(iban: 'CH9300762011623852957', betrag: 100);
    expect(KreditorenAbgleichService.match(tx, [e]), isNull);
  });

  test('IBAN + Betrag -> Treffer (ohne Referenz)', () {
    final tx = _tx(iban: 'CH9300762011623852957', amount: 250);
    final e = _er(iban: 'CH93 0076 2011 6238 5295 7', betrag: 250);
    expect(KreditorenAbgleichService.match(tx, [e])?.id, 'e1');
  });

  test('IBAN passt, Betrag weicht ab -> kein Treffer', () {
    final tx = _tx(iban: 'CH9300762011623852957', amount: 250);
    final e = _er(iban: 'CH9300762011623852957', betrag: 999);
    expect(KreditorenAbgleichService.match(tx, [e]), isNull);
  });

  test('mehrdeutig (2x gleiche IBAN+Betrag) -> kein Auto-Treffer', () {
    final tx = _tx(iban: 'CH9300762011623852957', amount: 100);
    final a = _er(id: 'a', iban: 'CH9300762011623852957', betrag: 100);
    final b = _er(id: 'b', iban: 'CH9300762011623852957', betrag: 100);
    expect(KreditorenAbgleichService.match(tx, [a, b]), isNull);
  });

  test('Name (Substring) + Betrag -> Treffer (kein Ref/IBAN)', () {
    final tx = _tx(name: 'Heineken Switzerland AG', amount: 50);
    final e = _er(name: 'Heineken', betrag: 50);
    expect(KreditorenAbgleichService.match(tx, [e])?.id, 'e1');
  });

  test('kein Kriterium passt -> null', () {
    final tx = _tx(name: 'Fremd AG', iban: 'CH0000000000000000000', amount: 1);
    final e = _er(name: 'Heineken', iban: 'CH9300762011623852957', betrag: 50);
    expect(KreditorenAbgleichService.match(tx, [e]), isNull);
  });

  test('vorhandene aber abweichende Referenz -> KEIN IBAN-Fallthrough', () {
    // tx trägt eine Referenz, die zu keiner Rechnung passt; eine andere
    // Rechnung desselben Lieferanten hat zufällig gleiche IBAN+Betrag.
    final tx = _tx(
        ref: '21 00000 00000 09999 99999 99999',
        iban: 'CH9300762011623852957',
        amount: 100);
    final e = _er(
        ref: '210000000000031394714300009',
        iban: 'CH9300762011623852957',
        betrag: 100);
    expect(KreditorenAbgleichService.match(tx, [e]), isNull);
  });

  test('Name-False-Positive: Post matcht NICHT PostFinance', () {
    final tx = _tx(name: 'PostFinance AG', amount: 50);
    final e = _er(name: 'Post', betrag: 50);
    expect(KreditorenAbgleichService.match(tx, [e]), isNull);
  });

  test('Name token-basiert: voller Lieferantenname matcht', () {
    final tx = _tx(name: 'Garage Arpagaus AG Chur', amount: 80);
    final e = _er(name: 'Garage Arpagaus', betrag: 80);
    expect(KreditorenAbgleichService.match(tx, [e])?.id, 'e1');
  });
}
