import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/presentation/widgets/rueckweg_knopf.dart';

/// A2 (Runde 5, 26.09.2026): Ein direkt per URL/Link geöffneter Screen
/// (Aufgabe, Kalender, Reload) hat nichts zum Zurückgehen — die AppBar
/// zeigte dann gar keinen Pfeil, und `context.pop()` nach dem Löschen lief
/// ins Leere.
void main() {
  group('rueckwegZiel', () {
    test('kann zurück → pop (null)', () {
      expect(rueckwegZiel(true, '/heineken'), isNull);
    });

    test('kann nicht zurück → Rückfall-Route', () {
      expect(rueckwegZiel(false, '/heineken'), '/heineken');
    });
  });

  group('RueckwegKnopf', () {
    GoRouter router(String start) => GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: '/rueckfall',
          builder: (context, state) =>
              const Scaffold(body: Text('Rückfall')),
        ),
        GoRoute(
          path: '/liste',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Liste'),
                GestureDetector(
                  onTap: () => context.push('/detail'),
                  child: const Text('öffnen'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/detail',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              leading: const RueckwegKnopf(fallback: '/rueckfall'),
              title: const Text('Detail'),
            ),
          ),
        ),
      ],
    );

    testWidgets('direkt geöffnet → Pfeil da, führt zur Rückfall-Route', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router('/detail')),
      );
      expect(find.text('Detail'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byType(RueckwegKnopf));
      await tester.pumpAndSettle();
      expect(find.text('Rückfall'), findsOneWidget);
      expect(find.text('Detail'), findsNothing);
    });

    testWidgets('aus der Liste geöffnet → geht eine Seite zurück', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router('/liste')),
      );
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);

      await tester.tap(find.byType(RueckwegKnopf));
      await tester.pumpAndSettle();
      expect(find.text('Liste'), findsOneWidget);
      expect(find.text('Rückfall'), findsNothing);
    });
  });
}
