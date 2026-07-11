import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_jahr_monat_leiste.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('AppJahrMonatLeiste: Jahr/Monat wählbar + trailing sichtbar',
      (t) async {
    int jahr = 2026;
    int monat = 0;
    await t.pumpWidget(_wrap(StatefulBuilder(
      builder: (c, setState) => AppJahrMonatLeiste(
        jahre: const [2026, 2025, 2024],
        selectedJahr: jahr,
        onJahrChanged: (y) => setState(() => jahr = y),
        selectedMonat: monat,
        onMonatChanged: (m) => setState(() => monat = m),
        trailing: const Text('12 Einträge'),
      ),
    )));
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Alle Monate'), findsOneWidget);
    expect(find.text('12 Einträge'), findsOneWidget);

    // Jahr wechseln
    await t.tap(find.text('2026'));
    await t.pumpAndSettle();
    await t.tap(find.text('2024').last);
    await t.pumpAndSettle();
    expect(jahr, 2024);

    // Monat wählen
    await t.tap(find.text('Alle Monate'));
    await t.pumpAndSettle();
    await t.tap(find.text('März').last);
    await t.pumpAndSettle();
    expect(monat, 3);
  });

  testWidgets('AppJahrMonatLeiste: ungültiges Jahr fällt auf jahre.first zurück',
      (t) async {
    await t.pumpWidget(_wrap(AppJahrMonatLeiste(
      jahre: const [2025, 2024],
      selectedJahr: 1999, // nicht in jahre
      onJahrChanged: (_) {},
      selectedMonat: 0,
      onMonatChanged: (_) {},
    )));
    // Kein Crash (Assertion), zeigt das erste Jahr.
    expect(find.text('2025'), findsOneWidget);
  });
}
