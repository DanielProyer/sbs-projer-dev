import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Review zu fe43767c: Kam die Antwort des Mailversands nicht an (Hinweis aus
/// `_sendeMail`), darf der Client den Versand NICHT selbst vermerken — im
/// Stand «unklar» wäre das eine Behauptung ohne Beleg, die Rechnung stünde
/// auf `gesendet` und würde nie nachgeholt. Jeder Vermerk-Aufruf in
/// `erstelleUndSende` hängt deshalb an `versandHinweis == null`, und ein
/// scheiternder Vermerk fragt den Server (statt roter Kettenfehler).
void main() {
  final s = File(
    'lib/services/rechnung/reinigung_rechnung_versand.dart',
  ).readAsStringSync();

  String erstelleUndSende() {
    final start = s.indexOf('erstelleUndSende(');
    final ende = s.indexOf('static Future<String?> _sendeMail', start);
    expect(start, greaterThan(-1));
    expect(ende, greaterThan(start));
    return s.substring(start, ende);
  }

  test('jeder Vermerk in erstelleUndSende steht hinter versandHinweis == null',
      () {
    final body = erstelleUndSende();
    final aufrufe =
        RegExp(r'(vermerkeVersand|_vermerkeMitNachfrage)\(').allMatches(body);
    expect(aufrufe, isNotEmpty);
    for (final m in aufrufe) {
      final davor = body.substring(0, m.start);
      // Gleichwertig: `versandHinweis ??= await …` direkt davor.
      final zeile = davor.substring(davor.lastIndexOf('\n') + 1);
      if (zeile.contains('versandHinweis ??=')) continue;
      // Sonst steht die Bedingung in der if-Zeile direkt davor.
      final ifZeile = davor.lastIndexOf('if (');
      expect(ifZeile, greaterThan(-1));
      expect(
        davor.substring(ifZeile).contains('versandHinweis == null'),
        isTrue,
        reason: 'Vermerk ohne Guard bei Offset ${m.start}',
      );
    }
  });

  test('scheiternder Vermerk fragt den Server statt zu werfen', () {
    final start = s.indexOf('static Future<String?> _vermerkeMitNachfrage');
    expect(start, greaterThan(-1));
    final body = s.substring(start, s.indexOf('\n  }\n', start));
    expect(body.contains('istVersandVermerkt'), isTrue);
    expect(body.contains('throw VersandFehler('), isTrue);
    expect(body.contains('rethrow'), isFalse);
  });
}
