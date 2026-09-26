import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter (V3, Runde 5): Stopps aus dem Tagesplan starten nur über
/// `startRoute()` in `core/util/einsatz_start.dart`.
///
/// Anlass: Alle Start-Kopien (Heute, Tourenplan, Diktat) öffneten bei einer
/// GEPLANTEN Störung/Montage ein neues Formular — doppelter Einsatz, der
/// geplante Stopp blieb ewig offen. Eine neue Kopie brächte den Fehler zurück.
void main() {
  const muster = [
    "'/stoerungen/neu?betriebId=",
    "'/montagen/neu?betriebId=",
    "'/reinigungen/neu?betriebId=",
  ];

  /// Echte Ausnahmen: Stellen OHNE `TourEintrag` — dort gibt es keinen
  /// geplanten Einsatz, den man öffnen könnte.
  const ausnahmen = {
    // Die Funktion selbst.
    'lib/core/util/einsatz_start.dart',
    // «Neue Störung» / «Neue Reinigung» auf der Betriebsseite: bewusst ein
    // NEUER Einsatz ohne Plan (Reinigung ohne vorgewählte Anlagen — das
    // Formular wählt dann alle Anlagen des Betriebs vor).
    'lib/presentation/screens/betriebe/betrieb_detail_screen.dart',
    // Betriebsauswahl, wenn `/reinigungen/neu` ohne Betrieb aufgerufen wird.
    'lib/presentation/screens/reinigungen/reinigung_betrieb_auswahl_screen.dart',
  };

  test('Start-Routen nur in einsatz_start.dart (plus Ausnahmen)', () {
    final treffer = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final pfad = f.path.replaceAll('\\', '/');
      if (ausnahmen.contains(pfad)) continue;
      final text = f.readAsStringSync();
      for (final m in muster) {
        if (text.contains(m)) treffer.add('$pfad: $m');
      }
    }
    expect(
      treffer,
      isEmpty,
      reason:
          'Stopps aus dem Tagesplan über startRoute() starten '
          '(core/util/einsatz_start.dart) — sonst öffnet eine geplante '
          'Störung/Montage ein neues Formular statt des Einsatzes.',
    );
  });

  test('Ausnahmen gibt es noch (sonst Liste aufräumen)', () {
    for (final a in ausnahmen) {
      expect(File(a).existsSync(), isTrue, reason: a);
    }
  });

  test('Service-Arten aus dem Plan stehen im Dropdown des Formulars', () {
    // startRoute gibt `eroeffnungsservice`/`endreinigung` mit; das Formular
    // übernimmt nur Werte aus `ReinigungFormScreen.serviceArten`. Beide
    // Listen müssen zum Dropdown passen, sonst bleibt die Vorgabe still weg.
    final form = File(
      'lib/presentation/screens/reinigungen/reinigung_form_screen.dart',
    ).readAsStringSync();
    for (final wert in const [
      'standardservice',
      'endreinigung',
      'eroeffnungsservice',
    ]) {
      expect(form, contains("value: '$wert'"), reason: wert);
    }
    final start = File('lib/core/util/einsatz_start.dart').readAsStringSync();
    expect(start, contains("'eroeffnungsservice'"));
    expect(start, contains("'endreinigung'"));
  });

  test('Heute, Tourenplan und Diktat rufen startRoute', () {
    for (final f in const [
      'lib/presentation/widgets/heute_liste.dart',
      'lib/presentation/screens/touren/tourenplanung_screen.dart',
      'lib/presentation/widgets/diktat_sheet.dart',
    ]) {
      expect(File(f).readAsStringSync(), contains('startRoute('), reason: f);
    }
  });
}
