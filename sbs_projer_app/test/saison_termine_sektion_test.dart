import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/touren/saison_termine_sektion.dart';

TourEintrag _eintrag(String name) => TourEintrag(
  typ: TourEintragTyp.reinigung,
  id: name,
  betriebName: name,
  beschreibung: 'Eröffnungsreinigung',
  istAutoTermin: true,
);

Future<void> _zeige(WidgetTester tester, List<TourEintrag> eintraege) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SaisonTermineSektion(
          eintraege: eintraege,
          onUebernehmen: (_) {},
          onAlleUebernehmen: () {},
          onTap: (_) {},
        ),
      ),
    ),
  );
}

/// Die Sektion stand aufgeklappt über dem Tagesplan und schob ihn auf dem
/// Handy aus dem Bild (Daniel, 06.09.2026: «brauchen zu viel Platz»).
/// Sie startet deshalb zugeklappt — die Zahl im Titel sagt weiterhin, dass
/// etwas da ist.
void main() {
  testWidgets('startet zugeklappt: nur Titel mit Anzahl, keine Einträge', (
    tester,
  ) async {
    await _zeige(tester, [_eintrag('Alpina'), _eintrag('Sternen')]);

    expect(find.text('Saison-Termine (2)'), findsOneWidget);
    expect(find.text('Alpina'), findsNothing);
    expect(find.text('Sternen'), findsNothing);
    // «Alle übernehmen» erst zeigen, wenn man sieht, was übernommen wird.
    expect(find.text('Alle übernehmen'), findsNothing);
  });

  testWidgets('Tippen auf den Kopf klappt auf und wieder zu', (tester) async {
    await _zeige(tester, [_eintrag('Alpina')]);

    await tester.tap(find.text('Saison-Termine (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Alpina'), findsOneWidget);
    expect(find.text('Alle übernehmen'), findsOneWidget);

    await tester.tap(find.text('Saison-Termine (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Alpina'), findsNothing);
  });

  testWidgets('leere Liste rendert nichts', (tester) async {
    await _zeige(tester, []);
    expect(find.textContaining('Saison-Termine'), findsNothing);
  });
}
