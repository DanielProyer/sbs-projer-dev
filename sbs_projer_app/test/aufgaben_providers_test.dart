import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_vorschlag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/einsatz_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

void main() {
  final calanda = BetriebLocal()
    ..serverId = 'b1'
    ..name = 'Calanda'
    ..ort = 'Chur';

  StoerungLocal stoerung(String id, String status, {DateTime? geplantAm}) =>
      StoerungLocal()
        ..serverId = id
        ..userId = 'u'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 10)
        ..geplantAm = geplantAm
        ..status = status
        ..problemBeschreibung = 'x';

  List<Override> basis({
    List<StoerungLocal> stoerungen = const [],
    List<Aufgabe> detektoren = const [],
    List<Map<String, dynamic>> zeilen = const [],
    List<TerminDto> termine = const [],
    int vorschlaege = 0,
    List<Aufgabe> mahnfaelle = const [],
  }) => [
    stoerungenProvider.overrideWithValue(stoerungen),
    montagenProvider.overrideWithValue(const []),
    eigenauftraegeProvider.overrideWithValue(const []),
    offeneTermineProvider.overrideWith((ref) async => termine),
    betriebLookupProvider.overrideWithValue({'b1': calanda}),
    autoTermineProvider.overrideWith((ref, tag) => const []),
    offeneVorschlaegeAnzahlProvider.overrideWithValue(vorschlaege),
    aufgabenDetektorenProvider.overrideWith((ref) async => detektoren),
    mahnlaufAufgabeProvider.overrideWith((ref) async => const []),
    draussenAufgabenProvider.overrideWith((ref) async => const []),
    mahnfallAufgabenProvider.overrideWith((ref) async => mahnfaelle),
    aufgabenZeilenProvider.overrideWith((ref) async => zeilen),
  ];

  test(
    'anstehendeEinsaetzeProvider: offen/geplant/inArbeit, erledigte nicht, Saison-Termine nicht',
    () {
      final container = ProviderContainer(
        overrides: basis(
          stoerungen: [
            stoerung('s1', 'offen'),
            stoerung('s2', 'behoben'),
            stoerung('s3', 'in_bearbeitung'),
          ],
          termine: [
            TerminDto(
              id: 't1',
              userId: 'u',
              betriebId: 'b1',
              datum: DateTime(2026, 10, 1),
              typ: 'endreinigung',
              titel: 'Endreinigung',
              status: 'geplant',
            ),
            TerminDto(
              id: 't2',
              userId: 'u',
              betriebId: 'b1',
              datum: DateTime(2026, 10, 2),
              typ: 'besuch',
              titel: 'Besuch',
              status: 'geplant',
            ),
          ],
        ),
      );
      addTearDown(container.dispose);
      // offeneTermineProvider ist asynchron — einmal auflösen lassen.
      return container.read(offeneTermineProvider.future).then((_) {
        final l = container.read(anstehendeEinsaetzeProvider);
        expect(l.map((e) => e.routeId).toSet(), containsAll(['t2']));
        expect(l.where((e) => e.typ.name == 'stoerung'), hasLength(2));
        expect(
          l.any((e) => e.routeId == 't1'),
          isFalse,
          reason: 'Saison-Termin laeuft als Quelle termin',
        );
      });
    },
  );

  test(
    'aufgabenListeProvider vereinigt Detektor, eigene, Einsatz, Termin und Vorschlaege',
    () async {
      final container = ProviderContainer(
        overrides: basis(
          stoerungen: [stoerung('s1', 'offen')],
          detektoren: [
            const Aufgabe(
              key: 'mahnlauf',
              titel: 'Mahnlauf',
              route: '/buchhaltung/mahnwesen',
            ),
          ],
          zeilen: [
            {
              'typ': 'eigene',
              'id': 'a1',
              'titel': 'Anrufen',
              'faellig_am': null,
              'erledigt_am': null,
            },
          ],
          termine: [
            TerminDto(
              id: 't1',
              userId: 'u',
              betriebId: 'b1',
              datum: DateTime(2026, 10, 1),
              typ: 'endreinigung',
              titel: '',
              status: 'geplant',
            ),
          ],
          vorschlaege: 2,
        ),
      );
      addTearDown(container.dispose);

      final liste = await container.read(aufgabenListeProvider.future);
      expect(liste.map((e) => e.quelle).toSet(), {
        AufgabenQuelle.detektor,
        AufgabenQuelle.eigene,
        AufgabenQuelle.einsatz,
        AufgabenQuelle.termin,
        AufgabenQuelle.aenderungsVorschlag,
      });
      expect(
        liste.firstWhere((e) => e.quelle == AufgabenQuelle.termin).titel,
        'Endreinigung Calanda',
        reason: 'leerer Termin-Titel wird aus Typ und Betrieb gebildet',
      );
      expect(
        liste.firstWhere((e) => e.quelle == AufgabenQuelle.einsatz).titel,
        'Störung Calanda',
      );
    },
  );

  test('Badge zaehlt nur jetzt Faelliges', () async {
    final container = ProviderContainer(
      overrides: basis(
        stoerungen: [
          stoerung(
            's1',
            'offen',
          ), // gemeldet 10.09., ohne Termin -> ueberfaellig
          stoerung(
            's2',
            'offen',
            geplantAm: DateTime.now().add(const Duration(days: 3)),
          ),
        ],
        zeilen: [
          {
            'typ': 'eigene',
            'id': 'a1',
            'titel': 'In 30 Tagen',
            'faellig_am': DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String()
                .split('T')
                .first,
            'erledigt_am': null,
          },
        ],
      ),
    );
    addTearDown(container.dispose);
    await container.read(aufgabenListeProvider.future);
    expect(container.read(aufgabenBadgeProvider), 1);
    expect(
      container.read(aufgabenJetztProvider).single.titel,
      'Störung Calanda',
    );
  });

  test(
    'mahnfallAufgabenProvider-Aufgabe erscheint in der Liste (Task 7)',
    () async {
      final container = ProviderContainer(
        overrides: basis(
          mahnfaelle: const [
            Aufgabe(
              key: 'mahnfall:f1:heineken',
              titel: 'Mahnfall Calanda: Heineken seit 20 Tagen ohne Ergebnis',
              route: '/rechnungen/mahnfall/f1',
            ),
          ],
        ),
      );
      addTearDown(container.dispose);

      final liste = await container.read(aufgabenListeProvider.future);
      expect(
        liste.any(
          (e) => e.titel == 'Mahnfall Calanda: Heineken seit 20 Tagen ohne Ergebnis',
        ),
        isTrue,
      );
    },
  );
}
