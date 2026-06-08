import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/services/camt/camt_klassifizierer.dart';

CamtTransaction _tx({required bool credit, String? name, String? addtl, double amt = 100}) =>
    CamtTransaction(amount: amt, currency: 'CHF', isCredit: credit,
      bookingDate: DateTime(2026, 7, 10), partyAddressLines: const [],
      partyName: name, additionalInfo: addtl, txKey: 'k');

void main() {
  test('Heineken-Eingang → heinekenEingang', () {
    expect(CamtKlassifizierer.kategorie(_tx(credit: true, name: 'HEINEKEN SWITZERLAND AG'),
        betriebErkannt: false), TxKategorie.heinekenEingang);
  });
  test('Bargeld → bargeldEinzahlung', () {
    expect(CamtKlassifizierer.kategorie(
        _tx(credit: true, addtl: 'Geldautomaten Einzahlung GKB'), betriebErkannt: false),
        TxKategorie.bargeldEinzahlung);
  });
  test('Saldovortrag → saldovortrag', () {
    expect(CamtKlassifizierer.kategorie(_tx(credit: true, addtl: 'Saldovortrag'),
        betriebErkannt: false), TxKategorie.saldovortrag);
  });
  test('Eingang mit Betrieb → kundenzahlung', () {
    expect(CamtKlassifizierer.kategorie(_tx(credit: true, name: 'Hotel Rovanada AG'),
        betriebErkannt: true), TxKategorie.kundenzahlung);
  });
  test('Eingang ohne Betrieb → unbekannt', () {
    expect(CamtKlassifizierer.kategorie(_tx(credit: true, name: 'Irgendwer'),
        betriebErkannt: false), TxKategorie.unbekannt);
  });
  test('Ausgang → ausgabe', () {
    expect(CamtKlassifizierer.kategorie(_tx(credit: false, name: 'Swisscom AG'),
        betriebErkannt: false), TxKategorie.ausgabe);
  });
}
