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

  // Z1 (Review 26.09.2026): Ein Tag-Wechsel innerhalb der 600 ms Entprellung
  // verwarf das ausstehende Speichern — die letzte Änderung war weg.
  group('TagesplanNotifier – ausstehendes Speichern beim Tag-Wechsel', () {
    late List<(DateTime, String)> gespeichert;
    late ProviderContainer container;

    setUp(() {
      gespeichert = [];
      container = ProviderContainer(
        overrides: [
          tagesplanProvider.overrideWith(
            (ref) => TagesplanNotifier(
              ref,
              speichern: (tag, eintraege) async {
                gespeichert.add((tag, eintraege.map((e) => e.id).join(',')));
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    final tag1 = DateTime(2026, 9, 28);
    final tag2 = DateTime(2026, 9, 29);

    for (final wechsel in ['setFromGespeichert', 'resetLeer']) {
      test(
        '$wechsel speichert den ALTEN Tag sofort mit dem alten Stand',
        () async {
          final notifier = container.read(tagesplanProvider.notifier);
          container.read(aktiverTagesplanTagProvider.notifier).state = tag1;
          notifier.setFromGespeichert(tag1, [_e('a')]);
          notifier.hinzufuegen(_e('b')); // entprellt, noch nicht gespeichert
          expect(gespeichert, isEmpty);

          container.read(aktiverTagesplanTagProvider.notifier).state = tag2;
          if (wechsel == 'setFromGespeichert') {
            notifier.setFromGespeichert(tag2, [_e('x')]);
          } else {
            notifier.resetLeer(tag2);
          }
          await Future<void>.delayed(Duration.zero);
          expect(gespeichert, [(tag1, 'a,b')]);

          // Der Timer ist weg: nach Ablauf der Entprellung kommt kein zweites
          // Speichern — schon gar nicht mit dem neuen Stand unter tag2.
          await Future<void>.delayed(const Duration(milliseconds: 700));
          expect(gespeichert, hasLength(1));
        },
      );
    }

    test('ohne ausstehende Änderung speichert der Wechsel nichts', () async {
      final notifier = container.read(tagesplanProvider.notifier);
      notifier.setFromGespeichert(tag1, [_e('a')]);
      notifier.setFromGespeichert(tag2, [_e('x')]);
      await Future<void>.delayed(Duration.zero);
      expect(gespeichert, isEmpty);
    });

    // A1 (Runde 5, 26.09.2026): Der Screen stellt aktiverTagesplanTagProvider
    // schon beim Tipp auf den neuen Tag, lädt dessen Plan aber erst danach.
    // Eine Mutation in diesem Fenster schrieb den ALTEN Plan unter den NEUEN
    // Tag. Gespeichert wird unter dem Tag, dem der State gehört.
    test('Mutation im Lade-Fenster speichert unter dem Tag des States',
        () async {
      final notifier = container.read(tagesplanProvider.notifier);
      container.read(aktiverTagesplanTagProvider.notifier).state = tag1;
      notifier.setFromGespeichert(tag1, [_e('a')]);

      // Tipp auf tag2: Provider schon umgestellt, Plan noch nicht geladen.
      container.read(aktiverTagesplanTagProvider.notifier).state = tag2;
      notifier.hinzufuegen(_e('b'));
      expect(notifier.datum, tag1);

      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(gespeichert, [(tag1, 'a,b')]);
    });

    test('Lade-Fetch nach Mutation im Fenster: alter Tag sofort gesichert, '
        'neuer Tag wird geladen', () async {
      final notifier = container.read(tagesplanProvider.notifier);
      container.read(aktiverTagesplanTagProvider.notifier).state = tag1;
      notifier.setFromGespeichert(tag1, [_e('a')]);

      container.read(aktiverTagesplanTagProvider.notifier).state = tag2;
      notifier.hinzufuegen(_e('b'));
      // Race-Schutz des Screens: `datum != tag2` → der Lade-Fetch darf den
      // State für tag2 setzen.
      expect(notifier.datum == tag2, isFalse);
      notifier.setFromGespeichert(tag2, [_e('x')]);
      await Future<void>.delayed(Duration.zero);
      expect(gespeichert, [(tag1, 'a,b')]);
      expect(notifier.datum, tag2);
      expect(container.read(tagesplanProvider).map((e) => e.id), ['x']);

      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(gespeichert, hasLength(1));
    });

    test('entprelltes Speichern ohne Wechsel läuft wie bisher', () async {
      final notifier = container.read(tagesplanProvider.notifier);
      container.read(aktiverTagesplanTagProvider.notifier).state = tag1;
      notifier.setFromGespeichert(tag1, [_e('a')]);
      notifier.entfernen('a');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(gespeichert, [(tag1, '')]);
    });
  });
}
