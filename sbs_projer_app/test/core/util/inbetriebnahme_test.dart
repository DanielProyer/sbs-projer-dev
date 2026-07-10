import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/inbetriebnahme.dart';

void main() {
  group('inbetriebnahmeFortschritt', () {
    test('keine Anlagen -> 0/0, nicht komplett', () {
      final f = inbetriebnahmeFortschritt([]);
      expect(f.total, 0);
      expect(f.inBetrieb, 0);
      expect(f.komplett, isFalse);
    });
    test('summiert anzahl, nur in-Betrieb zaehlen', () {
      final f = inbetriebnahmeFortschritt([
        (anzahl: 7, inBetrieb: true),
        (anzahl: 3, inBetrieb: false),
        (anzahl: 2, inBetrieb: true),
      ]);
      expect(f.total, 12);
      expect(f.inBetrieb, 9);
      expect(f.komplett, isFalse);
    });
    test('alle in Betrieb -> komplett', () {
      final f = inbetriebnahmeFortschritt([
        (anzahl: 4, inBetrieb: true),
        (anzahl: 1, inBetrieb: true),
      ]);
      expect(f.komplett, isTrue);
      expect(f.label, '✓ komplett');
    });
    test('label X/Y', () {
      expect(inbetriebnahmeFortschritt([(anzahl: 5, inBetrieb: true), (anzahl: 5, inBetrieb: false)]).label, '5/10 in Betrieb');
    });
  });
}
