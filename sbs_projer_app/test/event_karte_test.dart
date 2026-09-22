import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/event_karte.dart';

/// EventKarten auf Heute (v0.132.0): pro Event im 7-Tage-Fenster eine Karte
/// mit dem Betriebsnamen; ausserhalb des Fensters oder ohne Events bleibt
/// die Startseite leer (`SizedBox.shrink`), also kein Text.
void main() {
  BetriebLocal betrieb(String serverId, String name) => BetriebLocal()
    ..userId = 'u'
    ..name = name
    ..serverId = serverId;

  EventLocal event(String betriebId, DateTime von) => EventLocal()
    ..userId = 'u'
    ..betriebId = betriebId
    ..jahr = von.year
    ..terminVon = von;

  Widget rahmen(List<Override> overrides) => ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (c, s) => const EventKarten()),
          ]),
        ),
      );

  testWidgets('ein Event im Fenster: genau eine Karte mit Betriebsnamen',
      (tester) async {
    final jetzt = DateTime.now();
    final imFenster = event('b1', jetzt);
    final ausserhalb = event('b2', jetzt.subtract(const Duration(days: 30)));
    final betriebe = {'b1': betrieb('b1', 'Rössli'), 'b2': betrieb('b2', 'Krone')};

    await tester.pumpWidget(rahmen([
      eventsProvider.overrideWith((ref) async => [imFenster, ausserhalb]),
      betriebLookupProvider.overrideWithValue(betriebe),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rössli'), findsOneWidget);
    expect(find.textContaining('Krone'), findsNothing);
  });

  testWidgets('ohne Events im Fenster: nichts zu sehen', (tester) async {
    final jetzt = DateTime.now();
    final ausserhalb = event('b2', jetzt.subtract(const Duration(days: 30)));
    final betriebe = {'b2': betrieb('b2', 'Krone')};

    await tester.pumpWidget(rahmen([
      eventsProvider.overrideWith((ref) async => [ausserhalb]),
      betriebLookupProvider.overrideWithValue(betriebe),
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(EventKarten), findsOneWidget);
    expect(find.text('Krone'), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('Tippen auf die Karte führt zu /events/<routeId>',
      (tester) async {
    final jetzt = DateTime.now();
    final e = event('b1', jetzt)..id = 7; // feste Id -> feste routeId '7'.
    final betriebe = {'b1': betrieb('b1', 'Rössli')};

    await tester.pumpWidget(ProviderScope(
      overrides: [
        eventsProvider.overrideWith((ref) async => [e]),
        betriebLookupProvider.overrideWithValue(betriebe),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (c, s) => const EventKarten()),
          GoRoute(
            path: '/events/:id',
            builder: (c, s) => Text('Event ${s.pathParameters['id']}'),
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Rössli'));
    await tester.pumpAndSettle();

    expect(find.text('Event 7'), findsOneWidget);
  });
}
