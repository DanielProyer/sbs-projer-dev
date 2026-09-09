import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/screens/auswertungen/nutzung_screen.dart';

Widget _screen(NutzungStand stand) => ProviderScope(
      overrides: [
        nutzungProvider.overrideWith((ref) async => stand),
      ],
      child: const MaterialApp(home: NutzungScreen()),
    );

void main() {
  testWidgets('ohne Messdaten erklärt der Screen, was passieren wird',
      (tester) async {
    await tester.pumpWidget(_screen(const NutzungStand(
      zeilen: [],
      von: null,
      bis: null,
      tage: 0,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Noch nichts gemessen'), findsOneWidget);
    expect(find.textContaining('Handy und PC'), findsOneWidget);
  });

  testWidgets('sortiert nach Gesamtzahl und trennt Handy von PC',
      (tester) async {
    await tester.pumpWidget(_screen(NutzungStand(
      zeilen: const [
        NutzungZeile(route: '/touren', handy: 40, desktop: 2),
        NutzungZeile(route: '/buchhaltung', handy: 1, desktop: 25),
        NutzungZeile(route: '/anlagen', handy: 0, desktop: 1),
      ],
      von: DateTime(2026, 9, 9),
      bis: DateTime(2026, 9, 30),
      tage: 15,
    )));
    await tester.pumpAndSettle();

    expect(find.text('69 Aufrufe an 15 Tagen'), findsOneWidget);
    expect(find.textContaining('09.09. bis 30.09.'), findsOneWidget);
    expect(find.textContaining('3 verschiedene Bereiche'), findsOneWidget);

    // Die Aufteilung Werkstatt/Büro ist der Punkt der Messung (Befund 4).
    expect(find.text('Handy 41 (59 %)'), findsOneWidget);
    expect(find.text('PC 28 (41 %)'), findsOneWidget);

    // Reihenfolge: der meistgenutzte Bereich zuoberst.
    final routen = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((s) => s != null && s.startsWith('/'))
        .toList();
    expect(routen, ['/touren', '/buchhaltung', '/anlagen']);
  });

  testWidgets('eine kaum genutzte Route bleibt sichtbar, nicht abgeschnitten',
      (tester) async {
    // Genau diese Zeilen sind die interessanten: Was fast nie geöffnet wird,
    // ist der Kandidat fürs Aufräumen (A6).
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_screen(NutzungStand(
      zeilen: const [
        NutzungZeile(route: '/reinigungen', handy: 200, desktop: 0),
        NutzungZeile(route: '/bergkundenpauschalen', handy: 1, desktop: 0),
      ],
      von: DateTime(2026, 9, 9),
      bis: DateTime(2026, 9, 30),
      tage: 15,
    )));
    await tester.pumpAndSettle();

    expect(find.text('/bergkundenpauschalen'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
