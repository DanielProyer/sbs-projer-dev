import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/steuerrueckstellung.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/rueckstellung_dialog.dart';

/// Dialog «Steuerrückstellung buchen» (Jahresabschluss Schritt D) — am
/// Handy (360 px). Lage wie 2025 nach Abschreibung Jahrgang 2020: Gewinn vor
/// Rückstellung 18'035.70, Verkehrsbusse 120, gebucht 4'000.

const SteuerrueckstellungLage _lage2025 = (
  gewinnVorRueckstellung: 18035.70,
  aufrechnungenAuto: 120.0,
  gebucht: 4000.0,
);

class _Ergebnis {
  RueckstellungEingabe? wert;
  bool fertig = false;
}

Future<_Ergebnis> _oeffne(
  WidgetTester tester, {
  SteuerrueckstellungLage lage = _lage2025,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final ergebnis = _Ergebnis();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => GestureDetector(
            onTap: () async {
              ergebnis.wert = await zeigeRueckstellungDialog(
                context,
                jahr: 2025,
                lage: lage,
              );
              ergebnis.fertig = true;
            },
            child: const Text('öffnen'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('öffnen'));
  await tester.pumpAndSettle();
  return ergebnis;
}

String _wert(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

String _feld(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('zeigt Vorschlag, Bisher und Differenz — ohne Überlauf', (
    tester,
  ) async {
    await _oeffne(tester);
    expect(find.text('Steuerrückstellung 2025'), findsOneWidget);
    expect(find.text("18'035.70"), findsOneWidget);
    // 0.182 · (18'035.70 + 120) / 1.182 = 2'795.5 → 2'800
    expect(_wert(tester, 'rueckstellung_vorschlag'), "2'800.00");
    expect(_feld(tester, 'rueckstellung_ziel'), '2800.00');
    expect(_feld(tester, 'rueckstellung_satz'), '18.2');
    expect(find.text("4'000.00"), findsOneWidget);
    expect(_wert(tester, 'rueckstellung_differenz'), "1'200.00 · 2208 an 8900");
    expect(tester.takeException(), isNull);
  });

  testWidgets('Satz ändern zieht den Betrag nach; von Hand geändert bleibt '
      'er stehen', (tester) async {
    final e = await _oeffne(tester);
    await tester.enterText(find.byKey(const Key('rueckstellung_satz')), '20');
    await tester.pump();
    // 0.2 · 18'155.70 / 1.2 = 3'025.95 → 3'000
    expect(_wert(tester, 'rueckstellung_vorschlag'), "3'000.00");
    expect(_feld(tester, 'rueckstellung_ziel'), '3000.00');

    await tester.enterText(find.byKey(const Key('rueckstellung_ziel')), '3500');
    await tester.pump();
    expect(_wert(tester, 'rueckstellung_differenz'), '500.00 · 2208 an 8900');
    // Weitere Aufrechnungen ändern den Vorschlag, nicht mehr den Betrag.
    await tester.enterText(
      find.byKey(const Key('rueckstellung_weitere')),
      '200',
    );
    await tester.pump();
    expect(_feld(tester, 'rueckstellung_ziel'), '3500');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('rueckstellung_buchen')));
    await tester.pumpAndSettle();
    expect(e.fertig, isTrue);
    expect(e.wert!.ziel, 3500);
    expect(e.wert!.begruendung, contains('Satz 20.0 %'));
    expect(e.wert!.begruendung, contains("weitere 200.00"));
    expect(e.wert!.begruendung, contains("neu 3'500.00"));
  });

  testWidgets('«Vorschlag übernehmen» setzt den Betrag zurück', (tester) async {
    await _oeffne(tester);
    await tester.enterText(find.byKey(const Key('rueckstellung_ziel')), '1000');
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('rueckstellung_vorschlag_uebernehmen')),
    );
    await tester.pump();
    expect(_feld(tester, 'rueckstellung_ziel'), '2800.00');
  });

  testWidgets('ohne Differenz lässt sich nicht buchen', (tester) async {
    final e = await _oeffne(
      tester,
      lage: (
        gewinnVorRueckstellung: 18035.70,
        aufrechnungenAuto: 120.0,
        gebucht: 2800.0,
      ),
    );
    expect(_wert(tester, 'rueckstellung_differenz'), 'nichts (unverändert)');
    await tester.tap(find.byKey(const Key('rueckstellung_buchen')));
    await tester.pumpAndSettle();
    expect(e.fertig, isFalse);
    expect(find.text('Steuerrückstellung 2025'), findsOneWidget);
  });

  testWidgets('Abbrechen gibt null zurück', (tester) async {
    final e = await _oeffne(tester);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(e.fertig, isTrue);
    expect(e.wert, isNull);
  });
}
