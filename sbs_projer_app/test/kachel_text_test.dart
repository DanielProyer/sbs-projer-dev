import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test für Schritt 4 (A2): die neuen Kachel-Zähler-Texte ("12 diese Woche")
// sind deutlich länger als die alten reinen Zahlen ("933") und müssen bei
// 360 px logischer Breite (Pixel 9, 2 Spalten) ohne Overflow passen.
//
// `_DashboardTile` ist private in home_screen.dart und über die echte
// Startseite nur mit vollständiger Riverpod-Verdrahtung erreichbar (Sync-,
// Connectivity-, Aufgaben-, Tagesübersicht- und alle Kachel-Zähler-Provider,
// dazu SupabaseService-Init für den Abmelden-Button in der AppBar) — reiner
// Mock-Aufwand ohne Mehrwert für diese eine Layout-Frage. Stattdessen baut
// dieser Test den Kachel-Baustein 1:1 nach der Struktur in
// `_DashboardTile.build` (Card > InkWell > Padding > Column > Icon, Row mit
// Flexible-Label + Flexible-Zähler-Container) nach — inklusive Grid mit
// zwei Spalten, wie es `_KachelGrid` tatsächlich verwendet.
Widget _kachelNachbau({required String label, required String? count}) {
  const color = Colors.green;
  return Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.cleaning_services, color: color, size: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count,
                        style: const TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Kachel-Grid bei 360px: lange Zähler-Texte laufen nicht über',
    (tester) async {
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
                children: [
                  // Realistische, eher grosszügige Werte je Kachel-Text —
                  // die längste Variante ("… diese Woche") mit zweistelliger
                  // Zahl ist der Belastungstest.
                  _kachelNachbau(label: 'Betriebe', count: null),
                  _kachelNachbau(
                    label: 'Reinigungen',
                    count: '18 diese Woche',
                  ),
                  _kachelNachbau(label: 'Störungen', count: '12 offen'),
                  _kachelNachbau(label: 'Montagen', count: '9 geplant'),
                  _kachelNachbau(
                    label: 'Eigenaufträge',
                    count: '15 offen',
                  ),
                  _kachelNachbau(label: 'Eröffnungen', count: null),
                  _kachelNachbau(label: 'Kontakte', count: null),
                  _kachelNachbau(label: 'Aufgaben', count: '23'),
                  _kachelNachbau(label: 'Tourenplanung', count: '31 fällig'),
                  _kachelNachbau(label: 'Spesen', count: null),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
