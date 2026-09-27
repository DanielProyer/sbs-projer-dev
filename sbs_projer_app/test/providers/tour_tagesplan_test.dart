import 'dart:async';

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

  // Review 27.09.2026 (Restfenster nach K1): Eine zweite Tourenplanung (Tag
  // B) löst das Sofort-Speichern von Tag A aus. Kehrt man zurück, solange es
  // läuft, liegt im Cache von A noch der Stand VOR der letzten Änderung.
  group('standBeimLaden (Ladestand vs. laufendes Speichern)', () {
    final tagA = DateTime(2026, 9, 28);

    test('ohne laufendes Speichern gilt der Ladestand', () {
      final stand = standBeimLaden(
        tag: tagA,
        geladen: [_e('a')],
        laufend: const {},
      );
      expect(stand.map((e) => e.id), ['a']);
    });

    test('läuft das Speichern desselben Tages, gilt dessen Stand — auch '
        'mit Uhrzeit im Schlüssel', () {
      final stand = standBeimLaden(
        tag: tagA,
        geladen: [_e('a')],
        laufend: {
          DateTime(2026, 9, 28, 14, 5): [_e('a'), _e('b')],
        },
      );
      expect(stand.map((e) => e.id), ['a', 'b']);
    });

    test('ein Speichern eines anderen Tages ändert nichts', () {
      final stand = standBeimLaden(
        tag: tagA,
        geladen: [_e('a')],
        laufend: {
          DateTime(2026, 9, 29): [_e('x')],
          DateTime(2025, 9, 28): [_e('y')],
        },
      );
      expect(stand.map((e) => e.id), ['a']);
    });

    test('auch ein leerer gespeicherter Stand schlägt den Ladestand', () {
      final stand = standBeimLaden(
        tag: tagA,
        geladen: [_e('a')],
        laufend: {tagA: const []},
      );
      expect(stand, isEmpty);
    });
  });

  group('TagesplanNotifier – Ladestand während eines Speicherns', () {
    late List<Completer<void>> speichern;
    late List<(DateTime, String)> gespeichert;
    late ProviderContainer container;
    final tagA = DateTime(2026, 9, 28);
    final tagB = DateTime(2026, 9, 29);

    setUp(() {
      speichern = [];
      gespeichert = [];
      container = ProviderContainer(
        overrides: [
          tagesplanProvider.overrideWith(
            (ref) => TagesplanNotifier(
              ref,
              speichern: (tag, eintraege) {
                gespeichert.add((tag, eintraege.map((e) => e.id).join(',')));
                final c = Completer<void>();
                speichern.add(c);
                return c.future;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    List<String> ids() =>
        container.read(tagesplanProvider).map((e) => e.id).toList();

    test('zweite Instanz und schnell zurück: der ältere Ladestand von A wird '
        'verworfen', () async {
      final notifier = container.read(tagesplanProvider.notifier);
      container.read(aktiverTagesplanTagProvider.notifier).state = tagA;
      notifier.setFromGespeichert(tagA, [_e('a')]);
      notifier.hinzufuegen(_e('b')); // entprellt

      // Zweite Instanz lädt B → A wird sofort gespeichert (läuft noch).
      notifier.setFromGespeichert(tagB, [_e('x')]);
      await Future<void>.delayed(Duration.zero);
      expect(gespeichert, [(tagA, 'a,b')]);
      expect(notifier.speichertGerade(tagA), isTrue);

      // Zurück: der Cache von A hält noch den Stand ohne «b».
      notifier.setFromGespeichert(tagA, [_e('a')]);
      expect(ids(), ['a', 'b']);
      expect(notifier.gehoertZu(tagA), isTrue);

      speichern.first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.speichertGerade(tagA), isFalse);
    });

    test('auch «keine Zeile» ist ein älterer Ladestand, solange das erste '
        'Speichern läuft', () async {
      final notifier = container.read(tagesplanProvider.notifier);
      container.read(aktiverTagesplanTagProvider.notifier).state = tagA;
      notifier.resetLeer(tagA);
      notifier.hinzufuegen(_e('a'));
      notifier.resetLeer(tagB); // sichert A sofort
      await Future<void>.delayed(Duration.zero);

      notifier.resetLeer(tagA);
      expect(ids(), ['a']);
    });

    test('nach dem Speichern gilt wieder der Ladestand', () async {
      final notifier = container.read(tagesplanProvider.notifier);
      container.read(aktiverTagesplanTagProvider.notifier).state = tagA;
      notifier.setFromGespeichert(tagA, [_e('a')]);
      notifier.hinzufuegen(_e('b'));
      notifier.setFromGespeichert(tagB, [_e('x')]);
      await Future<void>.delayed(Duration.zero);
      speichern.first.complete();
      await Future<void>.delayed(Duration.zero);

      // Frisch geladen (nach der Invalidierung): enthält «b» — und darf
      // auch eine Änderung von anderswo tragen.
      notifier.setFromGespeichert(tagA, [_e('a'), _e('b'), _e('c')]);
      expect(ids(), ['a', 'b', 'c']);
    });

    test('ein gescheitertes Speichern gibt den Tag wieder frei', () async {
      final notifier = container.read(tagesplanProvider.notifier);
      container.read(aktiverTagesplanTagProvider.notifier).state = tagA;
      notifier.setFromGespeichert(tagA, [_e('a')]);
      notifier.hinzufuegen(_e('b'));
      notifier.setFromGespeichert(tagB, [_e('x')]);
      await Future<void>.delayed(Duration.zero);
      speichern.first.completeError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.speichertGerade(tagA), isFalse);
    });

    test('zwei Speicherungen desselben Tages: das frühere Ende gibt den '
        'neueren Stand nicht frei', () async {
      final notifier = container.read(tagesplanProvider.notifier);
      container.read(aktiverTagesplanTagProvider.notifier).state = tagA;
      notifier.setFromGespeichert(tagA, [_e('a')]);
      notifier.hinzufuegen(_e('b'));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      notifier.hinzufuegen(_e('c'));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(gespeichert, [(tagA, 'a,b'), (tagA, 'a,b,c')]);

      speichern.first.complete(); // das ältere ist fertig
      await Future<void>.delayed(Duration.zero);
      expect(notifier.speichertGerade(tagA), isTrue);

      notifier.setFromGespeichert(tagB, [_e('x')]);
      notifier.setFromGespeichert(tagA, [_e('a'), _e('b')]);
      expect(ids(), ['a', 'b', 'c']);
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

  // Review 27.09.2026: An vergangenen Tagen verlangte das Fällig-«+» bei
  // einem Ladefehler «zuerst Erneut laden» — den Knopf gab es dort nicht,
  // weil der Tab die Ist-Ansicht statt des Fehlers zeigt.
  group('tagesplanLadefehlerBand (Ist-Ansicht mit Ladefehler)', () {
    bool band({
      required bool nurIst,
      required bool planGehoertZumTag,
      required bool ladefehler,
    }) => tagesplanLadefehlerBand(
      nurIst: nurIst,
      planGehoertZumTag: planGehoertZumTag,
      ladefehler: ladefehler,
    );

    test('vergangener Tag, Plan nicht geladen, Fehler → Band', () {
      expect(
        band(nurIst: true, planGehoertZumTag: false, ladefehler: true),
        isTrue,
      );
    });

    test('vergangener Tag, Plan lädt noch → kein Band', () {
      expect(
        band(nurIst: true, planGehoertZumTag: false, ladefehler: false),
        isFalse,
      );
    });

    test('Nachladefehler bei geladenem Plan → kein Band (Plan-Aktionen '
        'gehen)', () {
      expect(
        band(nurIst: true, planGehoertZumTag: true, ladefehler: true),
        isFalse,
      );
    });

    test('heutiger/künftiger Tag → kein Band, dort zeigt der Tab den '
        'Fehler selbst', () {
      expect(
        band(nurIst: false, planGehoertZumTag: false, ladefehler: true),
        isFalse,
      );
      expect(
        tagesplanAnsicht(
          nurIst: false,
          planGehoertZumTag: false,
          ladefehler: true,
        ),
        TagesplanAnsicht.ladefehler,
      );
    });

    test('jede Lage, in der das «+» «Erneut laden» verlangt, hat einen '
        'Knopf', () {
      for (final nurIst in [false, true]) {
        for (final gehoert in [false, true]) {
          // `_planBereit` verlangt «Erneut laden» genau dann:
          const ladefehler = true;
          final verlangt = !gehoert && ladefehler;
          if (!verlangt) continue;
          final fehleransicht =
              tagesplanAnsicht(
                nurIst: nurIst,
                planGehoertZumTag: gehoert,
                ladefehler: ladefehler,
              ) ==
              TagesplanAnsicht.ladefehler;
          expect(
            fehleransicht ||
                band(
                  nurIst: nurIst,
                  planGehoertZumTag: gehoert,
                  ladefehler: ladefehler,
                ),
            isTrue,
            reason: 'nurIst=$nurIst',
          );
        }
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
