import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_gruppen_liste.dart';

void main() {
  // Echte Schrift, sonst misst der Test eine breitere Ersatzschrift: Am
  // 13.09.2026 meldete ein 360-px-Test 42 px Überlauf, den es auf dem
  // Pixel 9 nicht gab, am 15.09.2026 hielt er «Reinigungen» für gekürzt.
  // Solche Fehlalarme gewöhnen einen ans Wegdrücken. Roboto liegt ohnehin
  // im Repo (für die PDFs).
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  Future<List<String>> pump(
    WidgetTester tester, {
    String? Function(BereichEintrag)? zaehler,
    List<BereichGruppe>? gruppen,
  }) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final getippt = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Wie BereichScreen: 12 px Rand links und rechts.
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            children: [
              BereichGruppenListe(
                gruppen: gruppen ?? kBereichMehr.gruppen,
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
      if (e.untertitel != null) {
        expect(find.text(e.untertitel!), findsOneWidget, reason: e.untertitel);
      }
    }
  });

  testWidgets('Tippen meldet das Ziel', (tester) async {
    final getippt = await pump(tester);
    await tester.tap(find.text('Abschlüsse und Steuern'));
    await tester.tap(find.text('Einsätze'));
    expect(getippt, ['/abschluesse', '/einsaetze']);
  });

  testWidgets('Zaehler erscheint nur, wo einer geliefert wird', (tester) async {
    await pump(
      tester,
      zaehler: (e) => e.ziel == '/rechnungen' ? '2 offen' : null,
    );
    expect(find.text('2 offen'), findsOneWidget);
  });

  testWidgets('passt auf 360 px ohne Ueberlauf und ohne gekuerzte Texte', (
    tester,
  ) async {
    await pump(tester, zaehler: (e) => e.zaehler == null ? null : '12 offen');
    expect(tester.takeException(), isNull);
    for (final e in kBereichMehr.alleEintraege) {
      for (final t in [e.titel, ?e.untertitel]) {
        final absatz = tester.renderObject<RenderParagraph>(find.text(t));
        expect(absatz.didExceedMaxLines, isFalse, reason: t);
      }
    }
  });

  testWidgets('alle Gruppen sind Zeilen, alle Zeilen gleich hoch', (
    tester,
  ) async {
    await pump(tester, zaehler: (e) => e.zaehler == null ? null : '3');
    // Kein Kachel-Raster mehr (bis 27.09.2026 «Unterwegs»).
    expect(find.byType(GridView), findsNothing);
    final hoehen = {
      for (final e in kBereichMehr.alleEintraege)
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(e.titel),
                    matching: find.byType(InkWell),
                  )
                  .first,
            )
            .height,
    };
    expect(hoehen, {kBereichZeileHoehe});
  });

  testWidgets('Bereichsseiten ohne Gruppentitel zeichnen sich ebenso', (
    tester,
  ) async {
    final getippt = await pump(tester, gruppen: kBereichBank.gruppen);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Eingangsrechnungen'));
    expect(getippt, ['/buchhaltung/eingangsrechnungen']);
  });
}
