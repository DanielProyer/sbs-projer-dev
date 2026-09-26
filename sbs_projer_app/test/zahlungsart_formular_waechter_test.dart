import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Die Zahlungsart steht als Zeile im Reinigungsformular; der Abschluss-Dialog
/// kommt nur noch, wenn `abschlussDialogGruende` etwas meldet (V6).
///
/// WARUM: Bis V6 öffnete jeder Abschluss einen Dialog mit Zahlungsart-
/// Dropdown — in 82 % der Fälle wurde die Vorgabe unverändert bestätigt
/// (Analyse 25.09.2026, Bericht 4 «Tagesbetrieb», Schritt 6). Kommt das
/// Dropdown in den Dialog zurück, ist der Umweg wieder da.
void main() {
  final text = File(
    'lib/presentation/screens/reinigungen/reinigung_form_screen.dart',
  ).readAsStringSync();

  test('Abschluss entscheidet über abschlussDialogGruende', () {
    expect(text, contains('abschlussDialogGruende('));
  });

  test('kein Zahlungsart-Dropdown mehr im Abschluss-Dialog', () {
    expect(
      text,
      isNot(contains('Zahlungsart für DIESE Reinigung:')),
      reason: 'Marker des alten Dialog-Dropdowns',
    );
    expect(
      text,
      isNot(contains("labelText: 'Zahlungsart'")),
      reason: 'Die Zahlungsart wird im Formular gewählt, nicht im Dialog',
    );
  });

  test('Zeile im Formular öffnet die Auswahl als Bottom-Sheet', () {
    expect(text, contains('Widget _zahlungsartZeile('));
    expect(text, contains('_zahlungsartWaehlen('));
    expect(text, contains('zahlungsartAuswahl'));
  });

  test('Entwurf trägt die Zahlungsart', () {
    expect(text, contains('zahlungsart: '));
    expect(text, contains('e.zahlungsart'));
  });
}
