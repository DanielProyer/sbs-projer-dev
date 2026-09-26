import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/detail/detail_karte.dart';

void main() {
  group('DetailKarte', () {
    testWidgets('leere kinder rendern nichts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DetailKarte(
            titel: 'Titel',
            icon: Icons.info,
            kinder: [],
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.text('Titel'), findsNothing);
    });

    testWidgets('Kinder vorhanden zeigt Titel und Icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DetailKarte(
            titel: 'Stammdaten',
            icon: Icons.home,
            kinder: [Text('Inhalt')],
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Stammdaten'), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.text('Inhalt'), findsOneWidget);
    });

    testWidgets('aktion erscheint rechts im Kopf', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DetailKarte(
            titel: 'Mit Aktion',
            icon: Icons.settings,
            kinder: const [Text('Inhalt')],
            aktion: const Icon(Icons.edit),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });

  group('InfoZeile', () {
    testWidgets('zeigt Label und Wert', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: InfoZeile('A', 'B')),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('leeres Label zeigt nur den Wert', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: InfoZeile('', 'B')),
      );

      expect(find.text('B'), findsOneWidget);
      // Kein SizedBox mit fester Labelbreite, weil kein Label gerendert wird.
      expect(find.byType(Row), findsNothing);
    });
  });
}
