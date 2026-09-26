import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlungsweg_frei_buchen.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/presentation/providers/buchungs_vorlage_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/buchung_form_screen.dart';

/// Buchungsformular: Wechsel von einer Vorlage mit `kreditor`/`debitor` auf
/// «Frei buchen». Bis 26.09.2026 blieb der Wert stehen — Assertion im
/// Debug-Modus, sonst leeres Feld und `kreditor` wurde mitgespeichert.
void main() {
  group('zahlungswegFuerFreiBuchen', () {
    test('kasse, bank und privat bleiben', () {
      for (final z in const ['kasse', 'bank', 'privat']) {
        expect(zahlungswegFuerFreiBuchen(z), z);
      }
    });

    test('kreditor, debitor und Unbekanntes werden leer', () {
      expect(zahlungswegFuerFreiBuchen('kreditor'), isNull);
      expect(zahlungswegFuerFreiBuchen('debitor'), isNull);
      expect(zahlungswegFuerFreiBuchen('bar'), isNull);
      expect(zahlungswegFuerFreiBuchen(null), isNull);
    });

    test('genau drei Wege im freien Modus', () {
      expect(kZahlungswegeFreiBuchen, ['kasse', 'bank', 'privat']);
    });
  });

  testWidgets('Vorlage mit kreditor → Frei buchen: leer, Pflicht zu wählen', (
    tester,
  ) async {
    // Hoch genug, dass die ListView alle Felder aufbaut (auch Speichern).
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final vorlage = BuchungsVorlage(
      id: 'v1',
      userId: 'u',
      geschaeftsfallId: 'GF-9',
      bezeichnung: 'Lieferantenrechnung',
      art: 'ausgabe',
      hauptkonto: 4200,
      erlaubteZahlungswege: const ['kreditor'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          manuelleBuchungsVorlagenProvider.overrideWith(
            (ref) async => [vorlage],
          ),
        ],
        child: const MaterialApp(home: BuchungFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<BuchungsVorlage>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GF-9 – Lieferantenrechnung').last);
    await tester.pumpAndSettle();
    expect(find.text('Kreditor (offene Rechnung)'), findsOneWidget);

    await tester.tap(find.text('Frei buchen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final frei = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(frei.value, isNull);
    expect(
      frei.items!.map((i) => i.value),
      ['kasse', 'bank', 'privat'],
    );

    await tester.tap(find.text('Buchung speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Zahlungsweg wählen'), findsOneWidget);
  });
}
