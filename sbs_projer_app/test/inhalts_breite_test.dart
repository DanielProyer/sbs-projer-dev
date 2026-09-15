import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/inhalts_breite.dart';

/// A5: Am PC lief der Inhalt über die ganze Fensterbreite — die
/// Startseiten-Kacheln wurden zu leeren Kästen von 950 × 450 Pixeln
/// (App-Analyse 08.09.2026, Befund 4). `InhaltsBreite` hängt zentral im
/// `MaterialApp.builder` und begrenzt die Spalte.
void main() {
  const schluessel = Key('inhalt');

  Future<Size> breiteBei(WidgetTester tester, double fensterBreite) async {
    tester.view.physicalSize = Size(fensterBreite, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: InhaltsBreite(
          child: Scaffold(body: SizedBox.expand(key: schluessel)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byKey(schluessel));
  }

  testWidgets('am PC auf 720 px begrenzt', (tester) async {
    final groesse = await breiteBei(tester, 1400);
    expect(groesse.width, InhaltsBreite.maxBreite);
  });

  testWidgets('am Handy unverändert — volle Breite', (tester) async {
    final groesse = await breiteBei(tester, 360);
    expect(
      groesse.width,
      360,
      reason:
          'Auf dem Pixel 9 darf die Begrenzung nichts wegnehmen — dort ist '
          'jeder Pixel Breite gebraucht.',
    );
  });

  testWidgets('genau an der Grenze bleibt es bei 720', (tester) async {
    final groesse = await breiteBei(tester, InhaltsBreite.maxBreite);
    expect(groesse.width, InhaltsBreite.maxBreite);
  });
}
