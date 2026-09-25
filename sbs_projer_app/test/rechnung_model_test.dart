import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

Map<String, dynamic> _json({Object? guthaben}) => {
  'id': 'r1',
  'user_id': 'u1',
  'rechnungstyp': 'kundenrechnung',
  'rechnungsdatum': '2026-11-20',
  'faelligkeitsdatum': '2026-12-20',
  'betrag_brutto': 143.75,
  if (guthaben != null) 'guthaben_verrechnet': guthaben,
};

void main() {
  group('Rechnung.guthabenVerrechnet', () {
    test('fromJson ohne Feld → 0, zuZahlen = brutto', () {
      final r = Rechnung.fromJson(_json());
      expect(r.guthabenVerrechnet, 0);
      expect(r.zuZahlen, 143.75);
    });

    test('fromJson mit 30 → zuZahlen 113.75', () {
      final r = Rechnung.fromJson(_json(guthaben: 30));
      expect(r.guthabenVerrechnet, 30);
      expect(r.zuZahlen, closeTo(113.75, 1e-9));
    });

    test('fromJson als String (numeric aus PostgREST)', () {
      final r = Rechnung.fromJson(_json(guthaben: '30.00'));
      expect(r.guthabenVerrechnet, 30);
    });

    test('zuZahlen nie negativ', () {
      final r = Rechnung.fromJson(_json(guthaben: 200));
      expect(r.zuZahlen, 0);
    });

    test('toJson schreibt guthaben_verrechnet', () {
      final r = Rechnung.fromJson(_json(guthaben: 30));
      expect(r.toJson()['guthaben_verrechnet'], 30);
    });

    test('copyWith behält und überschreibt guthabenVerrechnet', () {
      final r = Rechnung.fromJson(_json(guthaben: 30));
      expect(
        r.copyWith(faelligkeitsdatum: DateTime(2027)).guthabenVerrechnet,
        30,
      );
      expect(r.copyWith(guthabenVerrechnet: 10).guthabenVerrechnet, 10);
    });
  });
}
