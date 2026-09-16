import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/reinigung_betrag.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';

void main() {
  ReinigungLocal r({double? preis, bool kulanz = false}) => ReinigungLocal()
    ..userId = 'u'
    ..anlageId = 'a'
    ..betriebId = 'b'
    ..datum = DateTime(2026, 7, 31)
    ..preisBrutto = preis
    ..istKulanz = kulanz;

  test('normaler Bruttopreis zaehlt', () {
    expect(reinigungBetrag(r(preis: 94.05)), 94.05);
  });
  test('Kulanz zaehlt 0, auch wenn der Trigger einen Preis gerechnet hat', () {
    expect(reinigungBetrag(r(preis: 94.05, kulanz: true)), 0);
  });
  test('ohne Preis 0', () {
    expect(reinigungBetrag(r()), 0);
  });
}
