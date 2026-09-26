import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_geld.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/presentation/screens/einsaetze/einsaetze_screen.dart';
import 'package:sbs_projer_app/presentation/widgets/betrieb/betrieb_geld_block.dart';
import 'package:sbs_projer_app/presentation/widgets/betrieb/einsaetze_akte_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_typ_wahl.dart';

Widget rahmen(Widget kind) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: kind)));

Einsatz einsatz(int i, {EinsatzTyp typ = EinsatzTyp.reinigung}) => Einsatz(
  typ: typ,
  typLabel: einsatzTypLabel(typ),
  routeId: 'e$i',
  betriebId: 'b1',
  betriebName: 'Calanda',
  betriebOrt: 'Chur',
  betriebNr: null,
  regionId: null,
  datum: DateTime(2025, 1, 1).add(Duration(days: i)),
  status: EinsatzStatus.erledigt,
  kennzeichen: EinsatzKennzeichen.keines,
);

void main() {
  group('Geld-Block', () {
    testWidgets('Ladefehler zeigt «nicht geladen», nie eine 0', (t) async {
      await t.pumpWidget(
        rahmen(
          BetriebGeldInhalt(
            stand: AsyncValue.error('weg', StackTrace.empty),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Geld: nicht geladen'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
    });

    testWidgets('zeigt Saldo, Überfällige, Mahnstufe und Guthaben', (t) async {
      var getippt = false;
      await t.pumpWidget(
        rahmen(
          BetriebGeldInhalt(
            stand: const AsyncValue.data(
              BetriebGeldStand(
                offenCHF: 1234.5,
                anzahlOffen: 3,
                anzahlUeberfaellig: 1,
                hoechsteMahnstufe: 2,
                guthabenCHF: 40,
              ),
            ),
            onTap: () => getippt = true,
          ),
        ),
      );
      expect(
        find.text("Offen CHF 1'234.50 (3 Rechnungen, davon 1 überfällig)"),
        findsOneWidget,
      );
      expect(find.text('Mahnstufe: 1. Mahnung'), findsOneWidget);
      expect(find.text('Kundenguthaben CHF 40.00'), findsOneWidget);
      await t.tap(find.byKey(const Key('betrieb_geld_tap')));
      expect(getippt, isTrue);
    });

    testWidgets('ohne Offenes keine Mahn- und Guthabenzeile', (t) async {
      await t.pumpWidget(
        rahmen(
          BetriebGeldInhalt(
            stand: const AsyncValue.data(
              BetriebGeldStand(
                offenCHF: 0,
                anzahlOffen: 0,
                anzahlUeberfaellig: 0,
                hoechsteMahnstufe: 0,
                guthabenCHF: 0,
              ),
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Keine offenen Rechnungen'), findsOneWidget);
      expect(find.textContaining('Mahnstufe'), findsNothing);
      expect(find.textContaining('Kundenguthaben'), findsNothing);
    });
  });

  group('Einsätze-Akte', () {
    testWidgets('zeigt die letzten 10 und verweist auf alle', (t) async {
      var alle = false;
      Einsatz? geoeffnet;
      final liste = [for (var i = 0; i < 14; i++) einsatz(i)];
      await t.pumpWidget(
        rahmen(
          EinsaetzeAkteInhalt(
            einsaetze: AsyncValue.data(liste),
            onOeffnen: (e) => geoeffnet = e,
            onAlle: () => alle = true,
          ),
        ),
      );
      expect(find.text('Einsätze (14)'), findsOneWidget);
      expect(find.text('Reinigung'), findsNWidgets(kAkteZeilen));
      // Kein «+» ohne onNeu (Gast).
      expect(find.byKey(const Key('akte_neu')), findsNothing);
      await t.tap(find.text('Reinigung').first);
      expect(geoeffnet?.routeId, 'e0');
      await t.tap(find.text('Alle 14 anzeigen'));
      expect(alle, isTrue);
    });

    testWidgets('leer und Ladefehler', (t) async {
      await t.pumpWidget(
        rahmen(
          EinsaetzeAkteInhalt(
            einsaetze: const AsyncValue.data([]),
            onOeffnen: (_) {},
            onAlle: () {},
            onNeu: () {},
          ),
        ),
      );
      expect(find.text('Noch keine Einsätze erfasst'), findsOneWidget);
      expect(find.byKey(const Key('akte_neu')), findsOneWidget);
      expect(find.byKey(const Key('akte_alle')), findsNothing);

      await t.pumpWidget(
        rahmen(
          EinsaetzeAkteInhalt(
            einsaetze: AsyncValue.error('kaputt', StackTrace.empty),
            onOeffnen: (_) {},
            onAlle: () {},
          ),
        ),
      );
      expect(find.textContaining('nicht geladen'), findsOneWidget);
    });

    testWidgets('Montage erscheint mit Typ als Titel', (t) async {
      await t.pumpWidget(
        rahmen(
          EinsaetzeAkteInhalt(
            einsaetze: AsyncValue.data([einsatz(1, typ: EinsatzTyp.montage)]),
            onOeffnen: (_) {},
            onAlle: () {},
          ),
        ),
      );
      expect(find.text('Montage'), findsOneWidget);
      // Datum mit Jahr, Betriebsname nicht wiederholt.
      expect(find.textContaining('02.01.2025'), findsOneWidget);
      expect(find.text('Calanda'), findsNothing);
    });
  });

  testWidgets('Einsätze-Screen mit Betrieb: Chip statt Jahresleiste, alle Jahre', (
    t,
  ) async {
    EinsatzFilter? neu;
    final liste = [
      einsatz(1),
      einsatz(400), // 2026
      Einsatz(
        typ: EinsatzTyp.stoerung,
        typLabel: 'Störung',
        routeId: 'fremd',
        betriebId: 'b2',
        betriebName: 'Roessli',
        betriebOrt: null,
        betriebNr: null,
        regionId: null,
        datum: DateTime(2026, 3, 1),
        status: EinsatzStatus.offen,
        kennzeichen: EinsatzKennzeichen.keines,
      ),
    ];
    await t.pumpWidget(
      MaterialApp(
        home: EinsaetzeInhalt(
          alle: liste,
          filter: const EinsatzFilter(jahr: 0, betriebId: 'b1'),
          jahre: const [2026],
          regionen: const [],
          anlagenTypen: const [],
          betriebName: 'Calanda',
          onFilter: (f) => neu = f,
          onOeffnen: (_) {},
          onNeu: (_) {},
        ),
      ),
    );
    expect(find.text('Betrieb: Calanda'), findsOneWidget);
    expect(find.text('2 Einsätze, alle Jahre'), findsOneWidget);
    expect(find.text('Roessli'), findsNothing);
    await t.tap(find.byKey(const Key('einsaetze_betrieb_chip')));
    expect(neu?.betriebId, isNull);
    expect(neu?.jahr, DateTime.now().year);
  });

  group('einsatzNeuRoute', () {
    test('mit Betrieb und Anlage vorbelegt', () {
      expect(
        einsatzNeuRoute(EinsatzTyp.montage, betriebId: 'b1', anlageId: 'a1'),
        '/montagen/neu?betriebId=b1&anlageId=a1',
      );
      expect(
        einsatzNeuRoute(EinsatzTyp.eigenauftrag, betriebId: 'b1'),
        '/eigenauftraege/neu?betriebId=b1',
      );
      expect(einsatzNeuRoute(EinsatzTyp.reinigung), '/reinigungen/neu');
      expect(
        einsatzNeuRoute(EinsatzTyp.pikett, betriebId: 'b1'),
        '/pikett/neu',
      );
    });
  });
}
