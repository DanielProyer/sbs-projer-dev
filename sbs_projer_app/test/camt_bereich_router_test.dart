import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/services/camt/camt_bereich_router.dart';

CamtTransaction _tx({required bool credit, String? party, String? addtl}) =>
    CamtTransaction(
      amount: 50, currency: 'CHF', isCredit: credit,
      bookingDate: DateTime(2026, 4, 1), partyName: party,
      additionalInfo: addtl, txKey: '$party-$addtl-$credit');

void main() {
  test('benannte Gutschrift → Kandidat', () {
    expect(istKundenzahlungsKandidat(_tx(credit: true, party: 'Hotel Alpina')), isTrue);
  });
  test('Gutschrift ohne Name (Abgleich findet via additionalInfo) → Kandidat', () {
    expect(istKundenzahlungsKandidat(
        _tx(credit: true, party: null, addtl: 'Gutschrift Bar Müller')), isTrue);
  });
  test('Belastung → kein Kandidat', () {
    expect(istKundenzahlungsKandidat(_tx(credit: false, party: 'Swisscom')), isFalse);
  });
  test('Geldautomaten-Einzahlung → kein Kandidat (Bargeld → Bereich 2)', () {
    expect(istKundenzahlungsKandidat(
        _tx(credit: true, addtl: 'Geldautomaten Einzahlung GKB')), isFalse);
  });
  test('Posteinzahlung → kein Kandidat', () {
    expect(istKundenzahlungsKandidat(_tx(credit: true, addtl: 'Posteinzahlung')), isFalse);
  });
  test('Heineken-Gutschrift → kein Kandidat', () {
    expect(istKundenzahlungsKandidat(_tx(credit: true, party: 'Heineken AG')), isFalse);
  });
  test('Saldovortrag → kein Kandidat', () {
    expect(istKundenzahlungsKandidat(_tx(credit: true, addtl: 'Saldovortrag')), isFalse);
  });
}
