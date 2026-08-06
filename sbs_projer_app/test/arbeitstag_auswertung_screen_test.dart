import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/screens/auswertungen/arbeitstag_auswertung_screen.dart';

// Befund 06.08.2026 («Warum hat es keine Besuche?»): Die Besuchszahl kam aus
// dem allgemeinen Reinigungs-Provider, der auf Web zuerst ALLE ~8'500
// Reinigungen laedt (~4,8 MB in 9 Anfragen). Der Screen wartete darauf nicht:
// sein Ladezustand deckte nur die winzige Tagesplan-Abfrage ab, die Besuche
// kamen ueber `valueOrNull ?? []` herein. Solange der grosse Load lief — oder
// wenn er scheiterte — zeigte der Screen eine fertig aussehende Seite mit
// «0 Besuche», ununterscheidbar von einer echten Null.
//
// Soll: Besuche monatsweise laden (~130 statt 8'500 Zeilen) UND ihren Lade-
// bzw. Fehlerzustand sichtbar machen.

/// Die echten Tagesplan-Zeilen vom August 2026.
final _august = <ArbeitstagRohdaten>[
  (
    datum: DateTime(2026, 8, 3),
    beginn: '07:03',
    ende: '17:35',
    kmStart: 78885,
    kmEnde: 78969,
  ),
  (
    datum: DateTime(2026, 8, 4),
    beginn: '08:40',
    ende: '16:24',
    kmStart: 78969,
    kmEnde: 79061,
  ),
  (
    datum: DateTime(2026, 8, 5),
    beginn: '07:37',
    ende: '18:47',
    kmStart: 79061,
    kmEnde: 79239,
  ),
];

/// 9 Besuche am 03.08., 2 am 04.08., 7 am 05.08. — wie in der Datenbank.
final _besucheAugust = <DateTime, int>{
  DateTime(2026, 8, 3): 9,
  DateTime(2026, 8, 4): 2,
  DateTime(2026, 8, 5): 7,
};

Future<void> _pumpe(
  WidgetTester tester, {
  required Future<Map<DateTime, int>> Function() besuche,
}) async {
  // Hoher Ausschnitt, damit auch die Tagesliste unter den Kennzahlen baut.
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        arbeitstageProvider.overrideWith((ref, m) async => _august),
        besucheImMonatProvider.overrideWith((ref, m) async => besuche()),
      ],
      child: const MaterialApp(home: ArbeitstagAuswertungScreen()),
    ),
  );
  await tester.pump(); // Tagesplan da, Besuche je nach Future noch nicht
}

void main() {
  group('Arbeitstag-Auswertung — Besuche', () {
    testWidgets('beide Quellen geladen: Kennzahl und Tageszeilen stimmen', (
      tester,
    ) async {
      await _pumpe(tester, besuche: () async => _besucheAugust);
      await tester.pumpAndSettle();

      expect(find.text('18'), findsOneWidget); // 9 + 2 + 7
      expect(find.textContaining('9 Besuche'), findsOneWidget);
      expect(find.textContaining('2 Besuche'), findsOneWidget);
      expect(find.textContaining('7 Besuche'), findsOneWidget);
    });

    testWidgets('Besuche laden noch: Ladeanzeige statt stiller Null', (
      tester,
    ) async {
      final nieFertig = Completer<Map<DateTime, int>>();
      addTearDown(() => nieFertig.complete(const {}));
      await _pumpe(tester, besuche: () => nieFertig.future);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Es darf KEINE fertige Seite mit 0 Besuchen erscheinen.
      expect(find.textContaining('0 Besuche'), findsNothing);
    });

    testWidgets('Besuche scheitern: Fehlerhinweis statt stiller Null', (
      tester,
    ) async {
      await _pumpe(
        tester,
        besuche: () async => throw 'keine Verbindung',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('nicht geladen'), findsOneWidget);
      expect(find.textContaining('0 Besuche'), findsNothing);
    });
  });
}
