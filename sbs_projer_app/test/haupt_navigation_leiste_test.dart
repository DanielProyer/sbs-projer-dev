import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/haupt_navigation.dart';

/// Die Leiste folgt dem Router auch über Weiterleitungen (22.09.2026).
///
/// WARUM: Sie hörte auf `routeInformationProvider`. Eine Weiterleitung
/// meldet ihm den neuen Pfad aber ohne `notifyListeners()` (go_router
/// 17.5.0, `information_provider.dart` `routerReportsNewRouteInformation`)
/// — die Leiste blieb auf dem Stand davor. Folge: Auf dem Anmeldebildschirm
/// stand die Leiste mit «Heute», nach dem Anmelden fehlte sie, und nach
/// Alias-Weiterleitungen leuchtete das falsche Ziel. Der Router der Tests
/// bildet den Auth-Guard aus `router.dart` nach.
GoRouter _router({required bool angemeldet, String start = '/'}) => GoRouter(
  initialLocation: start,
  redirect: (context, state) {
    final login = state.matchedLocation == '/login';
    if (!angemeldet && !login) return '/login';
    if (angemeldet && login) return '/';
    if (state.matchedLocation == '/alt') return '/betriebe';
    return null;
  },
  routes: [
    for (final p in [
      '/',
      '/login',
      '/mehr',
      '/alt',
      '/betriebe',
      '/buchhaltung',
      '/reinigungen/neu',
    ])
      GoRoute(path: p, builder: (context, state) => Text('Seite $p')),
  ],
);

Future<void> _pump(WidgetTester tester, GoRouter r) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: r,
      // Wie in app.dart: Leiste unter dem Router-Inhalt. Das Material
      // liefert dort die AufgabenGlocke darüber.
      builder: (context, child) => Material(
        child: Column(
          children: [
            Expanded(child: child ?? const SizedBox.shrink()),
            HauptNavigationLeiste(goRouter: r),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _farbe(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.color;

void main() {
  testWidgets('auf dem Anmeldebildschirm keine Leiste', (tester) async {
    final r = _router(angemeldet: false);
    await _pump(tester, r);
    expect(find.text('Seite /login'), findsOneWidget);
    expect(find.text('Heute'), findsNothing);
    expect(find.text('Mehr'), findsNothing);
  });

  testWidgets('nach der Weiterleitung vom Login ist die Leiste da', (
    tester,
  ) async {
    final r = _router(angemeldet: true, start: '/login');
    await _pump(tester, r);
    expect(find.text('Seite /'), findsOneWidget);
    expect(_farbe(tester, 'Heute'), AppColors.primary);
  });

  testWidgets('Alias-Weiterleitung laesst das Ziel dahinter leuchten', (
    tester,
  ) async {
    final r = _router(angemeldet: true);
    await _pump(tester, r);
    r.go('/alt');
    await tester.pumpAndSettle();
    expect(find.text('Seite /betriebe'), findsOneWidget);
    // Nicht «Mehr»: Das wäre der Pfad vor der Weiterleitung (/alt).
    expect(_farbe(tester, 'Betriebe'), AppColors.primary);
    expect(_farbe(tester, 'Mehr'), AppColors.textSecondary);
  });

  testWidgets('push und pop: oberste Route zaehlt, Formular ohne Leiste', (
    tester,
  ) async {
    final r = _router(angemeldet: true);
    await _pump(tester, r);

    r.push('/buchhaltung');
    await tester.pumpAndSettle();
    expect(_farbe(tester, 'Mehr'), AppColors.primary);

    r.push('/reinigungen/neu');
    await tester.pumpAndSettle();
    expect(find.text('Heute'), findsNothing);

    r.pop();
    await tester.pumpAndSettle();
    expect(_farbe(tester, 'Mehr'), AppColors.primary);

    r.pop();
    await tester.pumpAndSettle();
    expect(_farbe(tester, 'Heute'), AppColors.primary);
  });
}
