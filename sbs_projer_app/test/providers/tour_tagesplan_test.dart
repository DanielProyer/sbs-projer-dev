import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
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

  // D1 (Review 26.09.2026): Im Lade-Fenster zeigte die Zeitachse den Plan
  // des vorigen Tages unter dem neuen Datum, «Übernehmen» legte dort ab, und
  // das Verschieben liess Stopps doppelt stehen. Der Screen gibt Plan-
  // Aktionen nur frei, wenn `gehoertZu(angezeigter Tag)` stimmt.
  group('TagesplanNotifier.gehoertZu', () {
    final tag1 = DateTime(2026, 9, 28);
    final tag2 = DateTime(2026, 9, 29);

    test('vor dem ersten Laden gehört der State keinem Tag', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tagesplanProvider.notifier);
      expect(notifier.gehoertZu(tag1), isFalse);
    });

    test('Kalendertag-Vergleich — die Uhrzeit zählt nicht', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tagesplanProvider.notifier);
      notifier.setFromGespeichert(tag1, [_e('a')]);

      expect(notifier.gehoertZu(tag1), isTrue);
      expect(notifier.gehoertZu(DateTime(2026, 9, 28, 23, 59)), isTrue);
      expect(notifier.gehoertZu(tag2), isFalse);
      // Gleicher Tag und Monat, anderes Jahr.
      expect(notifier.gehoertZu(DateTime(2025, 9, 28)), isFalse);
    });

    test('Lade-Fenster: neuer Tag aktiv, State noch beim alten', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tagesplanProvider.notifier);
      container.read(aktiverTagesplanTagProvider.notifier).state = tag1;
      notifier.setFromGespeichert(tag1, [_e('a')]);

      // Tipp auf tag2: der Screen stellt den aktiven Tag sofort um.
      container.read(aktiverTagesplanTagProvider.notifier).state = tag2;
      expect(notifier.gehoertZu(tag2), isFalse);
      expect(notifier.gehoertZu(tag1), isTrue);

      // Plan von tag2 ist da (hier: keine Zeile gespeichert).
      notifier.resetLeer(tag2);
      expect(notifier.gehoertZu(tag2), isTrue);
      expect(notifier.gehoertZu(tag1), isFalse);
    });

    test('eine Mutation vor dem ersten Laden beansprucht den aktiven Tag', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(aktiverTagesplanTagProvider.notifier).state = tag1;
      final notifier = container.read(tagesplanProvider.notifier);
      notifier.hinzufuegen(_e('a'));
      expect(notifier.gehoertZu(tag1), isTrue);
    });
  });

  group('tagesplanAnsicht (Tagesplan-Tab)', () {
    test('Plan gehört dem Tag → Zeitachse', () {
      expect(
        tagesplanAnsicht(
          nurIst: false,
          planGehoertZumTag: true,
          ladefehler: false,
        ),
        TagesplanAnsicht.plan,
      );
    });

    test('Plan noch beim vorigen Tag → «Plan wird geladen…»', () {
      expect(
        tagesplanAnsicht(
          nurIst: false,
          planGehoertZumTag: false,
          ladefehler: false,
        ),
        TagesplanAnsicht.laedt,
      );
    });

    test('Ladefehler → Fehlerzustand, NICHT leerer Plan', () {
      expect(
        tagesplanAnsicht(
          nurIst: false,
          planGehoertZumTag: false,
          ladefehler: true,
        ),
        TagesplanAnsicht.ladefehler,
      );
    });

    test('Nachladefehler bei geladenem Plan → Plan bleibt stehen', () {
      expect(
        tagesplanAnsicht(
          nurIst: false,
          planGehoertZumTag: true,
          ladefehler: true,
        ),
        TagesplanAnsicht.plan,
      );
    });

    test('vergangener Tag zeigt die Ist-Daten, auch ohne geladenen Plan', () {
      for (final ladefehler in [false, true]) {
        expect(
          tagesplanAnsicht(
            nurIst: true,
            planGehoertZumTag: false,
            ladefehler: ladefehler,
          ),
          TagesplanAnsicht.plan,
        );
      }
    });
  });

  // M4 (Review 26.09.2026): Die Arbeitstag-Schreiber schreiben Beginn, Ende
  // und km IMMER. Bei einem Ladefehler hiess der erfasste Beginn `null` — ein
  // Tipp auf «Pause» löschte ihn.
  group('arbeitstagSchreibbereit', () {
    const keinPlan = AsyncData<GespeicherterTagesplan?>(null);

    test('geladen (auch «keine Zeile») → darf schreiben', () {
      expect(arbeitstagSchreibbereit(keinPlan), isTrue);
    });

    test('lädt zum ersten Mal → nicht schreiben', () {
      expect(
        arbeitstagSchreibbereit(const AsyncLoading<GespeicherterTagesplan?>()),
        isFalse,
      );
    });

    test('Ladefehler → nicht schreiben', () {
      expect(
        arbeitstagSchreibbereit(
          AsyncError<GespeicherterTagesplan?>('offline', StackTrace.empty),
        ),
        isFalse,
      );
    });

    test('lädt neu nach dem Speichern → nicht auf dem alten Wert schreiben',
        () {
      final neuLaden = const AsyncLoading<GespeicherterTagesplan?>()
          .copyWithPrevious(keinPlan);
      expect(neuLaden.hasValue, isTrue);
      expect(arbeitstagSchreibbereit(neuLaden), isFalse);
    });

    test('Fehler beim Neuladen mit altem Wert → nicht schreiben', () {
      final fehler = AsyncError<GespeicherterTagesplan?>(
        'offline',
        StackTrace.empty,
      ).copyWithPrevious(keinPlan);
      expect(fehler.hasValue, isTrue);
      expect(arbeitstagSchreibbereit(fehler), isFalse);
    });
  });

  // Review 26.09.2026 (Klein b): Im Lade-Fenster zählte die Wochenleiste
  // unter dem neuen Tag die Einträge des Plans vom vorigen Tag.
  group('tagesCountsProvider im Lade-Fenster', () {
    final montag = DateTime(2026, 9, 28);
    final dienstag = DateTime(2026, 9, 29);

    GespeicherterTagesplan plan(List<String> ids) => (
      eintraege: [for (final id in ids) _e(id)],
      arbeitsbeginn: null,
      planBeginn: null,
      arbeitsende: null,
      kmStand: null,
      kmStart: null,
      startLat: null,
      startLng: null,
      endLat: null,
      endLng: null,
      pauseMinuten: null,
      pauseStart: null,
    );

    ProviderContainer containerMitPlaenen() {
      final container = ProviderContainer(
        overrides: [
          reinigungenProvider.overrideWithValue(const []),
          stoerungenProvider.overrideWithValue(const []),
          montagenProvider.overrideWithValue(const []),
          gespeicherterTagesplanProvider.overrideWith(
            (ref, tag) async =>
                tag.day == dienstag.day ? plan(['d1']) : null,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('der Plan des vorigen Tages zählt nicht unter dem neuen', () async {
      final container = containerMitPlaenen();
      final notifier = container.read(tagesplanProvider.notifier);
      container.read(aktiverTagesplanTagProvider.notifier).state = montag;
      notifier.setFromGespeichert(montag, [_e('a'), _e('b'), _e('c')]);
      expect(container.read(tagesCountsProvider(montag))[0], 3);

      // Tipp auf Dienstag: aktiver Tag umgestellt, Plan noch beim Montag.
      container.read(aktiverTagesplanTagProvider.notifier).state = dienstag;
      await container.read(gespeicherterTagesplanProvider(dienstag).future);
      expect(
        container.read(tagesCountsProvider(montag))[1],
        1,
        reason: 'gespeicherter Plan vom Dienstag, nicht die 3 vom Montag',
      );

      // Plan vom Dienstag ist übernommen — jetzt zählt der Live-Stand.
      notifier.setFromGespeichert(dienstag, [_e('x'), _e('y')]);
      expect(container.read(tagesCountsProvider(montag))[1], 2);
    });
  });
}
