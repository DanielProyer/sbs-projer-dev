import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/jahrgang_abschreiben_screen.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
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

/// Lauf nach Migration 215: brutto per 31.12., Rückholung als Sammelbuchung
/// am Entscheidtag (hier 12.01.2027 → Q1/2027).
AbschreibungLauf _lauf() => AbschreibungLauf(
  id: 'l',
  geschaeftsjahr: 2026,
  jahrgaenge: const [2020, 2021],
  buchungsdatum: DateTime(2026, 12, 31),
  mwstJahr: 2027,
  mwstQuartal: 1,
  anzahl: 160,
  netto: 14274.88,
  mwst: 1099.82,
  brutto: 15374.70,
  status: 'gebucht',
  ruecknahmeMoeglich: true,
  createdAt: DateTime(2027, 1, 12),
  notizen: 'Jahresabschluss 2026 Schritt A: Abschreibung verjährter Jahrgänge',
  buchungMwstIds: const ['m1'],
);

/// Der 2019er-Lauf des Abschlusses 2025: per SQL, nicht zurücknehmbar.
AbschreibungLauf _sqlLauf() => AbschreibungLauf(
  id: 's',
  geschaeftsjahr: 2026,
  jahrgaenge: const [2019],
  buchungsdatum: DateTime(2026, 12, 31),
  mwstJahr: 2026,
  mwstQuartal: 3,
  anzahl: 29,
  netto: 2076.00,
  mwst: 159.90,
  brutto: 2235.90,
  status: 'gebucht',
  ruecknahmeMoeglich: false,
  createdAt: DateTime(2026, 9, 2),
);

AbschreibVorschau _leer() => AbschreibVorschau.aus(
  auswahlFuer(const [], geschaeftsjahr: 2026, betriebNamen: const {}),
);

Widget _app({
  List<AbschreibungLauf> laeufe = const [],
  AbschreibVorschau? vorschau,
  bool listeOffen = true,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: JahrgangAbschreibenInhalt(
      vorschau: vorschau ?? _vorschau(),
      laeufe: laeufe,
      heute: DateTime(2026, 9, 19),
      laeuft: false,
      listeOffen: listeOffen,
      onListeToggle: () {},
      onBuchen: () {},
      onZuruecknehmen: (_) {},
    ),
  ),
);

Future<void> _pruefe(
  WidgetTester tester,
  double schrift, {
  List<AbschreibungLauf> laeufe = const [],
}) async {
  tester.view.physicalSize = const Size(360, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(schrift)),
      child: _app(laeufe: laeufe),
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
    '360 px, 170 % Schrift, mit zwei gebuchten Läufen',
    (t) => _pruefe(t, 1.7, laeufe: [_lauf(), _sqlLauf()]),
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
    // Seit Migration 215: brutto per 31.12., Rückholung am Entscheidtag.
    expect(
      find.textContaining('3805 an 1100 brutto, per 31.12.2026'),
      findsOneWidget,
    );
    expect(
      find.textContaining('2200 an 3805 MWST 7.7 % (Zeile 302) am Entscheidtag'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Ziff. 235 im laufenden Quartal (Q3/2026)'),
      findsWidgets,
    );
    expect(find.textContaining('Q4/2026'), findsNothing);
    expect(find.text('Nicht im Lauf (1)'), findsOneWidget);
    expect(find.textContaining('Zahlung vermerkt'), findsOneWidget);
    expect(find.text('Jahrgänge 2020, 2021 abschreiben'), findsOneWidget);
    // Jahr läuft noch → Hinweis, aber Knopf bleibt
    expect(find.textContaining('Das Jahr 2026 läuft noch'), findsOneWidget);
  });

  testWidgets('gebuchter Lauf, nichts mehr offen: Karte, kein Knopf', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(laeufe: [_lauf()], vorschau: _leer()));
    await tester.pumpAndSettle();

    expect(find.text('Gebucht am 12.01.2027'), findsOneWidget);
    expect(
      find.textContaining('Debitorenverlust brutto (3805), per 31.12.2026'),
      findsOneWidget,
    );
    expect(
      find.textContaining('(2200 an 3805) → Ziff. 235 in Q1/2027'),
      findsOneWidget,
    );
    expect(find.text('Lauf zurücknehmen'), findsOneWidget);
    expect(find.textContaining('Alles gebucht'), findsOneWidget);
    // nur «Lauf zurücknehmen», kein Abschreiben-Knopf
    expect(find.byType(TapKnopf), findsOneWidget);
  });

  testWidgets('zweiter Lauf im selben Jahr (214): Karten UND Knopf', (
    tester,
  ) async {
    // Abschluss 2025: 2019 per SQL gebucht, 2020 kommt per App dazu. Bis
    // v0.153 verschwand der Knopf, sobald irgendein Lauf gebucht war.
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(laeufe: [_sqlLauf()]));
    await tester.pumpAndSettle();

    expect(find.text('Gebucht am 02.09.2026'), findsOneWidget);
    expect(
      find.text('Per SQL gebucht — Rücknahme nur von Hand.'),
      findsOneWidget,
    );
    expect(find.text('Jahrgänge 2020, 2021 abschreiben'), findsOneWidget);
  });

  testWidgets('Rücknahme meldet den Lauf, zu dem die Karte gehört', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    AbschreibungLauf? gemeldet;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: JahrgangAbschreibenInhalt(
            vorschau: _leer(),
            laeufe: [_lauf(), _sqlLauf()],
            heute: DateTime(2027, 1, 12),
            laeuft: false,
            listeOffen: false,
            onListeToggle: () {},
            onBuchen: () {},
            onZuruecknehmen: (l) => gemeldet = l,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lauf zurücknehmen'));
    expect(gemeldet?.id, 'l');
  });
}
