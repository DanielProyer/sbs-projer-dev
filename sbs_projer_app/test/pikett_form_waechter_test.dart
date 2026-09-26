import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pikett-Formular: zwei Fehler, die still falsche Pauschalen erzeugten
/// (Code-Review 26.09.2026). Das Formular hängt an Repository und Supabase,
/// deshalb hält ein Quelltext-Wächter die Regeln fest.
void main() {
  final code = File(
    'lib/presentation/screens/pikett/pikett_dienst_form_screen.dart',
  ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');

  String methode(String kopf) {
    final start = code.indexOf(kopf);
    expect(start, isNot(-1), reason: '$kopf nicht gefunden');
    // Bis zur nächsten Methode dieser Klasse.
    final naechste = RegExp(r'\n  [A-Za-z<>?]+[^\n]*\(.*\{');
    final ende = code.indexOf(naechste, start + 1);
    return code.substring(start, ende == -1 ? code.length : ende);
  }

  test('Bearbeiten übernimmt die gespeicherte Anzahl Feiertage', () {
    final laden = methode('Future<void> _loadPikett()');
    expect(laden.contains('_anzahlFeiertage = p.anzahlFeiertage'), isTrue);
    expect(
      laden.contains('_berechneFeiertage('),
      isFalse,
      reason:
          '_berechneFeiertage() überschreibt die Anzahl — beim Laden nur die '
          'erkannten Feiertage anzeigen, die gespeicherte Anzahl behalten.',
    );
  });

  // Review 26.09.2026 (h): Preisliste und gespeicherter Dienst laden
  // parallel. Kam die Preisliste als zweite, überschrieb sie beim Bearbeiten
  // die gespeicherte Pauschale mit dem heutigen Tarif.
  test('Bearbeiten: die Preisliste überschreibt die Pauschale nicht', () {
    final preise = methode('Future<void> _loadPauschale()');
    expect(
      RegExp(r'if \([^)]*!_isEdit[^)]*\) _pauschale = ').hasMatch(preise),
      isTrue,
      reason: 'die Pauschale aus der Preisliste nur beim Anlegen vorbelegen',
    );
    expect(
      RegExp(r'if \([^)]*!_zuschlagAusDienst[^)]*\) _feiertagZuschlagProTag = ')
          .hasMatch(preise),
      isTrue,
      reason: 'den aus dem Dienst zurückgerechneten Zuschlag nicht ersetzen',
    );
    for (final zeile in preise.split('\n')) {
      if (!zeile.contains('_pauschale = ')) continue;
      expect(
        zeile,
        contains('!_isEdit'),
        reason: 'keine unbedingte Zuweisung der Preisliste an _pauschale',
      );
    }

    final laden = methode('Future<void> _loadPikett()');
    expect(laden, contains('_pauschale = p.pauschale'));
    expect(laden, contains('_zuschlagAusDienst = true'));
  });

  test('das Jahr ist das ISO-Wochenjahr, nicht das Kalenderjahr', () {
    expect(
      RegExp(r'_jahr = [^;]*\.year;').hasMatch(code),
      isFalse,
      reason:
          'KW 1/2026 beginnt am 29.12.2025 — _jahr über isoWochenjahr() '
          'setzen, nie über DateTime.year.',
    );
    expect(code.contains('isoWochenjahr('), isTrue);
  });
}
