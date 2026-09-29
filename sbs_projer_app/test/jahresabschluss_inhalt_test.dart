import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/jahresabschluss_schritte.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/jahresabschluss_screen.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

Pruefbefund befund(String id, PruefStatus s, {String ist = '', String soll = '', String hinweis = ''}) =>
    Pruefbefund(regelId: id, gruppe: 'G', status: s, titel: id, ist: ist, soll: soll, hinweis: hinweis);

/// Die Lage des Abschlusses 2025 am 29.09.2026: Jahrgang 2020 noch offen,
/// Delkredere nachzuführen, Rückstellung gebildet, keine Jahresrechnung.
final schritte = jahresabschlussSchritte(
  jahr: 2025,
  heute: DateTime(2026, 9, 29),
  befunde: [
    befund(kRegelVerjaehrt, PruefStatus.rot, ist: "76 Rechnungen · 7'216.30", soll: '0'),
    befund(
      kRegelDelkredere,
      PruefStatus.gelb,
      ist: "5'629.38",
      soll: "5'267.60",
      hinweis: 'Auf 5 % nachführen.',
    ),
    befund(kRegelRueckstellung, PruefStatus.gruen, ist: "4'000.00"),
    befund('bank_camt', PruefStatus.gelb),
  ],
  laeufe: const [],
  dokumente: const [],
  steuerjahr: const Steuerjahr(jahr: 2025),
  dossier: const Dossier(
    total: 6,
    vorhanden: 1,
    fehlend: ['jahresrechnung', 'zinsausweis', 'steuererklaerung', 'veranlagung:bund', 'veranlagung:kanton'],
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  Future<List<SchrittAktion>> pump(
    WidgetTester tester, {
    List<JahresabschlussSchritt>? liste,
    String? fehler,
    Set<SchrittAktion> laufend = const {},
    double hoehe = 800,
  }) async {
    tester.view.physicalSize = Size(360, hoehe);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final getippt = <SchrittAktion>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: JahresabschlussInhalt(
          jahr: 2025,
          jahre: const [2026, 2025, 2024],
          onJahr: (_) {},
          schritte: fehler == null ? (liste ?? schritte) : null,
          fehler: fehler,
          laufend: laufend,
          onAktion: getippt.add,
        ),
      ),
    );
    return getippt;
  }

  testWidgets('zeigt sechs Schritte mit Titel und Ist', (tester) async {
    await pump(tester, hoehe: 2000);
    for (final s in schritte) {
      expect(find.text(s.titel), findsOneWidget, reason: s.titel);
      expect(find.text(s.ist), findsOneWidget, reason: s.ist);
    }
    expect(find.text('1 von 6 erledigt'), findsOneWidget);
    expect(find.textContaining('Reihenfolge einhalten'), findsOneWidget);
  });

  testWidgets('Status-Punkte tragen die Ampelfarbe', (tester) async {
    await pump(tester, hoehe: 2000);
    Color farbeVon(int nr) {
      final c = tester.widget<Container>(find.byKey(ValueKey('punkt-$nr')));
      return (c.decoration! as BoxDecoration).color!;
    }

    expect(farbeVon(1), AppColors.error); // Prüfung: 1 rot
    expect(farbeVon(2), AppColors.error); // Jahrgang offen
    expect(farbeVon(3), AppColors.warning); // Delkredere
    expect(farbeVon(4), AppColors.success); // Rückstellung
    expect(farbeVon(5), AppColors.warning); // keine Jahresrechnung
    expect(farbeVon(6), AppColors.warning); // nicht eingereicht
  });

  testWidgets('Knöpfe melden ihre Aktion', (tester) async {
    final getippt = await pump(tester, hoehe: 2000);
    await tester.tap(find.text('Erzeugen und ins Dossier legen'));
    await tester.tap(find.text('Vorschau'));
    await tester.tap(find.text('Zur Prüfung').first);
    await tester.tap(find.text('Öffnen').last);
    expect(getippt, [
      SchrittAktion.erzeugen,
      SchrittAktion.vorschau,
      SchrittAktion.pruefung,
      SchrittAktion.steuerjahr,
    ]);
  });

  testWidgets('laufende Aktion sperrt ihren Knopf', (tester) async {
    final getippt = await pump(tester, hoehe: 2000, laufend: {SchrittAktion.erzeugen});
    final knopf = tester.widget<TapKnopf>(
      find.widgetWithText(TapKnopf, 'Erzeugen und ins Dossier legen'),
    );
    expect(knopf.laeuft, isTrue);
    await tester.tap(find.text('Erzeugen und ins Dossier legen'));
    expect(getippt, isEmpty);
  });

  testWidgets('360 px: kein Überlauf, keine gekürzten Texte', (tester) async {
    await pump(tester, hoehe: 2000);
    expect(tester.takeException(), isNull);
    for (final t in [for (final s in schritte) ...[s.titel, s.ist]]) {
      final absatz = tester.renderObject<RenderParagraph>(find.text(t));
      expect(absatz.didExceedMaxLines, isFalse, reason: t);
    }
  });

  testWidgets('360×800 scrollt ohne Fehler bis zum letzten Schritt', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Steuererklärung'), 200);
    expect(find.text('Steuererklärung'), findsOneWidget);
  });

  testWidgets('Fehler statt Liste', (tester) async {
    await pump(tester, fehler: 'Jahresabschluss nicht ladbar: offline');
    expect(find.text('Jahresabschluss nicht ladbar: offline'), findsOneWidget);
    expect(find.text('Abschlussprüfung'), findsNothing);
  });

  group('Erzeugen-Dialog', () {
    const k = JahresrechnungKennzahlen(
      jahr: 2025,
      gewinn: 15235.70,
      gewinnvortrag: 35060.71,
      stammkapital: 20000,
      debitoren: 105351.96,
      delkredere: 5267.60,
      rueckstellung: 2800,
      bank: 12202.73,
      kasse: 6670.24,
      aufrechnungenAuto: 120,
    );

    Future<List<JahresrechnungEingabe?>> dialog(WidgetTester tester, {int bisherige = 0}) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ergebnis = <JahresrechnungEingabe?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: GestureDetector(
                  onTap: () async => ergebnis.add(
                    await showDialog<JahresrechnungEingabe>(
                      context: context,
                      builder: (_) => JahresrechnungDialog(kennzahlen: k, bisherige: bisherige),
                    ),
                  ),
                  child: const Text('auf'),
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

    testWidgets('zeigt 6280-Hinweis und Kennzahlen, rechnet mit', (tester) async {
      final ergebnis = await dialog(tester);
      expect(tester.takeException(), isNull);
      final hilfe = find.textContaining('Bussen 6280/6281 (120.00)');
      expect(hilfe, findsOneWidget);
      // Im Browser endeten zu lange Labels und Hilfetexte mit «…»
      // (Sichtprüfung 29.09.2026).
      for (final f in [
        find.text('Aufrechnungen (CHF)'),
        find.text('Ereignisse (optional)'),
        hilfe,
        find.textContaining('Nach dem Bilanzstichtag'),
      ]) {
        final absatz = tester.renderObject<RenderParagraph>(f);
        expect(absatz.didExceedMaxLines, isFalse, reason: '$f');
      }
      expect(find.text("15'355.70"), findsOneWidget); // steuerbar ohne Eingabe
      await tester.enterText(find.byType(TextField).first, '200');
      await tester.pump();
      expect(find.text("15'555.70"), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Keine.');
      await tester.tap(find.text('Erzeugen'));
      await tester.pumpAndSettle();
      expect(ergebnis.single?.manuell, 200);
      expect(ergebnis.single?.ereignisse, 'Keine.');
    });

    testWidgets('unlesbarer Betrag sperrt Erzeugen', (tester) async {
      final ergebnis = await dialog(tester);
      await tester.enterText(find.byType(TextField).first, '12..5');
      await tester.pump();
      expect(find.text('Kein gültiger Betrag'), findsOneWidget);
      await tester.tap(find.text('Erzeugen'));
      await tester.pumpAndSettle();
      expect(ergebnis, isEmpty); // Dialog noch offen
    });

    testWidgets('liegt schon eine vor: Fassung 2 zusätzlich', (tester) async {
      final ergebnis = await dialog(tester, bisherige: 1);
      expect(find.text('Fassung 2 ablegen?'), findsOneWidget);
      expect(find.textContaining('bisherige bleibt liegen'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(ergebnis, [null]);
    });
  });
}
