import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/monatsabschluss_screen.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';

Pruefbefund b(
  String id,
  PruefStatus s, {
  String gruppe = 'Einsätze',
  String titel = 'Eine Regel',
  String? route,
}) => Pruefbefund(
  regelId: id,
  gruppe: gruppe,
  status: s,
  titel: titel,
  ist: 'Ist-Wert',
  aktionRoute: route,
);

Widget rahmen(
  List<Pruefbefund> befunde, {
  ValueChanged<Pruefbefund>? onZeile,
}) => MaterialApp(
  home: MonatsabschlussInhalt(
    befunde: befunde,
    jahr: 2026,
    monat: 8,
    jahre: const [2026, 2025],
    onJahr: (_) {},
    onMonat: (_) {},
    onZeile: onZeile ?? (_) {},
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('zeigt Gruppen und Regeln', (tester) async {
    await tester.pumpWidget(
      rahmen([
        b('r1', PruefStatus.rot, titel: 'Alle Reinigungen abgeschlossen'),
        b(
          'h1',
          PruefStatus.gelb,
          gruppe: 'Heineken',
          titel: 'Monatsrechnung erstellt',
        ),
        b('l1', PruefStatus.gruen, gruppe: 'Lohn', titel: 'Lohnlauf gemacht'),
      ]),
    );
    expect(find.text('Einsätze'), findsOneWidget);
    expect(find.text('Heineken'), findsOneWidget);
    expect(find.text('Lohn'), findsOneWidget);
    expect(find.text('Alle Reinigungen abgeschlossen'), findsOneWidget);
  });

  testWidgets('Kopfzeile zaehlt die offenen Punkte', (tester) async {
    await tester.pumpWidget(
      rahmen([
        b('r1', PruefStatus.rot),
        b('r2', PruefStatus.gelb),
        b('r3', PruefStatus.gruen),
      ]),
    );
    expect(find.textContaining('2 von 3'), findsOneWidget);
  });

  testWidgets('alles gruen meldet sich', (tester) async {
    await tester.pumpWidget(rahmen([b('r1', PruefStatus.gruen)]));
    expect(find.textContaining('Alles erledigt'), findsOneWidget);
  });

  testWidgets('Tipp auf eine Zeile mit Ziel meldet den Befund', (tester) async {
    Pruefbefund? getippt;
    await tester.pumpWidget(
      rahmen([
        b('r1', PruefStatus.rot, titel: 'Mit Ziel', route: '/rechnungen'),
      ], onZeile: (x) => getippt = x),
    );
    await tester.tap(find.text('Mit Ziel'));
    expect(getippt?.regelId, 'r1');
  });

  testWidgets('auf 360 px kein Ueberlauf, kein ListTile', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      rahmen([
        b(
          'r1',
          PruefStatus.rot,
          titel: 'Jede Reinigung hat ihre Ertragsbuchung',
        ),
        b(
          'r2',
          PruefStatus.gelb,
          gruppe: 'Bank',
          titel: 'Bankauszug importiert und geprüft',
        ),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsNothing);
  });
}
