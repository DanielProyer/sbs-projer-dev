import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/presentation/screens/einsaetze/einsaetze_screen.dart';

Einsatz e(
  EinsatzTyp typ,
  String name, {
  EinsatzStatus status = EinsatzStatus.erledigt,
  String ort = 'Chur',
}) => Einsatz(
  typ: typ,
  typLabel: einsatzTypLabel(typ),
  routeId: name,
  betriebId: 'b_$name',
  betriebName: name,
  betriebOrt: ort,
  betriebNr: null,
  regionId: null,
  datum: DateTime(2026, 9, 15),
  status: status,
  kennzeichen: EinsatzKennzeichen.keines,
);

final alle = [
  e(EinsatzTyp.reinigung, 'Calanda'),
  e(EinsatzTyp.stoerung, 'Roessli', status: EinsatzStatus.offen, ort: 'Davos'),
  e(EinsatzTyp.montage, 'Posthotel', status: EinsatzStatus.geplant),
];

Widget rahmen({
  required EinsatzFilter filter,
  ValueChanged<EinsatzFilter>? onFilter,
  ValueChanged<Einsatz>? onOeffnen,
  ValueChanged<EinsatzTyp?>? onNeu,
}) => MaterialApp(
  home: EinsaetzeInhalt(
    alle: alle,
    filter: filter,
    jahre: const [2026, 2025],
    regionen: const [],
    anlagenTypen: const ['heigenie', 'david'],
    onFilter: onFilter ?? (_) {},
    onOeffnen: onOeffnen ?? (_) {},
    onNeu: onNeu ?? (_) {},
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('ohne Filter stehen alle drei da', (tester) async {
    await tester.pumpWidget(rahmen(filter: const EinsatzFilter(jahr: 2026)));
    expect(find.text('Calanda'), findsOneWidget);
    expect(find.text('Roessli'), findsOneWidget);
    expect(find.text('Posthotel'), findsOneWidget);
  });

  testWidgets('Typ-Filter zeigt nur den Typ', (tester) async {
    await tester.pumpWidget(
      rahmen(
        filter: const EinsatzFilter(jahr: 2026, typen: {EinsatzTyp.stoerung}),
      ),
    );
    expect(find.text('Roessli'), findsOneWidget);
    expect(find.text('Calanda'), findsNothing);
  });

  testWidgets('Status-Filter zeigt nur offene', (tester) async {
    await tester.pumpWidget(
      rahmen(
        filter: const EinsatzFilter(jahr: 2026, status: {EinsatzStatus.offen}),
      ),
    );
    expect(find.text('Roessli'), findsOneWidget);
    expect(find.text('Posthotel'), findsNothing);
  });

  testWidgets('Suche findet ueber den Ort', (tester) async {
    await tester.pumpWidget(
      rahmen(filter: const EinsatzFilter(jahr: 2026, suche: 'davos')),
    );
    expect(find.text('Roessli'), findsOneWidget);
    expect(find.text('Calanda'), findsNothing);
  });

  testWidgets('Stoerungs-Zusatzfilter erscheinen nur bei genau Stoerung', (
    tester,
  ) async {
    await tester.pumpWidget(rahmen(filter: const EinsatzFilter(jahr: 2026)));
    expect(find.text('Alle Bereiche'), findsNothing);

    await tester.pumpWidget(
      rahmen(
        filter: const EinsatzFilter(jahr: 2026, typen: {EinsatzTyp.stoerung}),
      ),
    );
    expect(find.text('Alle Bereiche'), findsOneWidget);
  });

  testWidgets('Tipp auf die Zeile meldet den Einsatz', (tester) async {
    Einsatz? geoeffnet;
    await tester.pumpWidget(
      rahmen(
        filter: const EinsatzFilter(jahr: 2026),
        onOeffnen: (x) => geoeffnet = x,
      ),
    );
    await tester.tap(find.text('Calanda'));
    expect(geoeffnet?.betriebName, 'Calanda');
  });

  testWidgets('Plus mit genau einem Typ meldet diesen Typ', (tester) async {
    EinsatzTyp? typ;
    var aufrufe = 0;
    await tester.pumpWidget(
      rahmen(
        filter: const EinsatzFilter(jahr: 2026, typen: {EinsatzTyp.montage}),
        onNeu: (t) {
          typ = t;
          aufrufe++;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('einsaetze_neu')));
    expect(aufrufe, 1);
    expect(typ, EinsatzTyp.montage);
  });

  testWidgets(
    'Plus ohne eindeutigen Typ meldet null — der Screen fragt dann nach',
    (tester) async {
      EinsatzTyp? typ = EinsatzTyp.reinigung;
      await tester.pumpWidget(
        rahmen(filter: const EinsatzFilter(jahr: 2026), onNeu: (t) => typ = t),
      );
      await tester.tap(find.byKey(const Key('einsaetze_neu')));
      expect(typ, isNull);
    },
  );

  testWidgets('Leerzustand statt leerer Flaeche', (tester) async {
    await tester.pumpWidget(
      rahmen(filter: const EinsatzFilter(jahr: 2026, suche: 'gibtsnicht')),
    );
    expect(find.text('Keine Einsätze für diese Auswahl'), findsOneWidget);
  });
}
