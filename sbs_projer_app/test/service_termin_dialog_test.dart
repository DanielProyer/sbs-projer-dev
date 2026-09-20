import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/service_termin_dialog.dart';

/// Termin für den nächsten Service von Hand setzen.
///
/// WARUM: 33 Anlagen laufen «auf Abruf» — für die rechnet die App bewusst
/// kein Fälligkeitsdatum aus, sie tauchen nie von selbst im Tourenplan auf.
/// Bis zum 20.09.2026 liess sich ein vereinbarter Termin nirgends festhalten
/// (Fall Alpina Resort Tschiertschen). Der Dialog füllt die Lücke; gebucht
/// wird als `typ: 'sonstiges'`, womit der bestehende Kalender-Push greift.
Future<ServiceTerminEingabe?> _oeffne(
  WidgetTester tester, {
  double schrift = 1.0,
}) async {
  ServiceTerminEingabe? ergebnis;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(schrift)),
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  ergebnis = await zeigeServiceTerminDialog(
                    c,
                    betriebName: 'Alpina Resort, Tschiertschen',
                    vorschlag: DateTime(2026, 10, 2),
                  );
                },
                child: const Text('auf'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('auf'));
  await tester.pumpAndSettle();
  return ergebnis;
}

void main() {
  testWidgets('zeigt Betrieb, Vorschlagsdatum und den Titel «Service»', (
    tester,
  ) async {
    await _oeffne(tester);
    expect(find.text('Nächsten Service planen'), findsOneWidget);
    expect(find.text('Alpina Resort, Tschiertschen'), findsOneWidget);
    expect(find.text('02.10.2026'), findsOneWidget);
    expect(find.text('Service'), findsOneWidget);
    expect(find.textContaining('Google Kalender'), findsWidgets);
  });

  testWidgets('Termin setzen liefert Datum und Titel, leere Notiz wird null', (
    tester,
  ) async {
    ServiceTerminEingabe? ergebnis;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  ergebnis = await zeigeServiceTerminDialog(
                    c,
                    betriebName: 'Alpina Resort',
                    vorschlag: DateTime(2026, 10, 2),
                  );
                },
                child: const Text('auf'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('auf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Termin setzen'));
    await tester.pumpAndSettle();

    expect(ergebnis, isNotNull);
    expect(ergebnis!.datum, DateTime(2026, 10, 2));
    expect(ergebnis!.titel, 'Service');
    expect(
      ergebnis!.notizen,
      isNull,
      reason: 'leere Notiz wird nicht gespeichert',
    );
  });

  testWidgets('eigener Titel und Notiz kommen durch', (tester) async {
    ServiceTerminEingabe? ergebnis;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  ergebnis = await zeigeServiceTerminDialog(
                    c,
                    betriebName: 'Alpina Resort',
                    vorschlag: DateTime(2026, 10, 2),
                  );
                },
                child: const Text('auf'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('auf'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Service'),
      'Reinigung',
    );
    await tester.enterText(find.byType(TextField).last, 'Wirt ruft vorher an');
    await tester.tap(find.text('Termin setzen'));
    await tester.pumpAndSettle();

    expect(ergebnis!.titel, 'Reinigung');
    expect(ergebnis!.notizen, 'Wirt ruft vorher an');
  });

  testWidgets('Abbrechen gibt nichts zurück', (tester) async {
    ServiceTerminEingabe? ergebnis;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  ergebnis = await zeigeServiceTerminDialog(
                    c,
                    betriebName: 'Alpina Resort',
                  );
                },
                child: const Text('auf'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('auf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(ergebnis, isNull);
  });

  for (final schrift in [1.0, 1.3, 1.7]) {
    testWidgets('360 px, ${(schrift * 100).round()} % Schrift', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await _oeffne(tester, schrift: schrift);
      expect(tester.takeException(), isNull);
      expect(find.text('Termin setzen'), findsOneWidget);
    });
  }
}
