import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Bis 27.09.2026 stand hier auch der Kachel-Text-Test (`DashboardTile` bei
// 360 px). Die Kachel ist mit dem Raster der Gruppe «Unterwegs» weg — alle
// Mehr-Gruppen sind Zeilen, ihr 360-px-Test steht in
// `bereich_gruppen_liste_test.dart`. Geblieben ist der Wächter der
// Startseite.
void main() {
  test('die Startseite ist nur noch der Tag (v0.131.0)', () {
    final quelle =
        File('lib/presentation/screens/home_screen.dart').readAsStringSync();
    for (final weg in [
      'DashboardTile(',
      '_KachelGrid',
      '_WeitereSection',
      '_MenuListTile',
      'Icons.logout',
    ]) {
      expect(quelle.contains(weg), isFalse,
          reason: '$weg gehoert seit v0.131.0 auf Mehr bzw. in die '
              'Einstellungen — auf Heute rutscht es unter den Tagesplan');
    }
    for (final bleibt in [
      'ArbeitstagKarte(',
      'HeuteListe(',
      '_AufgabenKarte(',
      'zeigeDiktatSheet',
      'EventKarten(',
      "context.push('/suche')",
    ]) {
      expect(quelle.contains(bleibt), isTrue, reason: bleibt);
    }
  });
}
