import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/material_filter.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/widgets/material_kategorie_chips.dart';

/// Kategorie-Chips des Material-Screens in einer horizontal scrollenden
/// Zeile — am Handy (360 px).

final _chips = [
  const KategorieChip(id: 'k-hahn', name: 'Zapfhahn', anzahl: 2),
  const KategorieChip(id: 'k-dicht', name: 'Dichtungen', anzahl: 1),
  const KategorieChip(id: kOhneKategorie, name: 'Ohne Kategorie', anzahl: 3),
];

class _Aufrufe {
  final kategorie = <String?>[];
  final niedrig = <bool>[];
}

Future<_Aufrufe> _zeige(
  WidgetTester tester, {
  List<KategorieChip>? chips,
  String? gewaehlt,
  bool nurNiedrig = false,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final r = _Aufrufe();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            MaterialKategorieChips(
              chips: chips ?? _chips,
              gewaehlt: gewaehlt,
              nurNiedrig: nurNiedrig,
              niedrigAnzahl: 4,
              onKategorie: r.kategorie.add,
              onNurNiedrig: r.niedrig.add,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return r;
}

/// Die Zeile scrollt horizontal (und zentriert den gewählten Chip) —
/// vor jedem Tipp den Chip ins Bild holen, sonst geht der Tipp daneben.
Future<void> _tippe(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

bool _aktiv(WidgetTester tester, String text) => tester
    .widget<FilterChip>(find.ancestor(
      of: find.text(text),
      matching: find.byType(FilterChip),
    ))
    .selected;

void main() {
  testWidgets('Reihenfolge: Niedrig, Alle, Kategorien, Ohne Kategorie',
      (tester) async {
    await _zeige(tester);
    final texte = tester
        .widgetList<FilterChip>(find.byType(FilterChip))
        .map((c) => ((c.label as Text).data)!)
        .toList();
    expect(texte, [
      'Niedrig · 4',
      'Alle',
      'Zapfhahn · 2',
      'Dichtungen · 1',
      'Ohne Kategorie · 3',
    ]);
    expect(_aktiv(tester, 'Alle'), isTrue);
    expect(_aktiv(tester, 'Zapfhahn · 2'), isFalse);
    expect(_aktiv(tester, 'Niedrig · 4'), isFalse);
  });

  testWidgets('Einzelauswahl: Tipp wählt, nochmals Tipp wählt ab',
      (tester) async {
    final r = await _zeige(tester, gewaehlt: 'k-hahn');
    expect(_aktiv(tester, 'Zapfhahn · 2'), isTrue);
    expect(_aktiv(tester, 'Alle'), isFalse);

    await _tippe(tester, 'Dichtungen · 1');
    await _tippe(tester, 'Zapfhahn · 2');
    await _tippe(tester, 'Alle');
    expect(r.kategorie, ['k-dicht', null, null]);
  });

  testWidgets('«Ohne Kategorie» liefert kOhneKategorie', (tester) async {
    final r = await _zeige(tester);
    await _tippe(tester, 'Ohne Kategorie · 3');
    expect(r.kategorie, [kOhneKategorie]);
  });

  testWidgets('Niedrig ist ein eigener Schalter', (tester) async {
    final r = await _zeige(tester, gewaehlt: 'k-hahn', nurNiedrig: true);
    expect(_aktiv(tester, 'Niedrig · 4'), isTrue);
    expect(_aktiv(tester, 'Zapfhahn · 2'), isTrue);
    await _tippe(tester, 'Niedrig · 4');
    expect(r.niedrig, [false]);
    expect(r.kategorie, isEmpty);
  });

  testWidgets('gewählter Chip weit hinten wird ins Bild gescrollt',
      (tester) async {
    final viele = [
      for (var i = 1; i <= 15; i++)
        KategorieChip(id: 'k$i', name: 'Kategorie $i', anzahl: i),
    ];
    await _zeige(tester, chips: viele, gewaehlt: 'k15');
    final rect = tester.getRect(find.text('Kategorie 15 · 15'));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(360));
  });

  testWidgets('Tippziele mindestens 44 px hoch', (tester) async {
    await _zeige(tester);
    final groesse = tester.getSize(find.byType(FilterChip).first);
    expect(groesse.height, greaterThanOrEqualTo(44));
  });

  testWidgets('keine Überläufe bei 360 px', (tester) async {
    await _zeige(tester);
    expect(tester.takeException(), isNull);
  });
}
