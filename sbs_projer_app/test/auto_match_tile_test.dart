import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/auto_match_tile.dart';

Widget _harness(double width) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: AutoMatchTile(
              betrag: "1'234.50 CHF",
              beschreibung: 'Hotel Alpina · Rechnung RG-2025-0123 · 05.01.2026',
              onVerbuchen: () {},
            ),
          ),
        ),
      ),
    );

const _betrag = "1'234.50 CHF";

void main() {
  // Eine Textzeile bei fontSize 15 ist ~18–22px hoch. >30 ⇒ mehrzeilig/senkrecht.
  const einzeiligMax = 30.0;

  for (final breite in [800.0, 320.0, 200.0]) {
    testWidgets('Betrag einzeilig + Details sichtbar bei Breite $breite',
        (tester) async {
      await tester.pumpWidget(_harness(breite));

      // Kein Overflow-Fehler.
      expect(tester.takeException(), isNull);

      // Betrag und Beschreibung sind vorhanden.
      expect(find.text(_betrag), findsOneWidget);
      expect(find.textContaining('Hotel Alpina'), findsOneWidget);

      // Betrag steht auf EINER Zeile (nicht senkrecht umgebrochen).
      final hoehe = tester.getSize(find.text(_betrag)).height;
      expect(hoehe, lessThan(einzeiligMax),
          reason: 'Betrag bei Breite $breite ist $hoehe px hoch → mehrzeilig');
    });
  }
}
