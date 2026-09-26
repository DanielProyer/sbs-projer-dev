import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// R7 (Analyse 25.09.2026): Formular schrieb die 5 Altspalten, Tourenplan las
/// `betrieb_ferien` — drei Perioden fehlten in der Planung. Ab v0.141.0 ist
/// die Tabelle die einzige gepflegte Quelle; Formular, Detail und Raster
/// lesen und schreiben nur noch sie.
void main() {
  String lies(String p) => File(p).readAsStringSync();
  test('Formular schreibt keine Altspalten mehr', () {
    final s = lies('lib/presentation/screens/betriebe/betrieb_form_screen.dart');
    for (final alt in ['ferienStart =', 'ferien2Start', 'ferien3Start', 'ferien4Start', 'ferien5Start', '_ferienStarts']) {
      expect(s.contains(alt), isFalse, reason: alt);
    }
    expect(s.contains('BetriebFerienListe('), isTrue);
  });
  test('Detail und Raster lesen die Tabelle', () {
    expect(lies('lib/presentation/screens/betriebe/betrieb_detail_screen.dart').contains('BetriebFerienListe('), isTrue);
    expect(lies('lib/presentation/screens/heineken/heineken_raster_screen.dart').contains('ferienPeriodenProvider'), isTrue);
  });
}
