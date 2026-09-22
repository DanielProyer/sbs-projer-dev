import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_gruppen_liste.dart';

void main() {
  // Echte Schrift, sonst misst der Test eine breitere Ersatzschrift
  // (Fehlalarme vom 13. und 15.09.2026, siehe kachel_text_test.dart).
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  Future<List<String>> pump(
    WidgetTester tester, {
    String? Function(BereichEintrag)? zaehler,
  }) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final getippt = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              BereichGruppenListe(
                gruppen: kBereichMehr.gruppen,
                zaehler: zaehler ?? (_) => null,
                onTap: getippt.add,
              ),
            ],
          ),
        ),
      ),
    );
    return getippt;
  }

  testWidgets('zeigt Gruppenkoepfe und alle Eintraege der Mehr-Seite', (
    tester,
  ) async {
    await pump(tester);
    for (final t in ['Unterwegs', 'Büro', 'Einrichtung']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    for (final e in kBereichMehr.alleEintraege) {
      expect(find.text(e.titel), findsOneWidget, reason: e.titel);
    }
  });

  testWidgets('Tippen meldet das Ziel', (tester) async {
    final getippt = await pump(tester);
    await tester.tap(find.text('Abschlüsse und Steuern'));
    await tester.tap(find.text('Material'));
    expect(getippt, ['/abschluesse', '/materialien']);
  });

  testWidgets('Zaehler erscheint nur, wo einer geliefert wird', (tester) async {
    await pump(
      tester,
      zaehler: (e) => e.ziel == '/rechnungen' ? '2 offen' : null,
    );
    expect(find.text('2 offen'), findsOneWidget);
  });

  testWidgets('passt auf 360 px ohne Ueberlauf und ohne gekuerzte Titel', (
    tester,
  ) async {
    await pump(tester, zaehler: (e) => e.zaehler == null ? null : '12 offen');
    expect(tester.takeException(), isNull);
    for (final e in kBereichMehr.alleEintraege) {
      final absatz = tester.renderObject<RenderParagraph>(find.text(e.titel));
      expect(absatz.didExceedMaxLines, isFalse, reason: e.titel);
    }
  });
}
