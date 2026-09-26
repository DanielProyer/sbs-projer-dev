import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hält ein SDK-Verhalten fest, auf das rund 57 Dropdowns der App bauen:
/// `DropdownButtonFormField` übernimmt ein GEÄNDERTES `initialValue` auch
/// ohne neuen Key (`didUpdateWidget` → `setValue`, Flutter 3.41).
///
/// WARUM: Seit dem Umbau `value` → `initialValue` (26.09.2026) setzen viele
/// Formulare den angezeigten Wert von aussen, indem sie nur `initialValue`
/// ändern — ohne `key:`. Der Name klingt aber nach «nur der Anfangswert».
/// Sollte eine künftige Flutter-Version das so umsetzen, zeigten all diese
/// Felder still den alten Wert. Schlägt dieser Test nach einem
/// Flutter-Update fehl: Jedes `DropdownButtonFormField` ohne Key, dessen
/// `initialValue` sich nach dem ersten Aufbau ändert, braucht dann einen
/// Key aus dem Wert (Vorbild: `buchung_form_screen.dart`, Zahlungsweg).
void main() {
  Widget feld(String wert) => MaterialApp(
    home: Scaffold(
      body: DropdownButtonFormField<String>(
        initialValue: wert,
        items: const [
          DropdownMenuItem(value: 'a', child: Text('Alpha')),
          DropdownMenuItem(value: 'b', child: Text('Bravo')),
        ],
        onChanged: (_) {},
      ),
    ),
  );

  String angezeigt(WidgetTester tester) => tester
      .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .value!;

  testWidgets('geändertes initialValue wird ohne Key übernommen', (
    tester,
  ) async {
    await tester.pumpWidget(feld('a'));
    expect(angezeigt(tester), 'a');
    expect(find.text('Alpha').hitTestable(), findsOneWidget);

    await tester.pumpWidget(feld('b'));
    expect(angezeigt(tester), 'b');
    expect(find.text('Bravo').hitTestable(), findsOneWidget);
    expect(find.text('Alpha').hitTestable(), findsNothing);
  });

  testWidgets('geändertes initialValue gilt auch nach einer Nutzerwahl', (
    tester,
  ) async {
    await tester.pumpWidget(feld('a'));
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bravo').last);
    await tester.pumpAndSettle();
    expect(angezeigt(tester), 'b');

    await tester.pumpWidget(feld('b'));
    expect(angezeigt(tester), 'b');

    await tester.pumpWidget(feld('a'));
    expect(angezeigt(tester), 'a');
  });

  testWidgets('UNVERÄNDERTES initialValue setzt eine Nutzerwahl nicht zurück', (
    tester,
  ) async {
    // Die Grenze des Verhaltens: Wer nach einer Nutzerwahl «den alten Wert
    // wieder setzt», ändert initialValue nicht — das Feld behält die Wahl.
    // Zurücksetzen geht dann nur über einen neuen Key (Vorbild:
    // heineken_zuweisungen_screen.dart nach fehlgeschlagenem Speichern).
    await tester.pumpWidget(feld('a'));
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bravo').last);
    await tester.pumpAndSettle();

    await tester.pumpWidget(feld('a'));
    expect(angezeigt(tester), 'b');
  });
}
