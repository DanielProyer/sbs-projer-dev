import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/services/camt/camt_auto_booker.dart';
import 'package:sbs_projer_app/services/camt/camt_vorschlag.dart';

CamtTransaction _dbit() => CamtTransaction(
      amount: 100,
      currency: 'CHF',
      isCredit: false,
      bookingDate: DateTime(2026, 6, 20),
      txKey: 'K1',
      partyIban: 'CH9300762011623852957',
      partyName: 'Lieferant X',
      additionalInfo: 'Lieferant X',
    );

Eingangsrechnung _kreditor() => Eingangsrechnung(
      id: 'e1',
      userId: 'u',
      lieferantIban: 'CH9300762011623852957',
      betragBrutto: 100,
      ausstellerName: 'Lieferant X',
      status: 'exportiert',
      buchungStufe1Id: 'b1',
    );

void main() {
  test('DBIT + offene Eingangsrechnung -> Kreditor-Vorschlag', () {
    final r = CamtAutoBooker.plan(
      transactions: [_dbit()],
      heinekenRechnungen: [],
      regeln: [],
      vorlagenById: {},
      offeneKreditoren: [_kreditor()],
    );
    expect(r.vorschlaege.length, 1);
    expect(r.vorschlaege.first.typ, CamtVorschlagTyp.kreditor);
    expect(r.vorschlaege.first.eingangsrechnung?.id, 'e1');
    expect(r.pruefliste, isEmpty);
  });

  test('DBIT ohne Kandidat -> Prüfliste, kein Kreditor-Vorschlag', () {
    final r = CamtAutoBooker.plan(
      transactions: [_dbit()],
      heinekenRechnungen: [],
      regeln: [],
      vorlagenById: {},
      offeneKreditoren: [],
    );
    expect(
        r.vorschlaege.where((v) => v.typ == CamtVorschlagTyp.kreditor), isEmpty);
    expect(r.pruefliste.length, 1);
  });

  test('zwei Belastungen, EINE Rechnung -> 1 Vorschlag + zweite in Prüfliste',
      () {
    // Dedup: dieselbe Rechnung darf nicht zweimal zugeordnet werden.
    final tx1 = _dbit();
    final tx2 = CamtTransaction(
      amount: 100,
      currency: 'CHF',
      isCredit: false,
      bookingDate: DateTime(2026, 6, 21),
      txKey: 'K2',
      partyIban: 'CH9300762011623852957',
      partyName: 'Lieferant X',
      additionalInfo: 'Lieferant X',
    );
    final r = CamtAutoBooker.plan(
      transactions: [tx1, tx2],
      heinekenRechnungen: [],
      regeln: [],
      vorlagenById: {},
      offeneKreditoren: [_kreditor()],
    );
    expect(r.vorschlaege.where((v) => v.typ == CamtVorschlagTyp.kreditor).length,
        1);
    expect(r.pruefliste.length, 1); // zweite Belastung -> manuell
  });
}
