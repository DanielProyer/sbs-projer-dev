import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/besuch_buendelung.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

TourEintrag reinigung(
  String id, {
  String? betriebId,
  List<String> anlageIds = const [],
  String? anlageId,
}) => TourEintrag(
  typ: TourEintragTyp.reinigung,
  id: id,
  betriebId: betriebId,
  anlageId: anlageId ?? (anlageIds.isNotEmpty ? anlageIds.first : null),
  betriebName: 'Betrieb $betriebId',
  beschreibung: '',
  anlageIds: anlageIds,
);

TourEintrag stoerung(String id, {String? betriebId}) => TourEintrag(
  typ: TourEintragTyp.stoerung,
  id: id,
  betriebId: betriebId,
  betriebName: 'Betrieb $betriebId',
  beschreibung: 'Defekt',
);

void main() {
  group('buendleInPlan (Spec 2026-07-29 §1)', () {
    test('bündelt in bestehenden Besuch desselben Betriebs', () {
      final plan = [
        reinigung('r_a1', betriebId: 'b1', anlageIds: ['a1']),
      ];
      final neu = reinigung('r_a2', betriebId: 'b1', anlageIds: ['a2']);

      final ergebnis = buendleInPlan(
        plan: plan,
        neu: neu,
        faelligeAnlagenDesBetriebs: ['a2'],
      );

      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.id, 'r_a1');
      expect(ergebnis.single.anlageIds, ['a1', 'a2']);
      expect(ergebnis.single.anlageId, 'a1'); // erste Anlage bleibt erste
    });

    test('dedupliziert — bereits enthaltene Anlage wird nicht doppelt', () {
      final plan = [
        reinigung('r_a1', betriebId: 'b1', anlageIds: ['a1', 'a2']),
      ];
      final neu = reinigung('r_a2', betriebId: 'b1', anlageIds: ['a2']);

      final ergebnis = buendleInPlan(
        plan: plan,
        neu: neu,
        faelligeAnlagenDesBetriebs: ['a2'],
      );

      expect(ergebnis.single.anlageIds, ['a1', 'a2']);
    });

    test(
      'neuer Besuch nimmt heute fällige Geschwister-Anlagen automatisch mit',
      () {
        final neu = reinigung('r_a1', betriebId: 'b1', anlageIds: ['a1']);

        final ergebnis = buendleInPlan(
          plan: const [],
          neu: neu,
          faelligeAnlagenDesBetriebs: ['a1', 'a2', 'a3'],
        );

        expect(ergebnis, hasLength(1));
        expect(ergebnis.single.anlageIds, ['a1', 'a2', 'a3']);
        expect(ergebnis.single.anlageId, 'a1');
      },
    );

    test(
      'Störung bleibt einzeln — auch bei gleichem Betrieb wie ein Besuch',
      () {
        final plan = [
          reinigung('r_a1', betriebId: 'b1', anlageIds: ['a1']),
        ];
        final neu = stoerung('s_1', betriebId: 'b1');

        final ergebnis = buendleInPlan(
          plan: plan,
          neu: neu,
          faelligeAnlagenDesBetriebs: const [],
        );

        expect(ergebnis, hasLength(2));
        expect(ergebnis.last.id, 's_1');
        expect(ergebnis.last.typ, TourEintragTyp.stoerung);
      },
    );

    test('Eingabelisten bleiben unverändert (keine Mutation)', () {
      final plan = [
        reinigung('r_a1', betriebId: 'b1', anlageIds: ['a1']),
      ];
      final planKopie = List<TourEintrag>.of(plan);
      final neu = reinigung('r_a2', betriebId: 'b1', anlageIds: ['a2']);

      buendleInPlan(plan: plan, neu: neu, faelligeAnlagenDesBetriebs: ['a2']);

      expect(plan, hasLength(1));
      expect(plan.single.anlageIds, ['a1']); // Original-Eintrag unverändert
      expect(plan.single.id, planKopie.single.id);
    });

    test('neu ohne anlageIds nutzt das anlageId-Altfeld', () {
      final neu = reinigung('r_a9', betriebId: 'b1', anlageId: 'a9');

      final ergebnis = buendleInPlan(
        plan: const [],
        neu: neu,
        faelligeAnlagenDesBetriebs: ['a9'],
      );

      expect(ergebnis.single.anlageIds, ['a9']);
      expect(ergebnis.single.anlageId, 'a9');
    });
  });
}
