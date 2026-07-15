import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/services/camt/pruefliste_buchung.dart';

CamtPrueflisteEintrag _e({
  String? iban = 'CH0430000001700007355',
  String? belegRef = 'ZV20260505/864008/3',
  bool gutschrift = false,
}) =>
    CamtPrueflisteEintrag(
      id: 'p1',
      txKey: 'tx-flims',
      bookingDatum: DateTime(2026, 5, 5),
      betrag: 40.00,
      istGutschrift: gutschrift,
      parteiName: 'Gemeinde Flims',
      parteiIban: iban,
      belegRef: belegRef,
      referenz: '000000000000009679010653954',
      kategorie: 'ausgabe',
    );

void main() {
  test('überträgt alle für die Buchung nötigen Felder', () {
    final tx = txAusPrueflisteEintrag(_e());
    expect(tx.amount, 40.00);
    expect(tx.bookingDate, DateTime(2026, 5, 5));
    expect(tx.isCredit, isFalse);
    expect(tx.partyName, 'Gemeinde Flims');
    expect(tx.partyIban, 'CH0430000001700007355');
    expect(tx.accountServiceRef, 'ZV20260505/864008/3');
    expect(tx.strukturierteReferenz, '000000000000009679010653954');
  });

  test('txKey bleibt erhalten — sonst greift der Dedup nicht', () {
    // Der txKey ist der einzige Anker, über den die Buchung später wieder
    // gefunden (und zurückgerollt) werden kann.
    expect(txAusPrueflisteEintrag(_e()).txKey, 'tx-flims');
  });

  test('Alt-Eintrag ohne IBAN/Beleg-Referenz ist trotzdem buchbar', () {
    // Einträge aus der Zeit vor Migration 142 haben beide Felder nicht.
    final tx = txAusPrueflisteEintrag(_e(iban: null, belegRef: null));
    expect(tx.partyIban, isNull);
    expect(tx.accountServiceRef, isNull);
    expect(tx.amount, 40.00);
    expect(tx.txKey, 'tx-flims');
  });

  test('Gutschrift behält ihre Richtung', () {
    expect(txAusPrueflisteEintrag(_e(gutschrift: true)).isCredit, isTrue);
  });
}
