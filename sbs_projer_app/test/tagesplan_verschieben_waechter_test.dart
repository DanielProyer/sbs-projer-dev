import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter (Review 26.09.2026, M3): Das Verschieben eines Tagesplan-Stopps
/// setzt an Störung/Montage NUR das Plandatum um.
///
/// Anlass: Es lief über `einplanen(… dauerMin: e.dauerMinuten ?? 60)`. Aus
/// der Fällig-Liste übernommene Einsätze tragen `dauerMinuten == null`, und
/// `geplantDauerMin` steht nicht im Plan-JSON — eine 180-min-Montage
/// schrumpfte beim Verschieben auf 60 min, auch im Google-Kalender.

/// Rumpf der Funktion/Methode, deren Kopf [kopf] enthält (Klammern gezählt).
String _rumpf(String quelle, String kopf) {
  final start = quelle.indexOf(kopf);
  expect(start, greaterThanOrEqualTo(0), reason: 'nicht gefunden: $kopf');
  final auf = quelle.indexOf('{', quelle.indexOf(')', start));
  var tiefe = 0;
  for (var i = auf; i < quelle.length; i++) {
    if (quelle[i] == '{') tiefe++;
    if (quelle[i] == '}') {
      tiefe--;
      if (tiefe == 0) return quelle.substring(auf, i + 1);
    }
  }
  fail('Rumpf von $kopf nicht geschlossen');
}

void main() {
  test('Verschieben plant Einsätze nur über umplanenAufTag um', () {
    final screen = File(
      'lib/presentation/screens/touren/tourenplanung_screen.dart',
    ).readAsStringSync();
    final rumpf = _rumpf(screen, 'Future<int> _einsaetzeAufTagUmplanen(');
    expect(rumpf, contains('StoerungRepository.umplanenAufTag('));
    expect(rumpf, contains('MontageRepository.umplanenAufTag('));
    expect(rumpf, isNot(contains('einplanen(')));
    // Einsatz-Id über die eine Regel, nicht über das Präfix (K2).
    expect(rumpf, contains('geplanteEinsatzId('));
    expect(rumpf, isNot(contains("startsWith('s_')")));
  });

  for (final (datei, tabelle) in [
    ('lib/data/repositories/stoerung_repository.dart', 'stoerungen'),
    ('lib/data/repositories/montage_repository.dart', 'montagen'),
  ]) {
    test('$tabelle: umplanenAufTag schreibt nur geplant_am + Kalender', () {
      final rumpf = _rumpf(
        File(datei).readAsStringSync(),
        'static Future<void> umplanenAufTag(',
      );
      expect(rumpf, contains("'geplant_am'"));
      expect(rumpf, isNot(contains('geplant_zeit')));
      expect(rumpf, isNot(contains('geplant_dauer_min')));
      expect(rumpf, isNot(contains('geplantZeit')));
      expect(rumpf, isNot(contains('geplantDauerMin')));
      expect(rumpf, contains('GoogleCalendarSyncService.push('));
    });
  }
}
