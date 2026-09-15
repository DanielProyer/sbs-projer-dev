import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/arbeit_beenden_knopf.dart';

// A8 (15.09.2026): Die Detailseiten von Stoerung und Montage nutzen fuer den
// neuen "Erledigt"-Knopf denselben ArbeitBeendenKnopf, mit dem die Formulare
// "Arbeit beenden" anzeigen (nur mit anderer Beschriftung). Dieser Test
// prueft das echte, gemeinsam genutzte Widget -- nicht einen Nachbau --
// damit eine kuenftige Aenderung an ArbeitBeendenKnopf hier auffaellt.
//
// Bewusst GestureDetector statt FilledButton/OutlinedButton (CanvasKit-Regel,
// CLAUDE.md): der Test tippt deshalb ueber `tester.tap(find.byType(...))`,
// nicht ueber eine button-spezifische Finder-API.
void main() {
  Widget wrapped(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('Default-Beschriftung ist "Beenden" (Formulare)',
      (tester) async {
    await tester.pumpWidget(wrapped(
      ArbeitBeendenKnopf(onTap: () {}, laeuft: false),
    ));

    expect(find.text('Beenden'), findsOneWidget);
    expect(find.text('Erledigt'), findsNothing);
  });

  testWidgets('label ueberschreibt die Beschriftung fuer die Detailseiten',
      (tester) async {
    await tester.pumpWidget(wrapped(
      ArbeitBeendenKnopf(onTap: () {}, laeuft: false, label: 'Erledigt'),
    ));

    expect(find.text('Erledigt'), findsOneWidget);
    expect(find.text('Beenden'), findsNothing);
  });

  testWidgets('Tippen loest onTap aus', (tester) async {
    var getippt = false;
    await tester.pumpWidget(wrapped(
      ArbeitBeendenKnopf(
        onTap: () => getippt = true,
        laeuft: false,
        label: 'Erledigt',
      ),
    ));

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    expect(getippt, isTrue);
  });

  testWidgets('laeuft: true blockiert den Knopf waehrend des Speicherns',
      (tester) async {
    var getippt = false;
    await tester.pumpWidget(wrapped(
      ArbeitBeendenKnopf(
        onTap: () => getippt = true,
        laeuft: true,
        label: 'Erledigt',
      ),
    ));

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    expect(getippt, isFalse,
        reason: 'Ein Speichervorgang laeuft bereits -- ein zweiter Tipp '
            'darf ihn nicht ueberlagern (Doppel-Buchung).');
  });
}
