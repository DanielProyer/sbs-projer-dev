import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/tour_filter.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/tour_filter_leiste.dart';

/// Baut die Leiste in einem Bildschirm der Breite [breite].
Future<Set<TourFilter>?> _pumpe(
  WidgetTester tester, {
  required double breite,
  Set<TourFilter> ausgewaehlt = const {},
}) async {
  Set<TourFilter>? letzte;
  tester.view.physicalSize = Size(breite, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TourFilterLeiste(
          ausgewaehlt: ausgewaehlt,
          onChanged: (s) => letzte = s,
        ),
      ),
    ),
  );
  return letzte;
}

void main() {
  group('TourFilterLeiste', () {
    // 360 = schmales Android, 375 = iPhone SE, 412 = Pixel 9.
    for (final breite in [360.0, 375.0, 412.0]) {
      testWidgets('passt ohne Überlauf auf ${breite.toInt()} px', (
        tester,
      ) async {
        await _pumpe(tester, breite: breite, ausgewaehlt: standardTourFilter);
        // Ein Overflow würde die Testausführung mit einer FlutterError
        // beenden — takeException() bleibt nur ohne Überlauf leer.
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('zeigt alle fünf Knöpfe auf einer Zeile', (tester) async {
      await _pumpe(tester, breite: 375, ausgewaehlt: standardTourFilter);

      for (final f in TourFilter.values) {
        expect(find.text(tourFilterLabel(f)), findsOneWidget, reason: f.name);
      }

      // Gleiche Höhe (dy) für alle → es gibt nur eine Zeile.
      final ys = TourFilter.values
          .map((f) => tester.getCenter(find.text(tourFilterLabel(f))).dy)
          .toSet();
      expect(ys.length, 1, reason: 'Knöpfe liegen auf mehreren Zeilen: $ys');
    });

    testWidgets('Tipp auf Alle wählt exklusiv aus', (tester) async {
      Set<TourFilter>? gemeldet;
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TourFilterLeiste(
              ausgewaehlt: standardTourFilter,
              onChanged: (s) => gemeldet = s,
            ),
          ),
        ),
      );

      await tester.tap(find.text(tourFilterLabel(TourFilter.alle)));
      expect(gemeldet, {TourFilter.alle});
    });

    testWidgets('Tipp auf Fällig schaltet ihn ab', (tester) async {
      Set<TourFilter>? gemeldet;
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TourFilterLeiste(
              ausgewaehlt: standardTourFilter,
              onChanged: (s) => gemeldet = s,
            ),
          ),
        ),
      );

      await tester.tap(find.text(tourFilterLabel(TourFilter.faellig)));
      expect(gemeldet, isNot(contains(TourFilter.faellig)));
      expect(gemeldet, contains(TourFilter.ueberfaellig));
    });
  });
}
