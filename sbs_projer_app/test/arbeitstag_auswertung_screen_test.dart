import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/auswertungen/arbeitstag_auswertung_screen.dart';

// Diagnose 06.08.2026 («Warum hat es keine Besuche?»): Der Screen holt den
// Tagesrahmen aus `tagesplaene` (winzige Monatsabfrage) und die Besuche aus
// `reinigungenProvider` — der auf Web ZUERST alle ~8'500 Reinigungen laedt.
//
// Der `async.when(...)`-Ladezustand deckt nur die Tagesplan-Abfrage ab. Die
// Besuche kommen ueber `valueOrNull ?? []` herein: solange der grosse Load
// laeuft (oder wenn er scheitert), rendert der Screen eine vollstaendig
// aussehende Seite mit «0 Besuche» — ununterscheidbar von einer echten Null.
//
// Beide Tests halten genau diesen Unterschied fest.

ReinigungLocal _reinigung(String betriebId, DateTime datum) => ReinigungLocal()
  ..serverId = 'r-$betriebId-${datum.day}'
  ..userId = 'u1'
  ..anlageId = 'a1'
  ..betriebId = betriebId
  ..datum = datum
  ..status = 'abgeschlossen';

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
List<ReinigungLocal> _reinigungenAugust() => [
  for (var i = 0; i < 9; i++) _reinigung('b$i', DateTime(2026, 8, 3)),
  for (var i = 0; i < 2; i++) _reinigung('c$i', DateTime(2026, 8, 4)),
  for (var i = 0; i < 7; i++) _reinigung('d$i', DateTime(2026, 8, 5)),
];

Future<void> _pumpe(
  WidgetTester tester,
  List<ReinigungLocal> reinigungen,
) async {
  // Hoher Ausschnitt, damit auch die Tagesliste unter den Kennzahlen baut.
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reinigungenProvider.overrideWithValue(reinigungen),
        arbeitstageProvider.overrideWith((ref, m) async => _august),
      ],
      child: const MaterialApp(home: ArbeitstagAuswertungScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Arbeitstag-Auswertung — Besuche', () {
    testWidgets('mit geladenen Reinigungen stimmen Kennzahl und Tageszeilen', (
      tester,
    ) async {
      await _pumpe(tester, _reinigungenAugust());

      // Kennzahl «Besuche» = 9 + 2 + 7
      expect(find.text('18'), findsOneWidget);
      expect(find.textContaining('9 Besuche'), findsOneWidget);
      expect(find.textContaining('2 Besuche'), findsOneWidget);
      expect(find.textContaining('7 Besuche'), findsOneWidget);
    });

    testWidgets(
      'ohne geladene Reinigungen: Tage erscheinen, Besuche still auf 0',
      (tester) async {
        await _pumpe(tester, const []);

        // Die Tage sind da (aus dem Tagesplan) …
        expect(find.textContaining('07:03–17:35'), findsOneWidget);
        // … aber jeder Tag meldet 0 Besuche, ohne jeden Hinweis darauf,
        // dass die Grundlage noch fehlt. Genau das sieht der Nutzer.
        expect(find.textContaining('0 Besuche'), findsNWidgets(3));
      },
    );
  });
}
