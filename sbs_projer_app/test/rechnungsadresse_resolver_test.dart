import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/rechnungsadresse_resolver.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';

void main() {
  final betriebAdr = BetriebRechnungsadresse(
    id: 'a1', userId: 'u', betriebId: 'b1',
    objekt: 'Muster', strasse: 'Dorfstr', nr: '1', plz: '7000', ort: 'Chur',
  );

  test('kein Override → Betriebs-Adresse', () {
    expect(effektiveRechnungsadresse(null, betriebAdr)?.ort, 'Chur');
    expect(effektiveRechnungsadresse(<String, dynamic>{}, betriebAdr)?.ort, 'Chur');
  });

  test('Override gesetzt → Override-Adresse', () {
    final eff = effektiveRechnungsadresse(
      {'firma': 'Neue AG', 'objekt': 'Neu', 'strasse': 'Bahnhofstr',
       'nr': '9', 'plz': '8000', 'ort': 'Zürich', 'email': 'x@y.ch'},
      betriebAdr,
      betriebId: 'b1',
    );
    expect(eff?.firma, 'Neue AG');
    expect(eff?.ort, 'Zürich');
    expect(eff?.email, 'x@y.ch');
    expect(eff?.betriebId, 'b1');
  });

  test('Snapshot round-trip (toAdressSnapshot → fromAdressSnapshot)', () {
    final snap = betriebAdr.toAdressSnapshot();
    final back = BetriebRechnungsadresse.fromAdressSnapshot(snap);
    expect(back.objekt, 'Muster');
    expect(back.plz, '7000');
    expect(snap.containsKey('id'), isFalse);
  });

  test('Alt-Snapshot mit Key «nachname» wird weiterhin gelesen (vor Mig. 167)',
      () {
    final back = BetriebRechnungsadresse.fromAdressSnapshot(
        {'nachname': 'Alt-Betrieb', 'plz': '7000', 'ort': 'Chur'});
    expect(back.objekt, 'Alt-Betrieb');
  });
}
