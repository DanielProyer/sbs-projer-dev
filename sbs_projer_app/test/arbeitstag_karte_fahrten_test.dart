import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/presentation/providers/fahrten_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/arbeitstag_karte.dart';

/// Arbeitstag-Karte: Zeile «Fahrten heute» nach dem Feierabend.

GespeicherterTagesplan _plan({String? ende}) => (
  eintraege: const <TourEintrag>[],
  arbeitsbeginn: '07:00',
  planBeginn: null,
  arbeitsende: ende,
  kmStand: ende == null ? null : 50148,
  kmStart: 50000,
  startLat: null,
  startLng: null,
  endLat: null,
  endLng: null,
  pauseMinuten: null,
  pauseStart: null,
);

TagesFahrten _fahrten({double km = 142.6, int ohneKm = 0}) => TagesFahrten(
  fahrten: const [],
  ohneZeit: const [],
  kmFahrten: km,
  fahrtenOhneKm: ohneKm,
  kmZaehler: 148,
  befunde: const [],
);

/// Das `Text.rich` der Zeile «Fahrten heute».
final _zeile = find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.textSpan?.toPlainText().startsWith('Fahrten heute') ?? false),
);

/// Der Δ-Teil der Zeile (letztes Kind des Text.rich).
TextSpan _deltaSpan(WidgetTester tester) {
  final kinder = (tester.widget<Text>(_zeile).textSpan! as TextSpan).children!;
  return kinder.last as TextSpan;
}

Future<void> _pumpe(
  WidgetTester tester, {
  required String? ende,
  required Future<TagesFahrten?> Function() fahrten,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: ArbeitstagKarte()),
      ),
      GoRoute(
        path: '/auswertungen/arbeitstage/:datum/fahrten',
        builder: (_, s) =>
            Scaffold(body: Text('Fahrten-Screen ${s.pathParameters['datum']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gespeicherterTagesplanProvider.overrideWith(
          (ref, datum) async => _plan(ende: ende),
        ),
        tagesFahrtenProvider.overrideWith((ref, datum) => fahrten()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _heutePfad() {
  final j = DateTime.now();
  return '${j.year}-${j.month.toString().padLeft(2, '0')}-'
      '${j.day.toString().padLeft(2, '0')}';
}

void main() {
  testWidgets('vor dem Feierabend keine Zeile — Provider bleibt ungestartet', (
    tester,
  ) async {
    var gestartet = false;
    await _pumpe(
      tester,
      ende: null,
      fahrten: () async {
        gestartet = true;
        return _fahrten();
      },
    );
    expect(_zeile, findsNothing);
    expect(
      gestartet,
      isFalse,
      reason: 'kein Monats-Provider, kein Nachrouten vor dem Feierabend',
    );
  });

  testWidgets('nach dem Feierabend: Zeile mit grauem Δ im Rahmen', (
    tester,
  ) async {
    await _pumpe(tester, ende: '17:30', fahrten: () async => _fahrten());
    expect(_zeile, findsOneWidget);
    expect(
      tester.widget<Text>(_zeile).textSpan!.toPlainText(),
      'Fahrten heute: 0 · 143 km · Zähler 148 km (+5)',
    );
    expect(_deltaSpan(tester).style?.color, isNot(AppColors.error));
  });

  testWidgets('auffällige Differenz: Δ rot', (tester) async {
    await _pumpe(tester, ende: '17:30', fahrten: () async => _fahrten(km: 120));
    expect(_deltaSpan(tester).text, ' (+28)');
    expect(_deltaSpan(tester).style?.color, AppColors.error);
  });

  testWidgets('Strecken fehlen: kein Δ, auch kein rotes', (tester) async {
    await _pumpe(
      tester,
      ende: '17:30',
      fahrten: () async => _fahrten(km: 120, ohneKm: 1),
    );
    expect(
      tester.widget<Text>(_zeile).textSpan!.toPlainText(),
      'Fahrten heute: 0 · 120 km (1 ohne Strecke) · Zähler 148 km',
    );
  });

  testWidgets('während des Ladens keine Zeile', (tester) async {
    final nieFertig = Completer<TagesFahrten?>();
    await _pumpe(tester, ende: '17:30', fahrten: () => nieFertig.future);
    expect(_zeile, findsNothing);
  });

  testWidgets('bei einem Fehler keine Zeile', (tester) async {
    await _pumpe(
      tester,
      ende: '17:30',
      fahrten: () async => throw StateError('offline'),
    );
    expect(_zeile, findsNothing);
  });

  testWidgets('Tipp führt zu den Fahrten des Tages', (tester) async {
    await _pumpe(tester, ende: '17:30', fahrten: () async => _fahrten());
    await tester.tap(_zeile);
    await tester.pumpAndSettle();
    expect(find.text('Fahrten-Screen ${_heutePfad()}'), findsOneWidget);
  });
}
