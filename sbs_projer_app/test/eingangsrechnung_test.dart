import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';

void main() {
  test('fromJson/toJson round-trip Kernfelder', () {
    final e = Eingangsrechnung.fromJson({
      'id': 'e1', 'user_id': 'u', 'aussteller_name': 'Heineken Switzerland AG',
      'betrag_brutto': '3772.70', 'mwst_satz': '8.1', 'referenz_typ': 'QRR',
      'status': 'erkannt', 'ist_nur_info': false, 'aufwandskonto': 6301,
    });
    expect(e.ausstellerName, 'Heineken Switzerland AG');
    expect(e.betragBrutto, 3772.70);
    expect(e.aufwandskonto, 6301);
    expect(e.toJson()['referenz_typ'], 'QRR');
  });
}
