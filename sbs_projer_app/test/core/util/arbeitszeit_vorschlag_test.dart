import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/arbeitszeit_vorschlag.dart';

void main() {
  group('aufViertelstunde', () {
    test('halbe Stunde bleibt 0.50', () {
      // Der Sartons-Fall vom 03.08.2026: 11:30–12:00, abgerechnet 0.50 h.
      expect(aufViertelstunde(0.5), 0.50);
    });

    test('35 Minuten runden auf die nächste Viertelstunde auf', () {
      expect(aufViertelstunde(35 / 60), 0.75);
    });

    test('exakte Viertelstunde wird NICHT weiter aufgerundet', () {
      expect(aufViertelstunde(0.25), 0.25);
      expect(aufViertelstunde(1.0), 1.00);
      expect(aufViertelstunde(2.75), 2.75);
    });

    test('eine Minute ergibt den Mindestansatz von 0.25', () {
      expect(aufViertelstunde(1 / 60), 0.25);
    });

    test('längerer Einsatz: 2h05 wird 2.25', () {
      expect(aufViertelstunde(125 / 60), 2.25);
    });

    test('über Mitternacht: 1h bleibt 1h', () {
      // Das Formular rechnet Pikett-Einsätze über Mitternacht bereits
      // korrekt in Stunden um — diese Funktion sieht nur noch die Dauer.
      expect(aufViertelstunde(1.0), 1.00);
    });

    test('ohne Messung kein Vorschlag', () {
      expect(aufViertelstunde(null), isNull);
    });

    test('null Stunden ergeben keinen Vorschlag', () {
      expect(aufViertelstunde(0), isNull);
    });

    test('negative Dauer ergibt keinen Vorschlag', () {
      expect(aufViertelstunde(-1.5), isNull);
    });

    test('Rundungsfehler erzeugen keine krummen Werte', () {
      // 0.1+0.2-Falle: das Ergebnis muss ein sauberes Vielfaches von 0.25
      // sein, sonst landet 0.7500000000000001 im Abrechnungsfeld.
      final r = aufViertelstunde(0.7500000000000001);
      expect(r, 0.75);
      expect((r! * 100).round() % 25, 0);
    });
  });
}
