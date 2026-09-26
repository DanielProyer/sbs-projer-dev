import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Heineken-Rechnung löschen (Review 26.09.2026, g): Nach den awaits kann
/// der Screen weg sein — `ref` wirft dann. Das Invalidieren stand deshalb
/// hinter `if (!mounted) return;` und fiel genau dann aus: Liste und Journal
/// zeigten die gelöschte Rechnung samt Buchungen weiter. Der Container wird
/// vor den awaits geholt und unabhängig von `mounted` invalidiert.
void main() {
  final code = File(
    'lib/presentation/screens/heineken/heineken_rechnung_detail_screen.dart',
  ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');

  String rumpf(String kopf) {
    final start = code.indexOf(kopf);
    expect(start, greaterThanOrEqualTo(0), reason: 'nicht gefunden: $kopf');
    final auf = code.indexOf('{', code.indexOf(')', start));
    var tiefe = 0;
    for (var i = auf; i < code.length; i++) {
      if (code[i] == '{') tiefe++;
      if (code[i] == '}') {
        tiefe--;
        if (tiefe == 0) return code.substring(auf, i + 1);
      }
    }
    fail('Rumpf von $kopf nicht geschlossen');
  }

  test('Löschen invalidiert über den Container, unabhängig von mounted', () {
    final loeschen = rumpf('Future<void> _delete()');
    final container = loeschen.indexOf(
      'ProviderScope.containerOf(context, listen: false)',
    );
    expect(container, greaterThanOrEqualTo(0));
    expect(
      container,
      lessThan(loeschen.indexOf('await ')),
      reason: 'den Container VOR dem ersten await holen',
    );

    expect(loeschen, isNot(contains('ref.invalidate(')));
    final rechnungen = loeschen.indexOf(
      'container.invalidate(heinekenRechnungenProvider)',
    );
    expect(rechnungen, greaterThanOrEqualTo(0));
    expect(
      rechnungen,
      lessThan(loeschen.indexOf('if (!mounted) return;')),
      reason: 'invalidieren, bevor ein weggeräumter Screen abbricht',
    );
    expect(loeschen, contains('container.invalidate(buchungenStreamProvider)'));
    expect(
      loeschen,
      isNot(contains('isNotEmpty && mounted')),
      reason: 'auch die Buchungen unabhängig von mounted auffrischen',
    );
  });
}
