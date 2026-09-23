import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_anzeige.dart';

void main() {
  test('Name mit Ort, ohne Ort nur der Name', () {
    expect(betriebMitOrt('Rössli', 'Cham'), 'Rössli, Cham');
    expect(betriebMitOrt('Rössli', null), 'Rössli');
    expect(betriebMitOrt('Rössli', '  '), 'Rössli');
  });
}
