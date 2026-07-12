import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

TourEintrag _e(String id) => TourEintrag(
      typ: TourEintragTyp.reinigung,
      id: id,
      betriebName: 'Betrieb $id',
      beschreibung: '',
    );

void main() {
  group('TagesplanNotifier – Datum-Beanspruchung (Race-Schutz)', () {
    test('Mutation beansprucht den aktiven Tag', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tag = DateTime(2026, 7, 15);
      container.read(aktiverTagesplanTagProvider.notifier).state = tag;

      final notifier = container.read(tagesplanProvider.notifier);
      expect(notifier.datum, isNull);

      notifier.hinzufuegen(_e('a'));
      expect(container.read(tagesplanProvider).length, 1);
      // Tag ist jetzt beansprucht → ein später eintreffender Lade-Fetch für
      // denselben Tag darf den Stand NICHT mehr überschreiben.
      expect(notifier.datum, tag);
    });

    test('setFromGespeichert / resetLeer setzen das Datum', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tagesplanProvider.notifier);

      final tag1 = DateTime(2026, 7, 15);
      notifier.setFromGespeichert(tag1, [_e('a'), _e('b')]);
      expect(notifier.datum, tag1);
      expect(container.read(tagesplanProvider).length, 2);

      final tag2 = DateTime(2026, 7, 16);
      notifier.resetLeer(tag2);
      expect(notifier.datum, tag2);
      expect(container.read(tagesplanProvider), isEmpty);
    });
  });
}
