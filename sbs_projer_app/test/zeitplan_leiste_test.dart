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

    // ── Servicezeit + konkreter Schliessungsgrund (31.07.2026) ──

    testWidgets('Servicezeit und Ruhetage stehen am Block', (tester) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('s', 9 * 60, 30),
          eintrag: _eintrag('s'),
          anlagenGesamt: 1,
          servicezeit: '08:00–12:00 · nachmittags kein Service',
          ruhetage: 'Mo, Di',
        ),
      );
      expect(
        find.text('🕐 08:00–12:00 · nachmittags kein Service · Ruhetag Mo, Di'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ohne erfasste Servicezeit keine Info-Zeile', (tester) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('o', 9 * 60, 30),
          eintrag: _eintrag('o'),
          anlagenGesamt: 1,
        ),
      );
      expect(find.textContaining('🕐'), findsNothing);
    });

    testWidgets('Schliessungsgrund statt pauschaler Warnung', (tester) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('g', 9 * 60, 30),
          eintrag: _eintrag('g'),
          anlagenGesamt: 1,
          ruhetagKonflikt: true,
          schliessungsGrund: 'Betriebsferien bis 16.08.',
        ),
      );
      expect(find.text('Betriebsferien bis 16.08.'), findsOneWidget);
      expect(find.text('Betrieb geschlossen'), findsNothing);
    });

    testWidgets('ohne Grund bleibt die alte Warnung', (tester) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('g2', 9 * 60, 30),
          eintrag: _eintrag('g2'),
          anlagenGesamt: 1,
          ruhetagKonflikt: true,
        ),
      );
      expect(find.text('Betrieb geschlossen'), findsOneWidget);
    });

    // ── Anker verpasst ──

    testWidgets('Anker vor der Ankunft: Warnung', (tester) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          // Anker 08:00, Ankunft laut Plan aber erst 14:30.
          segment: _besuch('v', 14 * 60 + 30, 30),
          eintrag: _eintrag('v').copyWith(ankerZeit: '08:00'),
          anlagenGesamt: 1,
        ),
      );
      expect(
        find.text('Termin 08:00 verpasst — Reihenfolge anpassen'),
        findsOneWidget,
      );
    });

    testWidgets('Anker exakt getroffen: keine Warnung', (tester) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('t', 8 * 60, 30),
          eintrag: _eintrag('t').copyWith(ankerZeit: '08:00'),
          anlagenGesamt: 1,
        ),
      );
      expect(find.textContaining('verpasst'), findsNothing);
    });

    testWidgets('erledigter Block warnt nicht mehr wegen Anker', (
      tester,
    ) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('e2', 14 * 60, 30),
          eintrag: _eintrag('e2').copyWith(ankerZeit: '08:00'),
          anlagenGesamt: 1,
          erledigt: true,
        ),
      );
      expect(find.textContaining('verpasst'), findsNothing);
    });

    // ── Vorjahres-Ferienhinweis (Daniel 31.07.2026) ──

    testWidgets('graues Band zeigt den Vorjahres-Ferienhinweis', (
      tester,
    ) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('vf', 9 * 60, 30),
          eintrag: _eintrag('vf'),
          anlagenGesamt: 1,
          vorjahresFerienText:
              'Letztes Jahr hier Betriebsferien (20.07.–10.08.) — nachfragen',
        ),
      );
      expect(
        find.text(
          'Letztes Jahr hier Betriebsferien (20.07.–10.08.) — nachfragen',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ohne Vorjahres-Ferienhinweis kein Band', (tester) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('vf2', 9 * 60, 30),
          eintrag: _eintrag('vf2'),
          anlagenGesamt: 1,
        ),
      );
      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(find.textContaining('Letztes Jahr'), findsNothing);
    });

    testWidgets('erledigter Block zeigt den Vorjahres-Hinweis nicht mehr', (
      tester,
    ) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: const ZeitSegment(
            art: SegmentArt.besuch,
            blockId: 'vf3',
            startMin: 9 * 60,
            endMin: 9 * 60 + 30,
            ist: true,
          ),
          eintrag: _eintrag('vf3'),
          anlagenGesamt: 1,
          erledigt: true,
          vorjahresFerienText:
              'Letztes Jahr hier Betriebsferien (20.07.–10.08.) — nachfragen',
        ),
      );
      expect(find.textContaining('Letztes Jahr'), findsNothing);
    });

    // ── Saison-Hinweis trotz Schliessung (Fall Löwen Grossdietwil) ──

    testWidgets('graues Band zeigt den Saison-Hinweis', (tester) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: _besuch('sh', 9 * 60, 30),
          eintrag: _eintrag('sh'),
          anlagenGesamt: 1,
          saisonHinweis: 'Letzter Ferientag — Eröffnung',
        ),
      );
      expect(find.text('Letzter Ferientag — Eröffnung'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      // Kein rotes Warnband daneben — der Tag ist gewollt.
      expect(find.byIcon(Icons.warning_amber), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('erledigter Block zeigt den Saison-Hinweis nicht mehr', (
      tester,
    ) async {
      await _pumpe(
        tester,
        ZeitplanZeile(
          segment: const ZeitSegment(
            art: SegmentArt.besuch,
            blockId: 'sh2',
            startMin: 9 * 60,
            endMin: 9 * 60 + 30,
            ist: true,
          ),
          eintrag: _eintrag('sh2'),
          anlagenGesamt: 1,
          erledigt: true,
          saisonHinweis: 'Letzter Ferientag — Eröffnung',
        ),
      );
      expect(find.textContaining('Letzter Ferientag'), findsNothing);
    });
  });
}
