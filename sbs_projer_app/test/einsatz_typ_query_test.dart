import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';

void main() {
  test('bekannter Typ wird erkannt', () {
    expect(einsatzTypAusQuery('stoerung'), EinsatzTyp.stoerung);
    expect(einsatzTypAusQuery('saisonreinigung'), EinsatzTyp.saisonreinigung);
  });

  test('fehlend oder unbekannt ergibt null — alle Typen', () {
    expect(einsatzTypAusQuery(null), isNull);
    expect(einsatzTypAusQuery(''), isNull);
    expect(einsatzTypAusQuery('irgendwas'), isNull);
  });
}
