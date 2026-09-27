import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/eigene_aufgabe.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgabe_dialog.dart';

/// Formular «Neue Aufgabe» / «Aufgabe bearbeiten» mit Betriebsfeld
/// (Migration 212, Entscheid Daniel 27.09.2026) — am Handy (360 px).

BetriebLocal _betrieb(String id, String name, String ort) => BetriebLocal()
  ..serverId = id
  ..name = name
  ..ort = ort;

final _betriebe = [
  _betrieb('1', 'Adler', 'Chur'),
  _betrieb('2', 'Bären', 'Davos'),
];

/// Öffnet den Dialog über einen Knopf und hält das Ergebnis fest.
class _Ergebnis {
  EigeneAufgabe? wert;
  bool fertig = false;
}

Future<_Ergebnis> _oeffne(
  WidgetTester tester, {
  EigeneAufgabe? vorlage,
  String? betriebId,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final ergebnis = _Ergebnis();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => GestureDetector(
            onTap: () async {
              ergebnis.wert = await zeigeAufgabeDialog(
                context,
                betriebe: _betriebe,
                vorlage: vorlage,
                betriebId: betriebId,
              );
              ergebnis.fertig = true;
            },
            child: const Text('öffnen'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('öffnen'));
  await tester.pumpAndSettle();
  return ergebnis;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('Anlegen mit vorbelegtem Betrieb (Betriebsseite)', (
    tester,
  ) async {
    final e = await _oeffne(tester, betriebId: '1');
    expect(find.text('Neue Aufgabe'), findsOneWidget);
    expect(find.text('Adler, Chur'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const Key('aufgabe_titel')),
      '  Hahn mitnehmen ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('aufgabe_speichern')));
    await tester.pumpAndSettle();

    expect(e.fertig, isTrue);
    expect(e.wert?.id, '');
    expect(e.wert?.titel, 'Hahn mitnehmen');
    expect(e.wert?.betriebId, '1');
    expect(e.wert?.faelligAm, isNull);
  });

  testWidgets('ohne Titel lässt sich nichts anlegen', (tester) async {
    final e = await _oeffne(tester);
    await tester.tap(find.byKey(const Key('aufgabe_speichern')));
    await tester.pumpAndSettle();
    expect(e.fertig, isFalse);
    expect(find.text('Neue Aufgabe'), findsOneWidget);
  });

  testWidgets('Betrieb ist optional und leerbar (Kreuz)', (tester) async {
    final e = await _oeffne(tester, betriebId: '1');
    await tester.enterText(find.byKey(const Key('aufgabe_titel')), 'Bank');
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(find.byIcon(Icons.clear), findsNothing);
    await tester.tap(find.byKey(const Key('aufgabe_speichern')));
    await tester.pumpAndSettle();
    expect(e.wert?.titel, 'Bank');
    expect(e.wert?.betriebId, isNull);
  });

  testWidgets('Betrieb über die Suche wählen', (tester) async {
    final e = await _oeffne(tester);
    await tester.enterText(find.byKey(const Key('aufgabe_titel')), 'Fass');
    await tester.enterText(find.widgetWithText(TextFormField, 'Betrieb (optional)'), 'dav');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bären'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aufgabe_speichern')));
    await tester.pumpAndSettle();
    expect(e.wert?.betriebId, '2');
  });

  testWidgets('Bearbeiten: Werte vorbelegt, Id bleibt, Datum entfernbar', (
    tester,
  ) async {
    final e = await _oeffne(
      tester,
      vorlage: EigeneAufgabe(
        id: 'a1',
        titel: 'Zapfhahn bestellen',
        faelligAm: DateTime(2026, 9, 1),
        betriebId: '2',
      ),
    );
    expect(find.text('Aufgabe bearbeiten'), findsOneWidget);
    expect(find.text('Zapfhahn bestellen'), findsOneWidget);
    expect(find.text('01.09.2026'), findsOneWidget);
    expect(find.text('Bären, Davos'), findsOneWidget);
    expect(find.text('Speichern'), findsOneWidget);

    await tester.tap(find.byKey(const Key('aufgabe_datum_leeren')));
    await tester.pump();
    expect(find.text('Kein Datum'), findsOneWidget);
    await tester.tap(find.byKey(const Key('aufgabe_speichern')));
    await tester.pumpAndSettle();

    expect(e.wert?.id, 'a1');
    expect(e.wert?.titel, 'Zapfhahn bestellen');
    expect(e.wert?.faelligAm, isNull);
    expect(e.wert?.betriebId, '2');
  });

  testWidgets('Abbrechen gibt null zurück', (tester) async {
    final e = await _oeffne(tester, betriebId: '1');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(e.fertig, isTrue);
    expect(e.wert, isNull);
  });

  testWidgets('keine Material-Knöpfe im Dialog (CanvasKit)', (tester) async {
    await _oeffne(tester, betriebId: '1');
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  test('neueAufgabeDialog nutzt den Baustein mit Betriebsfeld', () {
    final code = File(
      'lib/presentation/widgets/aufgaben_aktionen.dart',
    ).readAsStringSync();
    expect(code, contains('zeigeAufgabeDialog('));
    expect(code, contains('betriebId: eingabe.betriebId'));
    expect(code, contains('AufgabenRepository.eigeneAendern('));
  });
}
