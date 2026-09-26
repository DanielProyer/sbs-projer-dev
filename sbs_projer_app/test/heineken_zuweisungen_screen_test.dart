import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/heineken_zuweisung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/kontakt_providers.dart';
import 'package:sbs_projer_app/presentation/screens/heineken/heineken_zuweisungen_screen.dart';

/// Heineken-Zuweisungen: Scheitert das Speichern, zeigt das Dropdown wieder
/// den gespeicherten Kontakt — nicht die nie gespeicherte Wahl.
///
/// Der Fehlschlag kommt hier von selbst: Im Test ist Supabase nicht
/// initialisiert, `KontaktRepository.setHeinekenZuweisung` wirft also.
void main() {
  KontaktLocal kontakt(int id, String vorname, String nachname) =>
      KontaktLocal()
        ..id = id
        ..userId = 'u'
        ..vorname = vorname
        ..nachname = nachname;

  testWidgets('Fehlschlag setzt das Dropdown auf den gespeicherten Kontakt', (
    tester,
  ) async {
    final anna = kontakt(1, 'Anna', 'Alt');
    final bruno = kontakt(2, 'Bruno', 'Neu');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heinekenZuweisungenProvider.overrideWith(
            (ref) async => {'monatsrechnung': anna},
          ),
          kontakteByKategorieProvider.overrideWith(
            (ref, kategorie) async => [anna, bruno],
          ),
        ],
        child: const MaterialApp(home: HeinekenZuweisungenScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final monatsrechnung = find.byType(DropdownButton<String?>).first;
    String? angezeigt() =>
        tester.widget<DropdownButton<String?>>(monatsrechnung).value;
    expect(angezeigt(), anna.routeId);

    await tester.tap(monatsrechnung);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bruno Neu').last);
    await tester.pumpAndSettle();

    expect(angezeigt(), anna.routeId, reason: 'alte Zuweisung muss zurück');
    expect(find.textContaining('Nicht gespeichert'), findsOneWidget);
    // Der Dropdown ist wieder bedienbar (_saving zurückgesetzt).
    expect(
      tester.widget<DropdownButton<String?>>(monatsrechnung).onChanged,
      isNotNull,
    );
  });
}
