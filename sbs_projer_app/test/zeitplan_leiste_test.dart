import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zeitplan.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/zeitplan_leiste.dart';

TourEintrag _eintrag(
  String id, {
  bool uebernommen = false,
  List<String> anlageIds = const ['a1'],
}) => TourEintrag(
  typ: TourEintragTyp.reinigung,
  id: id,
  betriebId: 'b_$id',
  anlageId: anlageIds.isNotEmpty ? anlageIds.first : null,
  betriebName: 'Restaurant $id',
  betriebOrt: 'Davos Platz',
  beschreibung: 'Warmanstich · 6 Hähne',
  faelligkeit: FaelligkeitsStatus.faellig,
  anlageIds: anlageIds,
  uebernommen: uebernommen,
);

ZeitSegment _besuch(String id, int start, int dauer) => ZeitSegment(
  art: SegmentArt.besuch,
  blockId: id,
  startMin: start,
  endMin: start + dauer,
);

/// Drei Zeilen (30/60/90 min) wie im Tagesplan: eine mit Fahrt davor, eine
/// mit Wartezeit davor.
Widget _leiste({bool ruhetagKonflikt = false, bool dauerGeschaetzt = true}) =>
    Column(
      children: [
        ZeitplanZeile(
          segment: _besuch('a', 6 * 60, 30),
          eintrag: _eintrag('a'),
          anlagenGesamt: 2,
          dauerGeschaetzt: dauerGeschaetzt,
          ruhetagKonflikt: ruhetagKonflikt,
        ),
        ZeitplanZeile(
          segment: _besuch('b', 6 * 60 + 45, 60),
          fahrtDavor: ZeitSegment(
            art: SegmentArt.fahrt,
            blockId: 'b',
            startMin: 6 * 60 + 30,
            endMin: 6 * 60 + 45,
          ),
          eintrag: _eintrag('b'),
          anlagenGesamt: 3,
          fahrtQuelle: 'beobachtet',
        ),
        ZeitplanZeile(
          segment: _besuch('c', 8 * 60, 90),
          wartezeitDavor: ZeitSegment(
            art: SegmentArt.wartezeit,
            blockId: 'c',
            startMin: 7 * 60 + 55,
            endMin: 8 * 60,
          ),
          eintrag: _eintrag('c'),
          anlagenGesamt: 1,
        ),
      ],
    );

Future<void> _pumpe(
  WidgetTester tester,
  Widget kind, {
  double breite = 375,
}) async {
  tester.view.physicalSize = Size(breite, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: kind)),
    ),
  );
}

void main() {
  group('ZeitplanZeile', () {
    // 360 = schmales Android, 375 = iPhone SE, 412 = Pixel 9.
    for (final breite in [360.0, 375.0, 412.0]) {
      testWidgets('drei Blöcke ohne Überlauf auf ${breite.toInt()} px', (
        tester,
      ) async {
        await _pumpe(tester, _leiste(), breite: breite);
        // Ein Overflow beendet den Test mit FlutterError — takeException()
        // bleibt nur ohne Überlauf leer.
        expect(tester.takeException(), isNull);

        for (final id in ['a', 'b', 'c']) {
          final hoehe = tester
              .getSize(find.byKey(ValueKey('block_$id')))
              .height;
          expect(
            hoehe,
            greaterThanOrEqualTo(kBlockMindestHoehe),
            reason: 'Block $id zu flach ($hoehe px)',
          );
        }
      });
    }

    testWidgets('Blockhöhe wächst mit der Dauer', (tester) async {
      await _pumpe(tester, _leiste());
      final kurz = tester.getSize(find.byKey(const ValueKey('block_a'))).height;
      final lang = tester.getSize(find.byKey(const ValueKey('block_c'))).height;
      expect(lang, greaterThan(kurz));
    });

    testWidgets('Wartezeit und Fahrt sind sichtbar', (tester) async {
      await _pumpe(tester, _leiste());
      expect(find.text('⏳ 5 min Wartezeit'), findsOneWidget);
      expect(find.text('🚗 15 min'), findsOneWidget);
    });

    testWidgets('Warnband bei Ruhetag-Konflikt', (tester) async {
      await _pumpe(tester, _leiste());
      expect(find.text('Betrieb geschlossen'), findsNothing);

      await _pumpe(tester, _leiste(ruhetagKonflikt: true));
      expect(find.text('Betrieb geschlossen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('~ nur bei geschätzter Dauer', (tester) async {
      await _pumpe(tester, _leiste());
      expect(find.text('06:00–06:30 · ~30 min'), findsOneWidget);

      await _pumpe(tester, _leiste(dauerGeschaetzt: false));
      expect(find.text('06:00–06:30 · 30 min'), findsOneWidget);
    });

    // Regressionsschutz: eine frühere Kompakt-Regel blendete beides bei
    // Blockhöhen < 60 px aus — also beim Normalfall (Median 28–33 min).
    testWidgets('30-min-Block zeigt Anlagen-Chip UND Anker-Vorschlag', (
      tester,
    ) async {
      for (final breite in [360.0, 375.0, 412.0]) {
        await _pumpe(
          tester,
          ZeitplanZeile(
            segment: _besuch('k', 6 * 60, 30),
            eintrag: _eintrag('k'),
            anlagenGesamt: 3,
            servicezeitKonflikt: true,
            ankerVorschlag: '08:00',
            onAnkerVorschlag: () {},
          ),
          breite: breite,
        );
        expect(find.text('1 von 3 Anlagen'), findsOneWidget);
        expect(find.text('Anker 08:00?'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$breite px');
      }
    });

    testWidgets('Anker-Vorschlag auch bei Störung (kein Anlagen-Chip)', (
      tester,
    ) async {
      final stoerung = TourEintrag(
        typ: TourEintragTyp.stoerung,
        id: 's1',
        betriebId: 'b1',
        betriebName: 'Hotel Alpin',
        betriebOrt: 'Klosters',
        beschreibung: 'Kein Druck',
      );
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('s1', 7 * 60, 60),
          eintrag: stoerung,
          ankerVorschlag: '13:30',
          onAnkerVorschlag: () {},
        ),
      );
      expect(find.text('Anker 13:30?'), findsOneWidget);
      expect(find.textContaining('Anlagen'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('übernommener Eintrag wird abgeblendet und beschriftet', (
      tester,
    ) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('u', 6 * 60, 30),
          eintrag: _eintrag('u', uebernommen: true),
          anlagenGesamt: 1,
        ),
      );
      expect(find.text('übernommen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RandSegmentZeile zeigt Anfahrt', (tester) async {
      await _pumpe(
        tester,
        const RandSegmentZeile(
          segment: ZeitSegment(
            art: SegmentArt.anfahrt,
            startMin: 6 * 60,
            endMin: 6 * 60 + 20,
          ),
          label: 'Anfahrt',
        ),
      );
      expect(find.text('🚗 Anfahrt · 20 min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('erledigter Block: Haken + gemessene Zeiten, keine Warnung', (
      tester,
    ) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: const ZeitSegment(
            art: SegmentArt.besuch,
            blockId: 'e',
            startMin: 6 * 60 + 40,
            endMin: 7 * 60 + 10,
            ist: true,
          ),
          eintrag: _eintrag('e'),
          anlagenGesamt: 1,
          erledigt: true,
          ruhetagKonflikt: true, // darf bei erledigt NICHT erscheinen
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.textContaining('gemessen'), findsOneWidget);
      expect(find.text('Betrieb geschlossen'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FreiZeile und JetztLinie auf 360 px ohne Überlauf', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FreiZeile(
                  segment: ZeitSegment(
                    art: SegmentArt.frei,
                    startMin: 430,
                    endMin: 455,
                    ist: true,
                  ),
                ),
                JetztLinie(zeit: '07:35'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('frei · 25 min'), findsOneWidget);
      expect(find.text('07:35'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gemessene Fahrt ist grün beschriftet', (tester) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('f', 8 * 60, 30),
          fahrtDavor: const ZeitSegment(
            art: SegmentArt.fahrt,
            blockId: 'f',
            startMin: 7 * 60 + 40,
            endMin: 8 * 60,
            ist: true,
          ),
          eintrag: _eintrag('f'),
          anlagenGesamt: 1,
          erledigt: true,
        ),
      );
      expect(find.text('🚗 20 min gemessen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
