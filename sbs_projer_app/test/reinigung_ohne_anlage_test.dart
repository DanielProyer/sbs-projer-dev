import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/reinigung.dart';

// 1'707 der 8'500 Reinigungen haben `anlage_id = NULL` (Historik-Import 2019–2025
// plus 66 App-Besuche ohne Anlagenbezug). `Reinigung.anlageId` ist nicht nullbar.
//
// In Release-Builds bleibt das unbemerkt, weil dart2js auf `-O4` die impliziten
// Typpruefungen weglaesst — der Null-Wert liegt dann als `null` in einem Feld,
// das `String` verspricht. In Debug-Laeufen und Tests bricht derselbe Code sofort ab.
//
// Die App behandelt «keine Anlage» ohnehin als LEEREN String (siehe
// `r.anlageId.isNotEmpty`-Pruefungen in tour_providers.dart). Genau darauf
// wird der Leser hier festgenagelt.

Map<String, dynamic> _zeile({Object? anlageId = 'anlage-1'}) => {
  'id': 'r1',
  'user_id': 'u1',
  'anlage_id': anlageId,
  'betrieb_id': 'b1',
  'datum': '2026-08-03',
  'status': 'abgeschlossen',
};

void main() {
  group('Reinigung ohne Anlage', () {
    test('anlage_id = NULL wird zum leeren String statt zum Absturz', () {
      final r = Reinigung.fromJson(_zeile(anlageId: null));
      expect(r.anlageId, '');
      expect(r.betriebId, 'b1');
    });

    test('vorhandene Anlage bleibt unveraendert', () {
      expect(Reinigung.fromJson(_zeile()).anlageId, 'anlage-1');
    });

    test('eine anlagenlose Zeile reisst den Massen-Load nicht mehr mit', () {
      final rohdaten = [
        _zeile(),
        _zeile(anlageId: null),
        _zeile(anlageId: 'anlage-3'),
      ];
      final liste = rohdaten.map(Reinigung.fromJson).toList();
      expect(liste.length, 3);
      expect(liste.map((r) => r.anlageId), ['anlage-1', '', 'anlage-3']);
    });
  });
}
