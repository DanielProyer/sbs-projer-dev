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
///
/// Der Zahlungsweg bleibt dort aber FREIWILLIG (Spalte nullable, Migration
/// 089), und `intern` ist wählbar — die Pflichtwahl aus dem ersten Fix
/// machte Umbuchungen ohne Geldfluss unmöglich (Review 26.09.2026).
void main() {
  group('zahlungswegFuerFreiBuchen', () {
    test('kasse, bank, privat und intern bleiben', () {
      for (final z in const ['kasse', 'bank', 'privat', 'intern']) {
        expect(zahlungswegFuerFreiBuchen(z), z);
      }
    });

    test('kreditor, debitor und Unbekanntes werden leer', () {
      expect(zahlungswegFuerFreiBuchen('kreditor'), isNull);
      expect(zahlungswegFuerFreiBuchen('debitor'), isNull);
      expect(zahlungswegFuerFreiBuchen('bar'), isNull);
      expect(zahlungswegFuerFreiBuchen(null), isNull);
    });

    test('genau vier Wege im freien Modus', () {
      expect(kZahlungswegeFreiBuchen, ['kasse', 'bank', 'privat', 'intern']);
    });
  });

  group('zahlungswegFreiErlaubt', () {
    test('kein Zahlungsweg ist erlaubt', () {
      expect(zahlungswegFreiErlaubt(null), isTrue);
    });

    test('die vier Wege sind erlaubt', () {
      for (final z in kZahlungswegeFreiBuchen) {
        expect(zahlungswegFreiErlaubt(z), isTrue, reason: z);
      }
    });

    test('Reste einer Vorlage sind gesperrt', () {
      expect(zahlungswegFreiErlaubt('kreditor'), isFalse);
      expect(zahlungswegFreiErlaubt('debitor'), isFalse);
      expect(zahlungswegFreiErlaubt('rechnung'), isFalse);
    });
  });

  testWidgets('Vorlage mit kreditor → Frei buchen: leer, aber nicht Pflicht', (
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
      ['kasse', 'bank', 'privat', 'intern'],
    );

    // Speichern scheitert hier an den leeren Pflichtfeldern (Betrag,
    // Konten) — der Zahlungsweg meldet sich dabei nicht.
    await tester.tap(find.text('Buchung speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Pflicht'), findsWidgets, reason: 'Prüfung lief');
    expect(find.text('Zahlungsweg wählen'), findsNothing);
    expect(find.textContaining('Zahlungsweg gibt es'), findsNothing);
  });

  testWidgets('Frei buchen bietet «Intern» an und übernimmt es', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          manuelleBuchungsVorlagenProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: BuchungFormScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frei buchen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intern (ohne Geldfluss)').last);
    await tester.pumpAndSettle();

    final frei = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(frei.value, 'intern');
  });
}
