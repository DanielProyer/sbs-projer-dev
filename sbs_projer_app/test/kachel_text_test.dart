import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/screens/home_screen.dart';

// Test für Schritt 4 (A2): die neuen Kachel-Zähler-Texte ("18 diese Woche")
// sind deutlich länger als die alten reinen Zahlen ("933") und müssen bei
// 360 px logischer Breite (Pixel 9, 2 Spalten) ohne Overflow passen.
//
// Rendert `DashboardTile` (bis 13.09.2026 `_DashboardTile`, für diesen Test
// öffentlich gemacht) DIREKT, nicht nachgebaut: die Kachel selbst ist ein
// reines StatelessWidget ohne Provider-Zugriff — icon/label/count/color/
// onTap sind einfache Parameter, verdrahtet wird erst in `_KachelGrid`. Ein
// Nachbau hätte nur seine eigene Kopie geprüft und wäre stumm geblieben,
// wenn sich die echte Kachel ändert (z. B. das `Flexible` um den
// Zähler-Container verschwindet) — genau das Muster, das am 10.09.2026 zwei
// Wächter-Tests wirkungslos gemacht hat.
void main() {
  // Mit der echten Schrift messen, nicht mit der Ersatzschrift des
  // Test-Runners.
  //
  // WARUM: Ohne geladene Schrift rendert Flutter im Test eine Ersatzschrift,
  // die deutlich breiter baut als Roboto. Ein Layout-Test misst dann etwas
  // anderes als das Gerät zeigt — am 13.09.2026 meldete ein 360-px-Test
  // 42 px Überlauf, den es auf dem Pixel 9 nicht gab, und am 15.09.2026
  // hielt er «Reinigungen» für gekürzt, während im Browser alles stand.
  // Solche Fehlalarme sind gefährlicher als kein Test: Man gewöhnt sich an,
  // sie wegzudrücken. Roboto liegt ohnehin im Repo (für die PDFs).
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  Future<void> pumpGrid(WidgetTester tester, List<Widget> kacheln) async {
    // Pixel 9 (logische Breite 360px) — dieselbe Referenzgrösse, mit der
    // das Kachel-Raster im Kommentar von _KachelGrid begründet wird.
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 2.1,
              children: kacheln,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'DashboardTile bei 360px: langer Zähler-Text ("18 diese Woche") läuft nicht über',
    (tester) async {
      await pumpGrid(tester, [
        DashboardTile(
          icon: Icons.cleaning_services,
          label: 'Reinigungen',
          count: '18 diese Woche',
          color: Colors.green,
          onTap: () {},
        ),
        DashboardTile(
          icon: Icons.build_circle_outlined,
          label: 'Eigenaufträge',
          count: '15 offen',
          color: Colors.purple,
          onTap: () {},
        ),
      ]);

      expect(tester.takeException(), isNull);
    },
  );

  // Kein Überlauf heisst noch nicht lesbar: Am 15.09.2026 stand auf dem
  // Pixel 9 «87 diese Woc…» — die Ellipsis fing den Überlauf ab, und genau
  // deshalb schlug der Test oben nicht an. `didExceedMaxLines` prüft, was
  // wirklich zählt: ob der Text vollständig dargestellt wird.
  testWidgets(
    'DashboardTile bei 360px: der echte Zähler-Text wird nicht gekürzt',
    (tester) async {
      await pumpGrid(tester, [
        DashboardTile(
          icon: Icons.cleaning_services,
          label: 'Reinigungen',
          count: '87 diese Woche',
          color: Colors.green,
          onTap: () {},
        ),
        DashboardTile(
          icon: Icons.warning_amber,
          label: 'Störungen',
          count: '12 offen',
          color: Colors.orange,
          onTap: () {},
        ),
      ]);

      for (final text in ['87 diese Woche', '12 offen', 'Reinigungen', 'Störungen']) {
        final absatz = tester.renderObject<RenderParagraph>(find.text(text));
        expect(
          absatz.didExceedMaxLines,
          isFalse,
          reason:
              '«$text» wird auf 360 px gekuerzt dargestellt. Kuerzeren Text '
              'waehlen — die Schrift zu verkleinern ist keine Option, 11 px '
              'ist die Untergrenze fuer Lesbarkeit im Keller.',
        );
      }
    },
  );

  testWidgets(
    'DashboardTile bei 360px: kurzer Zähler-Text läuft nicht über',
    (tester) async {
      await pumpGrid(tester, [
        DashboardTile(
          icon: Icons.warning_amber,
          label: 'Störungen',
          count: '3 offen',
          color: Colors.orange,
          onTap: () {},
        ),
      ]);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DashboardTile bei 360px: count null (z.B. Betriebe, Kontakte) läuft nicht über',
    (tester) async {
      await pumpGrid(tester, [
        DashboardTile(
          icon: Icons.store,
          label: 'Betriebe',
          count: null,
          color: Colors.blue,
          onTap: () {},
        ),
      ]);

      expect(tester.takeException(), isNull);
    },
  );
}
