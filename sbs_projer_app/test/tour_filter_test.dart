import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/tour_filter.dart';

void main() {
  group('statusFuer', () {
    test('Saison fasst Eröffnung und Endreinigung zusammen', () {
      expect(statusFuer(TourFilter.saison), {
        FaelligkeitsStatus.endreinigungFaellig,
        FaelligkeitsStatus.eroeffnungFaellig,
      });
    });

    test('Alle enthält auch nicht fällige Anlagen', () {
      expect(statusFuer(TourFilter.alle),
          contains(FaelligkeitsStatus.nichtFaellig));
      expect(statusFuer(TourFilter.alle).length,
          FaelligkeitsStatus.values.length);
    });

    test('die drei Fälligkeitsstufen bleiben einzeln', () {
      expect(statusFuer(TourFilter.ueberfaellig),
          {FaelligkeitsStatus.ueberfaellig});
      expect(statusFuer(TourFilter.faellig), {FaelligkeitsStatus.faellig});
      expect(statusFuer(TourFilter.bald), {FaelligkeitsStatus.baldFaellig});
    });
  });

  group('sichtbarImTourfilter', () {
    test('leere Auswahl lässt alles durch', () {
      for (final s in FaelligkeitsStatus.values) {
        expect(sichtbarImTourfilter(s, {}), isTrue, reason: s.name);
      }
    });

    test('Standard zeigt alles ausser nicht fällig', () {
      final std = standardTourFilter;
      expect(sichtbarImTourfilter(FaelligkeitsStatus.ueberfaellig, std), isTrue);
      expect(sichtbarImTourfilter(FaelligkeitsStatus.faellig, std), isTrue);
      expect(sichtbarImTourfilter(FaelligkeitsStatus.baldFaellig, std), isTrue);
      expect(sichtbarImTourfilter(FaelligkeitsStatus.eroeffnungFaellig, std),
          isTrue);
      expect(sichtbarImTourfilter(FaelligkeitsStatus.endreinigungFaellig, std),
          isTrue);
      expect(
          sichtbarImTourfilter(FaelligkeitsStatus.nichtFaellig, std), isFalse);
    });

    test('nur Saison blendet die normalen Fälligkeiten aus', () {
      const nurSaison = {TourFilter.saison};
      expect(sichtbarImTourfilter(
          FaelligkeitsStatus.eroeffnungFaellig, nurSaison), isTrue);
      expect(sichtbarImTourfilter(
          FaelligkeitsStatus.endreinigungFaellig, nurSaison), isTrue);
      expect(sichtbarImTourfilter(FaelligkeitsStatus.ueberfaellig, nurSaison),
          isFalse);
    });

    test('Alle lässt jeden Status durch', () {
      for (final s in FaelligkeitsStatus.values) {
        expect(sichtbarImTourfilter(s, {TourFilter.alle}), isTrue,
            reason: s.name);
      }
    });
  });

  group('zeigtNichtFaellige', () {
    test('nur bei Alle oder leerer Auswahl', () {
      expect(zeigtNichtFaellige({TourFilter.alle}), isTrue);
      expect(zeigtNichtFaellige({}), isTrue);
      expect(zeigtNichtFaellige(standardTourFilter), isFalse);
      expect(zeigtNichtFaellige({TourFilter.saison}), isFalse);
    });
  });

  group('nachTipp', () {
    test('Alle schaltet die übrigen ab', () {
      expect(nachTipp(standardTourFilter, TourFilter.alle), {TourFilter.alle});
    });

    test('ein anderer Knopf schaltet Alle wieder aus', () {
      expect(nachTipp({TourFilter.alle}, TourFilter.faellig),
          {TourFilter.faellig});
    });

    test('Alle erneut getippt leert die Auswahl', () {
      expect(nachTipp({TourFilter.alle}, TourFilter.alle), isEmpty);
    });

    test('normale Knöpfe schalten einzeln um', () {
      expect(nachTipp({TourFilter.faellig}, TourFilter.bald),
          {TourFilter.faellig, TourFilter.bald});
      expect(nachTipp({TourFilter.faellig, TourFilter.bald}, TourFilter.bald),
          {TourFilter.faellig});
    });

    test('letzter Knopf darf abgewählt werden', () {
      expect(nachTipp({TourFilter.faellig}, TourFilter.faellig), isEmpty);
    });

    test('die Eingabemenge bleibt unverändert', () {
      final vorher = {TourFilter.faellig};
      nachTipp(vorher, TourFilter.bald);
      expect(vorher, {TourFilter.faellig});
    });
  });

  group('tourFilterLabel', () {
    test('alle Knöpfe haben ein kurzes Label', () {
      for (final f in TourFilter.values) {
        expect(tourFilterLabel(f).length, lessThanOrEqualTo(10), reason: f.name);
      }
    });
  });
}
