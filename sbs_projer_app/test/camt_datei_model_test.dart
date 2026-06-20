import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';

void main() {
  test('fromJson/toJson roundtrip', () {
    final j = {
      'id': 'a', 'user_id': 'u', 'dateiname': 'x.xml',
      'zeitraum_von': '2026-01-01', 'zeitraum_bis': '2026-06-19',
      'iban': 'CH66', 'anzahl_eintraege': 10, 'anzahl_gutschriften': 8,
      'storage_pfad': 'u/x.xml',
    };
    final d = CamtDatei.fromJson(j);
    expect(d.dateiname, 'x.xml');
    expect(d.zeitraumBis, DateTime(2026, 6, 19));
    expect(d.anzahlGutschriften, 8);
  });
}
