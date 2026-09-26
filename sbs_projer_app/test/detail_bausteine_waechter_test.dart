import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `class _SectionCard` und `class _InfoRow` standen textgleich in 11 bzw.
/// 13 Dateien (Detail-Screens). Ersetzt durch `DetailKarte`/`InfoZeile` in
/// `lib/presentation/widgets/detail/detail_karte.dart`.
///
/// WARUM als Wächter: Ohne ihn schleicht sich beim nächsten Detail-Screen
/// wieder eine Kopie ein, statt den gemeinsamen Baustein zu importieren.
///
/// Ausnahmen (bewusst KEIN DetailKarte/InfoZeile, weil das Layout/Verhalten
/// abweicht — Umbau hätte die Optik verändert):
/// - `einstellungen/stammdaten_screen.dart`: `_SectionCard` ist dort
///   `ExpansionTile`-basiert (auf-/zuklappbar), keine feste Card+Column.
///   `_InfoRow` läuft `spaceBetween` ohne feste Labelbreite, fett gesetzter
///   Wert, plus eigene `_EditableInfoRow` mit Stift-Icon.
/// - `materialien/material_detail_screen.dart` und
///   `rechnungen/rechnung_detail_screen.dart`: `_SectionCard` nimmt dort NUR
///   `children` entgegen — keinen Titel/Icon-Kopf, anders als der von
///   `DetailKarte` verlangte Vertrag. `_InfoRow` hat dort zusätzlich ein
///   anderes Padding (`symmetric(vertical: …)` statt `only(bottom: 8)`) und
///   in `rechnung_detail_screen.dart` ein `spaceBetween`-Layout ohne feste
///   Labelbreite.
/// - `heineken/heineken_rechnung_detail_screen.dart`: `_InfoRow` hat dort
///   ebenfalls ein anderes Padding (`symmetric(vertical: 4)`) und keinen
///   `crossAxisAlignment.start`.
/// - `bergkundenpauschalen/bergkundenpauschale_detail_screen.dart`:
///   `_InfoRow` ist dort eine rechtsbündige Wert-Zeile (`spaceBetween`,
///   `Flexible`+`textAlign: end`, fett gesetztes Label) — keine
///   Label/Wert-Beschreibungszeile.
void main() {
  const ausnahmenSectionCard = [
    'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    'lib/presentation/screens/materialien/material_detail_screen.dart',
    'lib/presentation/screens/rechnungen/rechnung_detail_screen.dart',
  ];

  const ausnahmenInfoRow = [
    'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    'lib/presentation/screens/materialien/material_detail_screen.dart',
    'lib/presentation/screens/rechnungen/rechnung_detail_screen.dart',
    'lib/presentation/screens/heineken/heineken_rechnung_detail_screen.dart',
    'lib/presentation/screens/bergkundenpauschalen/'
        'bergkundenpauschale_detail_screen.dart',
  ];

  List<String> dateien() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path.replaceAll('\\', '/'))
      .toList();

  test('class _SectionCard kommt nur in der Ausnahmeliste vor', () {
    final treffer = <String>[];
    for (final pfad in dateien()) {
      if (ausnahmenSectionCard.any(pfad.endsWith)) continue;
      final code = File(pfad).readAsStringSync();
      if (code.contains('class _SectionCard')) treffer.add(pfad);
    }
    expect(
      treffer,
      isEmpty,
      reason:
          'Diese Dateien haben wieder eine eigene _SectionCard statt '
          'DetailKarte aus lib/presentation/widgets/detail/detail_karte.dart:\n'
          '${treffer.join('\n')}',
    );
  });

  test('class _InfoRow kommt nur in der Ausnahmeliste vor', () {
    final treffer = <String>[];
    for (final pfad in dateien()) {
      if (ausnahmenInfoRow.any(pfad.endsWith)) continue;
      final code = File(pfad).readAsStringSync();
      if (code.contains('class _InfoRow')) treffer.add(pfad);
    }
    expect(
      treffer,
      isEmpty,
      reason:
          'Diese Dateien haben wieder eine eigene _InfoRow statt InfoZeile '
          'aus lib/presentation/widgets/detail/detail_karte.dart:\n'
          '${treffer.join('\n')}',
    );
  });
}
