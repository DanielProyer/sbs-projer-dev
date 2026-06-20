import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_regel.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/services/camt/camt_auto_booker.dart';
import 'package:sbs_projer_app/services/camt/camt_vorschlag.dart';

CamtTransaction _belastung(
        {required double amt, String? party, String? addtl, String? remit}) =>
    CamtTransaction(
      amount: amt,
      currency: 'CHF',
      isCredit: false,
      bookingDate: DateTime(2026, 4, 1),
      partyName: party,
      additionalInfo: addtl,
      remittanceInfo: remit,
      txKey: '$party-$amt-$addtl',
    );

void main() {
  final vorlage = BuchungsVorlage(
      id: 'v1',
      userId: 'u',
      geschaeftsfallId: 'g',
      bezeichnung: 'Büromiete',
      sollKonto: 6000,
      habenKonto: 1020);
  final vorlagenById = {'v1': vorlage};
  final regeln = [
    CamtRegel(
        bezeichnung: 'Büromiete',
        matchName: 'Miete Büro',
        buchungsVorlageId: 'v1',
        prioritaet: 20),
  ];

  test('Ausgabe mit Regel-Treffer → Vorschlag (nicht gebucht)', () {
    final r = CamtAutoBooker.plan(
      transactions: [
        _belastung(amt: 250, party: 'Daniel Proyer', remit: 'Miete Büro SBS')
      ],
      heinekenRechnungen: [],
      regeln: regeln,
      vorlagenById: vorlagenById,
    );
    expect(r.vorschlaege.length, 1);
    expect(r.vorschlaege.first.typ, CamtVorschlagTyp.ausgabe);
    expect(r.vorschlaege.first.vorlage!.sollKonto, 6000);
    expect(r.pruefliste, isEmpty);
  });

  test('Ausgabe ohne Regel → Prüfliste', () {
    final r = CamtAutoBooker.plan(
      transactions: [_belastung(amt: 99, party: 'Unbekannt AG')],
      heinekenRechnungen: [],
      regeln: regeln,
      vorlagenById: vorlagenById,
    );
    expect(r.vorschlaege, isEmpty);
    expect(r.pruefliste.length, 1);
  });

  test('Saldovortrag → übersprungen', () {
    final r = CamtAutoBooker.plan(
      transactions: [_belastung(amt: 0, addtl: 'Saldovortrag')],
      heinekenRechnungen: [],
      regeln: regeln,
      vorlagenById: vorlagenById,
    );
    expect(r.uebersprungen, 1);
    expect(r.vorschlaege, isEmpty);
    expect(r.pruefliste, isEmpty);
  });
}
