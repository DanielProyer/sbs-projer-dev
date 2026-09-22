import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sbs_projer_app/core/util/suche.dart';
import 'package:sbs_projer_app/presentation/providers/suche_provider.dart';
import 'package:sbs_projer_app/presentation/screens/suche/suche_screen.dart';

final _eingabe = SuchEingabe(
  betriebe: [
    for (var i = 1; i <= 7; i++)
      (id: 'b$i', name: 'Bar $i', ort: 'Chur', betriebNr: null, status: 'aktiv'),
  ],
  personen: const [
    (id: 'k1', vorname: 'Donato', nachname: 'Toscano', telefon: '079 108 41 08', betriebName: '4eri Bar'),
  ],
  rechnungen: [
    (id: 'r1', nummer: '2026-09-1449', betriebName: 'Heineken', datum: DateTime(2026, 9, 5), brutto: 10, zahlungsstatus: 'offen'),
  ],
  bereiche: const [
    (titel: 'MwSt-Abrechnung', untertitel: null, gruppe: 'Abschlüsse und Steuern', ziel: '/buchhaltung/mwst', stichwoerter: ['mwst']),
  ],
);

GoRouter _router() => GoRouter(
      initialLocation: '/suche',
      routes: [
        GoRoute(path: '/suche', builder: (c, s) => const SucheScreen()),
        GoRoute(path: '/', builder: (c, s) => const Text('Seite Heute')),
        GoRoute(
          path: '/betriebe',
          builder: (c, s) =>
              Text('Liste Betriebe ${s.uri.queryParameters['suche']}'),
        ),
        GoRoute(
          path: '/betriebe/:id',
          builder: (c, s) => Text('Betrieb ${s.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/buchhaltung/mwst',
          builder: (c, s) => const Text('Seite MwSt'),
        ),
      ],
    );

Future<GoRouter> _pump(WidgetTester tester) async {
  final r = _router();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [suchEingabeProvider.overrideWithValue(_eingabe)],
      child: MaterialApp.router(routerConfig: r),
    ),
  );
  await tester.pumpAndSettle();
  return r;
}

Future<void> _tippe(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Fokus im Feld beim Oeffnen', (tester) async {
    await _pump(tester);
    final feld = tester.widget<TextField>(find.byType(TextField));
    expect(feld.focusNode?.hasFocus, isTrue);
  });

  testWidgets('unter 2 Zeichen keine Treffer', (tester) async {
    await _pump(tester);
    await _tippe(tester, 'b');
    expect(find.text('Betriebe'), findsNothing);
  });

  testWidgets('Gruppen erscheinen, Deckel 5, alle N anzeigen', (tester) async {
    final r = await _pump(tester);
    await _tippe(tester, 'bar');
    expect(find.text('Betriebe'), findsOneWidget);
    expect(find.text('Personen'), findsOneWidget); // «4eri Bar»
    await tester.tap(find.text('alle 7 anzeigen'));
    await tester.pumpAndSettle();
    expect(find.text('Liste Betriebe bar'), findsOneWidget);
    expect(r.routerDelegate.state.uri.toString(), '/betriebe?suche=bar');
  });

  testWidgets('Tipp oeffnet Route und merkt Zuletzt geoeffnet', (tester) async {
    await _pump(tester);
    await _tippe(tester, 'mwst');
    await tester.tap(find.text('MwSt-Abrechnung'));
    await tester.pumpAndSettle();
    expect(find.text('Seite MwSt'), findsOneWidget);

    // zurück: Suchtext steht noch, und «Zuletzt geöffnet» kennt den Treffer
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    nav.pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'mwst',
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Zuletzt geöffnet'), findsOneWidget);
    expect(find.text('MwSt-Abrechnung'), findsOneWidget);
  });

  testWidgets('Nichts gefunden', (tester) async {
    await _pump(tester);
    await _tippe(tester, 'xyzxyz');
    expect(find.textContaining('Nichts gefunden'), findsOneWidget);
  });

  testWidgets('× loescht den Text', (tester) async {
    await _pump(tester);
    await _tippe(tester, 'bar');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(find.text('Betriebe'), findsNothing);
  });
}
