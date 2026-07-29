import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

// `routeId` liefert nativ (Tests laufen auf der VM, kIsWeb == false) den
// Isar-`id`.toString(), nicht `serverId` — deshalb hier über `id` steuern,
// analog zum echten App-Verhalten (siehe AnlageLocal.routeId-Getter).
AnlageLocal anlage(String betriebId, int id) => AnlageLocal()
  ..betriebId = betriebId
  ..id = id;

void main() {
  group('faelligeAnlagenRouteIdsFuerBetrieb / faelligeBetriebIds '
      '(Review 29.07.2026 — unabhaengig vom «Alle»-Filter)', () {
    test('liefert nur die RouteIds des gefragten Betriebs', () {
      final faellig = [anlage('b1', 1), anlage('b1', 2), anlage('b2', 3)];

      expect(faelligeAnlagenRouteIdsFuerBetrieb(faellig, 'b1'), ['1', '2']);
      expect(faelligeAnlagenRouteIdsFuerBetrieb(faellig, 'b2'), ['3']);
    });

    test('unbekannter Betrieb -> leere Liste', () {
      final faellig = [anlage('b1', 1)];
      expect(faelligeAnlagenRouteIdsFuerBetrieb(faellig, 'b9'), isEmpty);
    });

    test('leere Fällig-Liste (z.B. «Alle»-Filter hätte sie sonst gefüllt) '
        '-> leere Liste, kein Crash', () {
      expect(faelligeAnlagenRouteIdsFuerBetrieb(const [], 'b1'), isEmpty);
    });

    test(
      'faelligeBetriebIds dedupliziert mehrere Anlagen desselben Betriebs',
      () {
        final faellig = [anlage('b1', 1), anlage('b1', 2), anlage('b2', 3)];

        expect(faelligeBetriebIds(faellig), {'b1', 'b2'});
      },
    );

    test('faelligeBetriebIds leer -> leeres Set', () {
      expect(faelligeBetriebIds(const []), isEmpty);
    });
  });
}
