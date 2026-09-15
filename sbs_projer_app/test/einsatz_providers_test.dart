import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/einsatz_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

void main() {
  test(
    'einsaetzeProvider vereinigt die Quellen und leitet verrechnet aus den Beleg-Ids ab',
    () async {
      final calanda = BetriebLocal()
        ..serverId = 'b1'
        ..name = 'Calanda'
        ..ort = 'Chur';
      final r1 = ReinigungLocal()
        ..serverId = 'r1'
        ..userId = 'u'
        ..anlageId = 'a1'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 15)
        ..status = 'abgeschlossen'
        ..preisBrutto = 177.30;
      final r2 = ReinigungLocal()
        ..serverId = 'r2'
        ..userId = 'u'
        ..anlageId = 'a1'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 14)
        ..status = 'abgeschlossen';
      final s1 = StoerungLocal()
        ..serverId = 's1'
        ..userId = 'u'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 10)
        ..status = 'behoben'
        ..problemBeschreibung = 'x';

      final container = ProviderContainer(
        overrides: [
          reinigungenByJahrProvider.overrideWith(
            (ref, jahr) async => jahr == 2026 ? [r1, r2] : [],
          ),
          stoerungenProvider.overrideWithValue([s1]),
          montagenProvider.overrideWithValue(const []),
          eigenauftraegeProvider.overrideWithValue(const []),
          eroeffnungsreinigungenProvider.overrideWithValue(const []),
          pikettDiensteProvider.overrideWithValue(const []),
          offeneTermineProvider.overrideWith((ref) async => const []),
          betriebLookupProvider.overrideWithValue({'b1': calanda}),
          belegIdsMitBuchungProvider.overrideWith((ref, jahr) async => {'r1'}),
        ],
      );
      addTearDown(container.dispose);

      final liste = await container.read(einsaetzeProvider(2026).future);

      expect(liste, hasLength(3));
      // Reihenfolge ueber Datum pruefen — `routeId` ist im VM-Lauf
      // `id.toString()`, nicht der serverId.
      expect(liste.map((e) => e.datum.day), [
        15,
        14,
        10,
      ], reason: 'neuestes Datum zuerst');
      expect(
        liste[0].status,
        EinsatzStatus.verrechnet,
        reason: 'r1 hat eine Buchung',
      );
      expect(liste[1].status, EinsatzStatus.erledigt, reason: 'r2 hat keine');
      expect(liste[0].betriebName, 'Calanda');
      expect(liste[2].typ, EinsatzTyp.stoerung);
    },
  );

  test('Stoerungen anderer Jahre werden nicht mitgeliefert', () async {
    final alt = StoerungLocal()
      ..serverId = 's0'
      ..userId = 'u'
      ..betriebId = 'b1'
      ..datum = DateTime(2025, 3, 1)
      ..status = 'behoben'
      ..problemBeschreibung = 'x';
    final container = ProviderContainer(
      overrides: [
        reinigungenByJahrProvider.overrideWith((ref, jahr) async => const []),
        stoerungenProvider.overrideWithValue([alt]),
        montagenProvider.overrideWithValue(const []),
        eigenauftraegeProvider.overrideWithValue(const []),
        eroeffnungsreinigungenProvider.overrideWithValue(const []),
        pikettDiensteProvider.overrideWithValue(const []),
        offeneTermineProvider.overrideWith((ref) async => const []),
        betriebLookupProvider.overrideWithValue(const {}),
        belegIdsMitBuchungProvider.overrideWith((ref, jahr) async => const {}),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(einsaetzeProvider(2026).future), isEmpty);
  });
}
