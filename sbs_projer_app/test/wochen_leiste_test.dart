import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/screens/touren/widgets/wochen_leiste.dart';

/// Wochenwechsel und Tageswahl in einer Zeile (B5, v0.113.0).
void main() {
  group('kalenderwoche (ISO 8601)', () {
    test('Woche 1 ist die mit dem ersten Donnerstag', () {
      // 1.1.2026 ist ein Donnerstag → die Woche ab Mo 29.12.2025 ist KW 1.
      expect(kalenderwoche(DateTime(2025, 12, 29)), 1);
      expect(kalenderwoche(DateTime(2026, 1, 1)), 1);
      expect(kalenderwoche(DateTime(2026, 1, 4)), 1); // Sonntag derselben
      expect(kalenderwoche(DateTime(2026, 1, 5)), 2);
    });

    test('Tage vor dem ersten Donnerstag gehoeren ins Vorjahr', () {
      // 1.1.2027 ist ein Freitag → gehoert noch zur letzten Woche von 2026.
      expect(kalenderwoche(DateTime(2027, 1, 1)), 53);
    });

    test('eine Woche hat ueber alle sieben Tage dieselbe Nummer', () {
      final montag = DateTime(2026, 9, 14);
      for (var i = 0; i < 7; i++) {
        expect(
          kalenderwoche(montag.add(Duration(days: i))),
          38,
          reason: 'Tag $i der Woche',
        );
      }
    });
  });

  group('wochenTitel', () {
    test('Woche innerhalb eines Monats', () {
      expect(wochenTitel(DateTime(2026, 9, 14)), 'KW 38 · Sep 2026');
    });

    test('Woche ueber einen Monatswechsel nennt beide Monate', () {
      // Mo 28.09.2026 bis Sa 03.10.2026
      expect(wochenTitel(DateTime(2026, 9, 28)), 'KW 40 · Sep/Okt 2026');
    });

    test('kurz genug fuer die Titelzeile', () {
      // Drei Knoepfe rechts lassen wenig Platz; mit Tagesspanne wurde der
      // Titel abgeschnitten (Sichtpruefung 19.09.2026).
      for (final mo in [DateTime(2026, 9, 14), DateTime(2026, 9, 28)]) {
        expect(wochenTitel(mo).length, lessThanOrEqualTo(20));
      }
    });
  });

  group('gleicherTag', () {
    test('ignoriert die Uhrzeit', () {
      expect(
        gleicherTag(DateTime(2026, 9, 14, 7, 40), DateTime(2026, 9, 14, 23)),
        isTrue,
      );
      expect(
        gleicherTag(DateTime(2026, 9, 14), DateTime(2026, 9, 15)),
        isFalse,
      );
    });
  });

  group('Darstellung', () {
    Widget leiste({List<int>? counts}) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: WochenLeiste(
          weekStart: DateTime(2026, 9, 14),
          selectedDate: DateTime(2026, 9, 17),
          counts: counts ?? const [8, 11, 6, 9, 7, 0],
          onPrevious: () {},
          onNext: () {},
          onSelect: (_) {},
        ),
      ),
    );

    testWidgets('sechs Tage und beide Pfeile passen auf 360 px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(leiste());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Ueberlauf auf 360 px');
      for (final t in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.byTooltip('Vorherige Woche'), findsOneWidget);
      expect(find.byTooltip('Nächste Woche'), findsOneWidget);
    });

    testWidgets('haelt 130 % Systemschrift aus', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: leiste(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ein Tag ohne Eintraege zeigt keinen Zaehler', (tester) async {
      await tester.pumpWidget(leiste(counts: const [3, 0, 0, 0, 0, 0]));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      // Die Null selbst darf nirgends als Zaehler stehen.
      expect(find.text('0'), findsNothing);
    });

    testWidgets('bleibt bei einer zu kurzen counts-Liste heil', (tester) async {
      // Die Zaehler kommen aus einer Abfrage; bricht die ab, ist die Liste
      // womoeglich leer. Das darf die Leiste nicht umwerfen.
      await tester.pumpWidget(leiste(counts: const []));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Mo'), findsOneWidget);
    });

    testWidgets('die Leiste misst hoechstens 70 px', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(leiste());
      await tester.pumpAndSettle();

      final hoehe = tester.getSize(find.byType(WochenLeiste)).height;
      expect(
        hoehe,
        lessThanOrEqualTo(70),
        reason:
            'Der Sinn von B5 ist Platz fuer die Zeitachse: Die beiden alten '
            'Zeilen brauchten zusammen rund 130 px, diese eine misst 70. '
            'Wer sie wachsen laesst, nimmt den Gewinn wieder weg.',
      );
    });
  });
}
