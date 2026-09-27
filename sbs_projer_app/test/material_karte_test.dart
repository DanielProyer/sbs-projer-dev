import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/widgets/material_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

/// Material-Karte der Swipe-Ansicht: Foto, Nummern, Bestand ± und
/// Vormerken — am Handy (360 px).

Lager _lager({
  double bestand = 5,
  double mindest = 3,
  bool vorgemerkt = false,
  String? beschreibung = 'Chromhahn mit Kompensator',
}) =>
    Lager(
      id: 'l1',
      userId: 'u',
      name: 'Zapfhahn Chrom',
      dboNr: '123',
      sapNr: '456',
      beschreibung: beschreibung,
      bestandAktuell: bestand,
      bestandMindest: mindest,
      bestandOptimal: 10,
      vorgemerkt: vorgemerkt,
    );

class _Aufrufe {
  final bestand = <double>[];
  final vormerken = <bool>[];
  var details = 0;
}

Widget _app(
  Lager lager,
  _Aufrufe r, {
  bool bearbeitbar = true,
  Future<void> Function(double)? onBestand,
  Future<void> Function(bool)? onVormerken,
}) =>
    MaterialApp(
      home: Scaffold(
        body: MaterialKarte(
          lager: lager,
          kategorieName: 'Zapfhahn',
          fotoUrl: Future.value(null),
          bearbeitbar: bearbeitbar,
          onBestand: onBestand ??
              (neu) async {
                r.bestand.add(neu);
              },
          onVormerken: onVormerken ??
              (v) async {
                r.vormerken.add(v);
              },
          onDetails: () => r.details++,
        ),
      ),
    );

Future<_Aufrufe> _zeige(
  WidgetTester tester,
  Lager lager, {
  bool bearbeitbar = true,
  Future<void> Function(double)? onBestand,
  Future<void> Function(bool)? onVormerken,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final r = _Aufrufe();
  await tester.pumpWidget(
    _app(lager, r,
        bearbeitbar: bearbeitbar,
        onBestand: onBestand,
        onVormerken: onVormerken),
  );
  await tester.pumpAndSettle();
  return r;
}

Future<void> _tippe(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('zeigt Name, Nummern, Beschreibung und Bestand', (tester) async {
    await _zeige(tester, _lager());
    expect(find.text('Zapfhahn Chrom'), findsOneWidget);
    expect(find.text('DBO 123 · SAP 456 · Zapfhahn'), findsOneWidget);
    expect(find.text('Chromhahn mit Kompensator'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Stück'), findsOneWidget);
    expect(find.text('Mindest 3 · Optimal 10'), findsOneWidget);
    expect(find.text('Unter Mindestbestand'), findsNothing);
    // Ohne Foto: Platzhalter statt leerer Fläche.
    expect(find.byIcon(Icons.inventory_2), findsOneWidget);
  });

  testWidgets('«+» speichert 6 und zeigt 6 ohne Neuladen', (tester) async {
    final r = await _zeige(tester, _lager());
    await _tippe(tester, find.byIcon(Icons.add));
    expect(r.bestand, [6]);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('«−» speichert 4', (tester) async {
    final r = await _zeige(tester, _lager());
    await _tippe(tester, find.byIcon(Icons.remove));
    expect(r.bestand, [4]);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('«−» bei 0 tut nichts', (tester) async {
    final r = await _zeige(tester, _lager(bestand: 0));
    await _tippe(tester, find.byIcon(Icons.remove));
    expect(r.bestand, isEmpty);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('Fehler beim Speichern → alter Wert und Meldung', (tester) async {
    await _zeige(
      tester,
      _lager(),
      onBestand: (_) async => throw Exception('offline'),
    );
    await _tippe(tester, find.byIcon(Icons.add));
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsNothing);
    expect(find.text('Bestand konnte nicht gespeichert werden'), findsOneWidget);
  });

  testWidgets('während des Speicherns sind ± gesperrt', (tester) async {
    final laufend = Completer<void>();
    final aufrufe = <double>[];
    await _zeige(
      tester,
      _lager(),
      onBestand: (neu) {
        aufrufe.add(neu);
        return laufend.future;
      },
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    // Nur EIN Request — ein zweiter hätte denselben Ausgangswert gehabt.
    expect(aufrufe, [6]);
    expect(find.text('6'), findsOneWidget);

    laufend.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(aufrufe, [6, 7]);
  });

  testWidgets('«Unter Mindestbestand» sofort nach dem Tipp, nicht erst nach '
      'dem Neuladen', (tester) async {
    await _zeige(tester, _lager(bestand: 3, mindest: 3));
    expect(find.text('Unter Mindestbestand'), findsNothing);
    await _tippe(tester, find.byIcon(Icons.remove));
    expect(find.text('Unter Mindestbestand'), findsOneWidget);
  });

  testWidgets('neuer Stand vom Server wird übernommen', (tester) async {
    final r = await _zeige(tester, _lager());
    await tester.pumpWidget(_app(_lager(bestand: 8, vorgemerkt: true), r));
    await tester.pumpAndSettle();
    expect(find.text('8'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('Vormerken schaltet sofort um', (tester) async {
    final r = await _zeige(tester, _lager());
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    await _tippe(tester, find.byIcon(Icons.bookmark_border));
    expect(r.vormerken, [true]);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('Vormerken-Fehler → zurück und Meldung', (tester) async {
    await _zeige(
      tester,
      _lager(),
      onVormerken: (_) async => throw Exception('offline'),
    );
    await _tippe(tester, find.byIcon(Icons.bookmark_border));
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(
      find.text('Vormerkung konnte nicht gespeichert werden'),
      findsOneWidget,
    );
  });

  testWidgets('Details ruft onDetails', (tester) async {
    final r = await _zeige(tester, _lager());
    expect(find.widgetWithText(TapKnopf, 'Details'), findsOneWidget);
    await _tippe(tester, find.text('Details'));
    expect(r.details, 1);
  });

  testWidgets('nicht bearbeitbar: keine ± Knöpfe, Vormerken nur Anzeige',
      (tester) async {
    final r = await _zeige(tester, _lager(vorgemerkt: true),
        bearbeitbar: false);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    await _tippe(tester, find.byIcon(Icons.bookmark));
    expect(r.vormerken, isEmpty);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('Knöpfe sind gross genug für den Daumen', (tester) async {
    await _zeige(tester, _lager());
    for (final icon in [Icons.add, Icons.remove, Icons.bookmark_border]) {
      final flaeche = tester.getSize(find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(InkWell),
      ));
      expect(flaeche.width, greaterThanOrEqualTo(44), reason: '$icon');
      expect(flaeche.height, greaterThanOrEqualTo(44), reason: '$icon');
    }
  });

  testWidgets('lange Texte laufen bei 360 px nicht über', (tester) async {
    await _zeige(
      tester,
      _lager(beschreibung: List.filled(80, 'Sehr lange Beschreibung').join(' ')),
    );
    expect(tester.takeException(), isNull);
  });
}
