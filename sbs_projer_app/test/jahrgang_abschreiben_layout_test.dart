import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/jahrgang_abschreiben_screen.dart';
import 'package:sbs_projer_app/services/buchhaltung/jahrgang_abschreibung.dart';

/// Der Schritt «Jahrgang abschreiben» auf 360 px mit bis zu 170 % Schrift:
/// Vorschau, Ausschlüsse, Liste, Knopf und Lauf-Karte laufen nicht über.
///
/// WARUM: Lange Beschriftungen («Nie gestellt · 47 — kein Versanddatum in
/// der App …») neben einem Betrag sind genau die Rows, die am 08.09.2026
/// mit grosser Schrift 44 px überliefen. Hier stehen sie in Expanded.
Rechnung _rg(
  String id,
  DateTime datum, {
  String? versandart = 'rechnung_mail',
}) => Rechnung(
  id: id,
  userId: 'u',
  rechnungsnummer: '011_2020_05_02_0042_00006785',
  rechnungstyp: 'kundenrechnung',
  betriebId: 'b',
  rechnungsdatum: datum,
  faelligkeitsdatum: datum,
  betragNetto: 67.85,
  mwstBetrag: 5.20,
  betragBrutto: 73.05,
  versandart: versandart,
);

AbschreibVorschau _vorschau() => AbschreibVorschau.aus(
  auswahlFuer(
    [
      _rg('1', DateTime(2020, 5, 2), versandart: 'rechnung_tresen'),
      _rg('2', DateTime(2020, 6, 2)),
      _rg('3', DateTime(2021, 6, 2)),
      Rechnung(
        id: '4',
        userId: 'u',
        rechnungsnummer: '011_2021_01_01_0001_00006785',
        rechnungstyp: 'kundenrechnung',
        betriebId: 'b',
        rechnungsdatum: DateTime(2021, 1, 1),
        faelligkeitsdatum: DateTime(2021, 1, 1),
        betragNetto: 67.85,
        mwstBetrag: 5.20,
        betragBrutto: 73.05,
        zahlungEingegangenAm: DateTime(2021, 2, 1),
      ),
    ],
    geschaeftsjahr: 2026,
    betriebNamen: const {'b': 'Grand Hotel Surselva Restaurant'},
  ),
);

AbschreibungLauf _lauf() => AbschreibungLauf(
  id: 'l',
  geschaeftsjahr: 2026,
  jahrgaenge: const [2020, 2021],
  buchungsdatum: DateTime(2026, 12, 31),
  mwstJahr: 2026,
  mwstQuartal: 4,
  anzahl: 160,
  netto: 14274.88,
  mwst: 1099.82,
  brutto: 15374.70,
  status: 'gebucht',
  ruecknahmeMoeglich: true,
  createdAt: DateTime(2027, 1, 12),
  notizen: 'Jahresabschluss 2026 Schritt A: Abschreibung verjährter Jahrgänge',
);

Widget _app({AbschreibungLauf? lauf, bool listeOffen = true}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: JahrgangAbschreibenInhalt(
      vorschau: _vorschau(),
      lauf: lauf,
      heute: DateTime(2026, 9, 19),
      laeuft: false,
      listeOffen: listeOffen,
      onListeToggle: () {},
      onBuchen: () {},
      onZuruecknehmen: () {},
    ),
  ),
);

Future<void> _pruefe(
  WidgetTester tester,
  double schrift, {
  AbschreibungLauf? lauf,
}) async {
  tester.view.physicalSize = const Size(360, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(schrift)),
      child: _app(lauf: lauf),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: 'Ueberlauf bei ${(schrift * 100).round()} % Schrift',
  );
}

void main() {
  testWidgets('360 px, normale Schrift', (t) => _pruefe(t, 1.0));
  testWidgets('360 px, 130 % Schrift', (t) => _pruefe(t, 1.3));
  testWidgets('360 px, 170 % Schrift', (t) => _pruefe(t, 1.7));
  testWidgets(
    '360 px, 170 % Schrift, mit gebuchtem Lauf',
    (t) => _pruefe(t, 1.7, lauf: _lauf()),
  );

  testWidgets('zeigt Vorschau, Ausschluss, Jahrgänge und Freigabe-Knopf', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Verjährt per 31.12.2026'), findsOneWidget);
    expect(find.textContaining('Jahrgänge bis 2021'), findsOneWidget);
    expect(find.textContaining('Jahrgang 2020 · 2 Rechnungen'), findsOneWidget);
    expect(find.textContaining('Jahrgang 2021 · 1 Rechnungen'), findsOneWidget);
    expect(find.textContaining('Tresen · 1'), findsOneWidget);
    expect(find.textContaining('Nie gestellt · 1'), findsNWidgets(2));
    expect(
      find.textContaining('MWST 7.7 % → 2200 (Zeile 302)'),
      findsOneWidget,
    );
    expect(find.text('Nicht im Lauf (1)'), findsOneWidget);
    expect(find.textContaining('Zahlung vermerkt'), findsOneWidget);
    expect(find.text('Jahrgänge 2020, 2021 abschreiben'), findsOneWidget);
    // Jahr läuft noch → Hinweis, aber Knopf bleibt
    expect(find.textContaining('Das Jahr 2026 läuft noch'), findsOneWidget);
  });

  testWidgets('mit gebuchtem Lauf: Karte statt Knopf', (tester) async {
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(lauf: _lauf()));
    await tester.pumpAndSettle();

    expect(find.text('Gebucht am 12.01.2027'), findsOneWidget);
    expect(find.textContaining('Ziff. 235 in Q4/2026'), findsOneWidget);
    expect(find.text('Lauf zurücknehmen'), findsOneWidget);
    expect(find.text('Jahrgänge 2020, 2021 abschreiben'), findsNothing);
  });
}
