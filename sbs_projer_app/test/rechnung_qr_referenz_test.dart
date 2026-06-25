import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

void main() {
  test('qrReferenz round-trips durch fromJson/toJson', () {
    final r = Rechnung.fromJson({
      'id': 'r1', 'user_id': 'u', 'rechnungstyp': 'kundenrechnung',
      'rechnungsdatum': '2026-06-25', 'faelligkeitsdatum': '2026-07-25',
      'qr_referenz': 'RF18539007547034',
    });
    expect(r.qrReferenz, 'RF18539007547034');
    expect(r.toJson()['qr_referenz'], 'RF18539007547034');
  });

  test('copyWith behält qrReferenz', () {
    final r = Rechnung(
      id: 'r1', userId: 'u', rechnungstyp: 'kundenrechnung',
      rechnungsdatum: DateTime(2026, 6, 25),
      faelligkeitsdatum: DateTime(2026, 7, 25),
      qrReferenz: 'RF18539007547034',
    );
    expect(r.copyWith().qrReferenz, 'RF18539007547034');
  });
}
