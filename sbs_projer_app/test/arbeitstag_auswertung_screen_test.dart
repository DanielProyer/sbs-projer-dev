import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/presentation/providers/fahrten_providers.dart';
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
    startPosition: null,
    endPosition: null,
  ),
  (
    datum: DateTime(2026, 8, 4),
    beginn: '08:40',
    ende: '16:24',
    kmStart: 78969,
    kmEnde: 79061,
    startPosition: null,
    endPosition: null,
  ),
  (
    datum: DateTime(2026, 8, 5),
    beginn: '07:37',
    ende: '18:47',
    kmStart: 79061,
    kmEnde: 79239,
    startPosition: null,
    endPosition: null,
  ),
];

/// 9 Besuche am 03.08., 2 am 04.08., 7 am 05.08. — wie in der Datenbank.
final _besucheAugust = <DateTime, int>{
  DateTime(2026, 8, 3): 9,
  DateTime(2026, 8, 4): 2,
  DateTime(2026, 8, 5): 7,
};

const _halt = Halt(
  typ: HaltTyp.betrieb,
  id: 'b',
  name: 'Betrieb',
  quelle: 'reinigung',
);

/// «Fahrten aus der Kette» je Tag (Zähler: 84 / 92 / 178 km). [anzahl]
/// Platzhalter-Fahrten, davon [ohneKm] ohne Strecke.
TagesFahrten _fahrtenTag(
  double km,
  int zaehler, {
  int ohneKm = 0,
  int anzahl = 0,
}) => TagesFahrten(
  fahrten: [
    for (var i = 0; i < anzahl; i++) const Fahrt(von: _halt, nach: _halt),
  ],
  ohneZeit: const [],
  kmFahrten: km,
  fahrtenOhneKm: ohneKm,
  kmZaehler: zaehler,
  befunde: const [],
);

final _fahrtenAugust = <DateTime, TagesFahrten>{
  DateTime(2026, 8, 3): _fahrtenTag(70.4, 84), // Δ +13.6 → auffällig
  DateTime(2026, 8, 4): _fahrtenTag(90.0, 92), // Δ +2 → im Rahmen
  DateTime(2026, 8, 5): _fahrtenTag(181.2, 178), // Δ −3.2 → im Rahmen
};

List<Override> _overrides({
  required Future<Map<DateTime, int>> Function() besuche,
  required Future<Map<DateTime, TagesFahrten>> Function() fahrten,
}) => [
  arbeitstageProvider.overrideWith((ref, m) async => _august),
  besucheImMonatProvider.overrideWith((ref, m) async => besuche()),
  monatsFahrtenProvider.overrideWith((ref, m) => fahrten()),
];

Future<void> _pumpe(
  WidgetTester tester, {
  required Future<Map<DateTime, int>> Function() besuche,
  Future<Map<DateTime, TagesFahrten>> Function()? fahrten,
}) async {
  // Hoher Ausschnitt, damit auch die Tagesliste unter den Kennzahlen baut.
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(
        besuche: besuche,
        fahrten: fahrten ?? () async => const {},
      ),
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

  group('Arbeitstag-Auswertung — Fahrten aus der Kette', () {
    testWidgets('je Tag Fahrten-km und Δ, rot nur ausserhalb der Toleranz', (
      tester,
    ) async {
      await _pumpe(
        tester,
        besuche: () async => _besucheAugust,
        fahrten: () async => _fahrtenAugust,
      );
      await tester.pumpAndSettle();

      final auffaellig = tester.widget<Text>(
        find.textContaining('Fahrten 70 km · Δ +14 km'),
      );
      final imRahmen = tester.widget<Text>(
        find.textContaining('Fahrten 90 km · Δ +2 km'),
      );
      expect(find.textContaining('Fahrten 181 km · Δ −3 km'), findsOneWidget);

      TextStyle? deltaStil(Text t) =>
          ((t.textSpan! as TextSpan).children!.last as TextSpan).style;
      expect(deltaStil(auffaellig)?.color, AppColors.error);
      expect(deltaStil(imRahmen), isNull); // erbt das Grau der Zeile

      // Kennzahl: 70.4 + 90 + 181.2 = 341.6
      expect(find.text('342'), findsOneWidget);
      expect(find.text('0 Fahrten an 3 Tagen'), findsOneWidget);
    });

    testWidgets('Fahrten laden noch: keine Angabe statt «0 km»', (
      tester,
    ) async {
      final nieFertig = Completer<Map<DateTime, TagesFahrten>>();
      addTearDown(() => nieFertig.complete(const {}));
      await _pumpe(
        tester,
        besuche: () async => _besucheAugust,
        fahrten: () => nieFertig.future,
      );
      await tester.pumpAndSettle();

      // Tage sind da, nur ohne Fahrten-Zeile.
      expect(find.textContaining('9 Besuche'), findsOneWidget);
      expect(find.textContaining('Fahrten 0 km'), findsNothing);
      expect(find.textContaining('km · Δ'), findsNothing);
      expect(find.text('wird berechnet'), findsOneWidget);
    });

    testWidgets('Fahrten scheitern: Seite bleibt ohne Fahrten-Angabe', (
      tester,
    ) async {
      await _pumpe(
        tester,
        besuche: () async => _besucheAugust,
        fahrten: () async => throw 'keine Verbindung',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('9 Besuche'), findsOneWidget);
      expect(find.textContaining('km · Δ'), findsNothing);
      // Kennzahl: «–» statt dauerhaft «wird berechnet».
      expect(find.text('Fahrten-km (Kette)'), findsOneWidget);
      expect(find.text('wird berechnet'), findsNothing);
    });

    // Seit 29.09.2026 keine Luftlinien-km: Ein Tag mit fehlender Strecke
    // zeigt die Lücke statt eines Δ, das die Lücke als «unerklärt» zählte.
    testWidgets('Strecken fehlen: Lücke genannt, kein Δ', (tester) async {
      await _pumpe(
        tester,
        besuche: () async => _besucheAugust,
        fahrten: () async => {
          DateTime(2026, 8, 3): _fahrtenTag(70.4, 84, ohneKm: 1),
          DateTime(2026, 8, 4): _fahrtenTag(90.0, 92),
        },
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Fahrten 70 km (1 ohne Strecke)'),
        findsOneWidget,
      );
      expect(find.textContaining('Fahrten 70 km · Δ'), findsNothing);
      expect(find.textContaining('Fahrten 90 km · Δ +2 km'), findsOneWidget);
    });

    // Die Monatssumme zählt nur die bekannten Strecken — die Kennzahl muss
    // sagen, dass welche fehlen (Review 29.09.).
    testWidgets('Kennzahl «Fahrten-km (Kette)» nennt fehlende Strecken', (
      tester,
    ) async {
      await _pumpe(
        tester,
        besuche: () async => _besucheAugust,
        fahrten: () async => {
          DateTime(2026, 8, 3): _fahrtenTag(70.4, 84, anzahl: 4, ohneKm: 1),
          DateTime(2026, 8, 4): _fahrtenTag(90.0, 92, anzahl: 3),
          DateTime(2026, 8, 5): _fahrtenTag(181.2, 178, anzahl: 5, ohneKm: 2),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Fahrten-km (Kette)'), findsOneWidget);
      expect(find.text('342'), findsOneWidget); // 70.4 + 90 + 181.2
      expect(find.text('12 Fahrten, 3 ohne Strecke'), findsOneWidget);
      expect(find.textContaining('Fahrten an 3 Tagen'), findsNothing);
    });

    testWidgets('Kennzahl ohne Lücken: wie bisher «… an N Tagen»', (
      tester,
    ) async {
      await _pumpe(
        tester,
        besuche: () async => _besucheAugust,
        fahrten: () async => {
          DateTime(2026, 8, 3): _fahrtenTag(70.4, 84, anzahl: 4),
          DateTime(2026, 8, 4): _fahrtenTag(90.0, 92, anzahl: 3),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('7 Fahrten an 2 Tagen'), findsOneWidget);
      expect(find.textContaining('ohne Strecke'), findsNothing);
    });

    testWidgets('Δ erst runden, dann Vorzeichen — kein «−0 km»', (
      tester,
    ) async {
      await _pumpe(
        tester,
        besuche: () async => _besucheAugust,
        fahrten: () async => {
          DateTime(2026, 8, 3): _fahrtenTag(84.4, 84), // Δ −0.4
          DateTime(2026, 8, 4): _fahrtenTag(92.6, 92), // Δ −0.6
          DateTime(2026, 8, 5): _fahrtenTag(177.7, 178), // Δ +0.3
        },
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Fahrten 84 km · Δ ±0 km'), findsOneWidget);
      expect(find.textContaining('Fahrten 93 km · Δ −1 km'), findsOneWidget);
      expect(find.textContaining('Fahrten 178 km · Δ ±0 km'), findsOneWidget);
      expect(find.textContaining('−0'), findsNothing);
      expect(find.textContaining('+0'), findsNothing);
    });

    testWidgets('Tageszeile öffnet den Fahrten-Screen des Tages', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1100, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ArbeitstagAuswertungScreen(),
          ),
          GoRoute(
            path: '/auswertungen/arbeitstage/:datum/fahrten',
            builder: (context, state) =>
                Text('Fahrten-Screen ${state.pathParameters['datum']}'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(
            besuche: () async => _besucheAugust,
            fahrten: () async => _fahrtenAugust,
          ),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('9 Besuche'));
      await tester.pumpAndSettle();
      expect(find.text('Fahrten-Screen 2026-08-03'), findsOneWidget);

      // Das Muster oben muss das der echten App sein. (Der Erreichbarkeits-
      // Wächter nimmt Detail-Routen mit `/:` bewusst aus — dieser Test ist
      // ihr Ersatz für den Fahrten-Screen.)
      expect(
        File('lib/core/config/router.dart').readAsStringSync(),
        contains("path: '/auswertungen/arbeitstage/:datum/fahrten'"),
      );
    });
  });
}
