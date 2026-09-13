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
