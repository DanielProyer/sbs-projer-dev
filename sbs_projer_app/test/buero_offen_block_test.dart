import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/widgets/buero_offen_block.dart';

final heute = DateTime(2026, 9, 16, 9);

AufgabenEintrag e(
  String titel, {
  bool vorrat = false,
  DateTime? faellig,
  String route = '/buchhaltung',
}) => AufgabenEintrag(
  quelle: AufgabenQuelle.detektor,
  key: titel,
  titel: titel,
  faellig: faellig,
  route: route,
  istVorrat: vorrat,
);

Widget rahmen(
  List<AufgabenEintrag> liste, {
  ValueChanged<AufgabenEintrag>? onDorthin,
}) => MaterialApp(
  home: Scaffold(
    body: ListView(
      children: [
        BueroOffenBlock(
          eintraege: liste,
          heute: heute,
          onDorthin: onDorthin ?? (_) {},
          onSnooze: (_, _) {},
          onErledigt: (_) {},
        ),
      ],
    ),
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('Ueberschrift und Eintraege', (tester) async {
    await tester.pumpWidget(
      rahmen([e('MWST Q3 2026 einreichen', faellig: heute)]),
    );
    expect(find.text('Was ist offen?'), findsOneWidget);
    expect(find.text('MWST Q3 2026 einreichen'), findsOneWidget);
  });

  testWidgets('Fristen stehen vor Vorraeten', (tester) async {
    await tester.pumpWidget(
      rahmen([
        e('23 Bank-Buchungen prüfen', vorrat: true),
        e('MWST Q3 2026 einreichen', faellig: heute),
        e('7 Eingangsrechnungen offen', vorrat: true),
        e('Heineken-Rechnung August erstellen', faellig: heute),
      ]),
    );
    final y = <String, double>{
      for (final t in [
        'MWST Q3 2026 einreichen',
        'Heineken-Rechnung August erstellen',
        '23 Bank-Buchungen prüfen',
        '7 Eingangsrechnungen offen',
      ])
        t: tester.getTopLeft(find.text(t)).dy,
    };
    expect(
      y['MWST Q3 2026 einreichen']! < y['23 Bank-Buchungen prüfen']!,
      isTrue,
    );
    expect(
      y['Heineken-Rechnung August erstellen']! < y['23 Bank-Buchungen prüfen']!,
      isTrue,
    );
  });

  testWidgets('Leerzustand', (tester) async {
    await tester.pumpWidget(rahmen(const []));
    expect(find.text('Nichts offen 🎉'), findsOneWidget);
  });

  testWidgets('Tipp meldet den Eintrag', (tester) async {
    AufgabenEintrag? getippt;
    await tester.pumpWidget(
      rahmen([
        e('MWST Q3 2026 einreichen', faellig: heute),
      ], onDorthin: (a) => getippt = a),
    );
    await tester.tap(find.text('MWST Q3 2026 einreichen'));
    expect(getippt?.key, 'MWST Q3 2026 einreichen');
  });

  testWidgets('kein ListTile, auch auf 360 px kein Ueberlauf', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      rahmen([
        e(
          '7 Mail-Rechnungen ohne Versandvermerk — Postausgang prüfen',
          vorrat: true,
        ),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsNothing);
  });
}
