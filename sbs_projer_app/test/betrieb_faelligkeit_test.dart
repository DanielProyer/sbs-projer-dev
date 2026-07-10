import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_faelligkeit.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

void main() {
  group('betriebFaelligkeit', () {
    test('leere Liste -> nichtFaellig', () {
      expect(betriebFaelligkeit([]), FaelligkeitsStatus.nichtFaellig);
    });

    test('gibt den schlimmsten Status zurueck (ueberfaellig schlaegt faellig)', () {
      final r = betriebFaelligkeit([
        FaelligkeitsStatus.nichtFaellig,
        FaelligkeitsStatus.faellig,
        FaelligkeitsStatus.ueberfaellig,
        FaelligkeitsStatus.baldFaellig,
      ]);
      expect(r, FaelligkeitsStatus.ueberfaellig);
    });

    test('Rangfolge faellig > baldFaellig > endreinigung > eroeffnung > nicht', () {
      expect(
        betriebFaelligkeit([
          FaelligkeitsStatus.baldFaellig,
          FaelligkeitsStatus.faellig,
        ]),
        FaelligkeitsStatus.faellig,
      );
      expect(
        betriebFaelligkeit([
          FaelligkeitsStatus.eroeffnungFaellig,
          FaelligkeitsStatus.endreinigungFaellig,
        ]),
        FaelligkeitsStatus.endreinigungFaellig,
      );
      expect(
        betriebFaelligkeit([
          FaelligkeitsStatus.nichtFaellig,
          FaelligkeitsStatus.eroeffnungFaellig,
        ]),
        FaelligkeitsStatus.eroeffnungFaellig,
      );
    });
  });
}
