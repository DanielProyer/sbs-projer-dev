import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/material_kategorie.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/materialien_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/widgets/material_karte.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `/materialien`: Kategorie-Chips in einer Zeile, Liste ↔ Karten mit
/// Swipe, gemerkte Ansicht (27.09.2026) — am Handy (360 px).
///
/// Alle Test-Artikel ohne `materialId`: so fragt keine Karte ein Foto bei
/// Supabase an.

// Einfüge-Reihenfolge absichtlich anders als die Sortierung.
final _kategorien = [
  MaterialKategorie(id: 'k-reiniger', userId: 'u', name: 'Reiniger', sortierung: 30),
  MaterialKategorie(id: 'k-hahn', userId: 'u', name: 'Zapfhahn', sortierung: 10),
  MaterialKategorie(id: 'k-leer', userId: 'u', name: 'Unbenutzt', sortierung: 5),
  MaterialKategorie(id: 'k-dicht', userId: 'u', name: 'Dichtungen', sortierung: 20),
];

// Sortiert (DBO zuerst, dann Name): Kompensator, Zapfhahn Chrom,
// Alkalireiniger, Bürste, Dichtung gross.
final _lager = [
  Lager(id: 'a1', userId: 'u', name: 'Zapfhahn Chrom', kategorieId: 'k-hahn', dboNr: '200'),
  Lager(id: 'a2', userId: 'u', name: 'Kompensator', kategorieId: 'k-hahn', dboNr: '100'),
  Lager(id: 'a3', userId: 'u', name: 'Alkalireiniger', kategorieId: 'k-reiniger',
      bestandAktuell: 1, bestandNiedrig: true),
  Lager(id: 'a4', userId: 'u', name: 'Dichtung gross', kategorieId: 'k-dicht'),
  Lager(id: 'a5', userId: 'u', name: 'Bürste'),
];

Future<void> _zeige(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  List<Lager>? lager,
  Size groesse = const Size(360, 800),
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = groesse;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        materialienStreamProvider
            .overrideWith((ref) => Stream.value(lager ?? _lager)),
        kategorienProvider.overrideWith((ref) async => _kategorien),
      ],
      child: const MaterialApp(home: MaterialienListScreen(istGast: false)),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _chipTexte(WidgetTester tester) => tester
    .widgetList<FilterChip>(find.byType(FilterChip))
    .map((c) => ((c.label as Text).data)!)
    .toList();

bool _chipAktiv(WidgetTester tester, String text) => tester
    .widget<FilterChip>(find.ancestor(
      of: find.text(text),
      matching: find.byType(FilterChip),
    ))
    .selected;

Future<void> _tippe(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _wische(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-400, 0));
  await tester.pumpAndSettle();
}

/// Name der sichtbaren Karte (der PageView baut nur die sichtbare Seite).
String _kartenName(WidgetTester tester) =>
    tester.widget<MaterialKarte>(find.byType(MaterialKarte)).lager.name;

Future<String?> _pref(String schluessel) async =>
    (await SharedPreferences.getInstance()).getString(schluessel);

void main() {
  testWidgets('Chips: nur belegte Kategorien in Sortierungs-Reihenfolge',
      (tester) async {
    await _zeige(tester);
    expect(_chipTexte(tester), [
      'Niedrig · 1',
      'Alle',
      'Zapfhahn · 2',
      'Dichtungen · 1',
      'Reiniger · 1',
      'Ohne Kategorie · 1',
    ]);
    expect(_chipAktiv(tester, 'Alle'), isTrue);
    expect(find.text('5 Materialien'), findsOneWidget);
    // Das alte Dropdown ist weg.
    expect(find.text('Alle Kategorien'), findsNothing);
  });

  testWidgets('Chip filtert, nochmals Tipp zeigt wieder alle', (tester) async {
    await _zeige(tester);
    await _tippe(tester, find.text('Zapfhahn · 2'));
    expect(find.text('2 Materialien'), findsOneWidget);
    expect(find.text('Kompensator'), findsOneWidget);
    expect(find.text('Zapfhahn Chrom'), findsOneWidget);
    expect(find.text('Alkalireiniger'), findsNothing);
    expect(_chipAktiv(tester, 'Zapfhahn · 2'), isTrue);

    await _tippe(tester, find.text('Zapfhahn · 2'));
    expect(find.text('5 Materialien'), findsOneWidget);
    expect(_chipAktiv(tester, 'Alle'), isTrue);
  });

  testWidgets('Niedrig-Chip zeigt nur Artikel unter Mindestbestand',
      (tester) async {
    await _zeige(tester);
    await _tippe(tester, find.text('Niedrig · 1'));
    expect(find.text('1 Materialien'), findsOneWidget);
    expect(find.text('Alkalireiniger'), findsOneWidget);
  });

  testWidgets('keine Treffer → «Keine Ergebnisse»', (tester) async {
    await _zeige(tester);
    await tester.enterText(find.byType(TextField), 'gibtsnicht');
    await tester.pumpAndSettle();
    expect(find.text('Keine Ergebnisse'), findsOneWidget);
    expect(find.text('0 Materialien'), findsOneWidget);
  });

  testWidgets('Umschalter → Karten mit Zähler, Wischen blättert',
      (tester) async {
    await _zeige(tester);
    expect(find.byTooltip('Karten'), findsOneWidget);
    await _tippe(tester, find.byTooltip('Karten'));
    expect(find.byTooltip('Liste'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(_kartenName(tester), 'Kompensator');
    expect(find.text('Kompensator'), findsOneWidget);

    await _wische(tester);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(_kartenName(tester), 'Zapfhahn Chrom');

    await _tippe(tester, find.byTooltip('Liste'));
    expect(find.text('5 Materialien'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('Karten ohne FAB — er läge über dem Vormerken-Kreis',
      (tester) async {
    await _zeige(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await _tippe(tester, find.byTooltip('Karten'));
    expect(find.byType(FloatingActionButton), findsNothing);
    await _tippe(tester, find.byTooltip('Liste'));
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('kleines Handy (360×640): «+» ohne Scrollen sichtbar',
      (tester) async {
    // Bestand ± ist die Hauptaktion im Auto. Unter AppBar, Suche, Chips und
    // Zähler bleibt der Karte wenig Höhe — ein langer Name und zwei Zeilen
    // Beschreibung dürfen die Knöpfe nicht unter den Rand schieben.
    await _zeige(
      tester,
      groesse: const Size(360, 640),
      lager: [
        Lager(
          id: 'x1',
          userId: 'u',
          name: 'Zapfhahn Chrom mit Kompensator und Tropfschale',
          beschreibung: 'Standardhahn für Tresenanlagen, Kompensator stufenlos, '
              'Dichtungssatz dabei',
        ),
      ],
    );
    await _tippe(tester, find.byTooltip('Karten'));
    final plus = find.descendant(
      of: find.byType(MaterialKarte),
      matching: find.byIcon(Icons.add),
    );
    expect(tester.getRect(plus).bottom, lessThanOrEqualTo(640));
  });

  testWidgets('Karten lassen sich auch mit der Maus wischen (PC-Browser)',
      (tester) async {
    await _zeige(tester);
    await _tippe(tester, find.byTooltip('Karten'));
    await tester.drag(
      find.byType(PageView),
      const Offset(-400, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
  });

  testWidgets('Tipp auf die zweite Listenzeile öffnet deren Karte',
      (tester) async {
    await _zeige(tester);
    await _tippe(tester, find.text('Zapfhahn Chrom'));
    expect(find.text('2 / 5'), findsOneWidget);
    expect(_kartenName(tester), 'Zapfhahn Chrom');
  });

  testWidgets('Karten → Liste → andere Zeile: Karte stimmt wieder',
      (tester) async {
    // Der PageController war schon einmal an einen PageView gebunden —
    // der zweite Einstieg darf nicht auf der alten Seite landen.
    await _zeige(tester);
    await _tippe(tester, find.byTooltip('Karten'));
    await _wische(tester);
    await _tippe(tester, find.byTooltip('Liste'));
    await _tippe(tester, find.text('Bürste'));
    expect(find.text('4 / 5'), findsOneWidget);
    expect(_kartenName(tester), 'Bürste');
  });

  testWidgets('Umschalter kehrt zur zuletzt gesehenen Karte zurück',
      (tester) async {
    await _zeige(tester);
    await _tippe(tester, find.byTooltip('Karten'));
    await _wische(tester);
    await _wische(tester);
    expect(find.text('3 / 5'), findsOneWidget);
    await _tippe(tester, find.byTooltip('Liste'));
    await _tippe(tester, find.byTooltip('Karten'));
    expect(find.text('3 / 5'), findsOneWidget);
    expect(_kartenName(tester), 'Alkalireiniger');
  });

  testWidgets('Chipwechsel in den Karten springt auf die erste Karte',
      (tester) async {
    await _zeige(tester);
    await _tippe(tester, find.byTooltip('Karten'));
    await _wische(tester);
    await _wische(tester);
    expect(find.text('3 / 5'), findsOneWidget);

    await _tippe(tester, find.text('Zapfhahn · 2'));
    expect(find.text('1 / 2'), findsOneWidget);
    expect(_kartenName(tester), 'Kompensator');
  });

  testWidgets('Karten: nach «keine Treffer» wieder bei der ersten Karte',
      (tester) async {
    // Einstieg über Listenzeile 3: Der Controller startet dann bei Seite 2.
    // Während «keine Treffer» hängt er an keinem PageView — ein blosses
    // jumpToPage griffe ins Leere, und der neue PageView begänne wieder
    // bei Seite 3, während der Zähler «1 / 5» sagt.
    await _zeige(tester);
    await _tippe(tester, find.text('Alkalireiniger'));
    expect(find.text('3 / 5'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'gibtsnicht');
    await tester.pumpAndSettle();
    expect(find.text('Keine Ergebnisse'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    expect(_kartenName(tester), 'Kompensator');
  });

  testWidgets('jede Karte trägt die Artikel-ID als Key', (tester) async {
    await _zeige(tester);
    await _tippe(tester, find.byTooltip('Karten'));
    expect(
      tester.widget<MaterialKarte>(find.byType(MaterialKarte)).key,
      const ValueKey('a2'),
    );
  });

  testWidgets('gemerkte Ansicht und Kategorie beim Öffnen', (tester) async {
    await _zeige(tester, prefs: {
      'material_ansicht': 'karten',
      'material_kategorie': 'k-hahn',
    });
    expect(find.text('1 / 2'), findsOneWidget);
    expect(_kartenName(tester), 'Kompensator');
    expect(_chipAktiv(tester, 'Zapfhahn · 2'), isTrue);
  });

  testWidgets('gemerkte, nicht mehr belegte Kategorie → alle', (tester) async {
    await _zeige(tester, prefs: {'material_kategorie': 'k-leer'});
    expect(find.text('5 Materialien'), findsOneWidget);
    expect(_chipAktiv(tester, 'Alle'), isTrue);
  });

  testWidgets('Umschalter und Chip schreiben in die Prefs', (tester) async {
    await _zeige(tester);
    await _tippe(tester, find.byTooltip('Karten'));
    expect(await _pref('material_ansicht'), 'karten');
    await _tippe(tester, find.byTooltip('Liste'));
    expect(await _pref('material_ansicht'), 'liste');

    await _tippe(tester, find.text('Zapfhahn · 2'));
    expect(await _pref('material_kategorie'), 'k-hahn');
    await _tippe(tester, find.text('Zapfhahn · 2'));
    expect(await _pref('material_kategorie'), isNull);
  });

  testWidgets('Tipp auf eine Listenzeile merkt die Ansicht nicht',
      (tester) async {
    // Der Sprung in die Karte ist vorübergehend — beim nächsten Öffnen soll
    // wieder die Liste kommen, wenn man sie dort gewählt hatte.
    await _zeige(tester);
    await _tippe(tester, find.text('Kompensator'));
    expect(find.text('1 / 5'), findsOneWidget);
    expect(await _pref('material_ansicht'), isNull);
  });

  testWidgets('keine Überläufe bei 360 px, weder Liste noch Karten',
      (tester) async {
    await _zeige(tester);
    expect(tester.takeException(), isNull);
    await _tippe(tester, find.byTooltip('Karten'));
    expect(tester.takeException(), isNull);
  });
}
