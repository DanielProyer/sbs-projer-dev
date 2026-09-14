import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Jeder Mail-Versand einer Rechnung muss `markiereVersandt` mitschicken.
///
/// WARUM: Die Edge Function `send-rechnung-mail` vermerkt den Versand seit
/// v15/v16 selbst — serverseitig und über `EdgeRuntime.waitUntil`, damit der
/// Vermerk auch dann gesetzt wird, wenn der Client die Verbindung kappt
/// (Handy weggesteckt, Tab eingefroren). Sie tut das aber nur, wenn der
/// Aufrufer `markiereVersandt: true` sendet:
///
/// ```js
/// if (markiereVersandt === true && rechnungId && !istMahnung) { … }
/// ```
///
/// Fehlt das Flag, fällt der Vermerk auf den alten Weg zurück: Die App setzt
/// ihn, NACHDEM sie die Antwort bekommen hat. Kommt die Antwort nicht an, ist
/// die Mail beim Kunden und die Rechnung steht in der App auf «offen» — mit
/// der Gefahr, dass sie ein zweites Mal verschickt wird.
///
/// Am **14.09.2026** passierte das zweimal an einem Tag: Blue Cinema (14:03,
/// CHF 256.20) und Alpina Resort (16:08, CHF 74.60). Beide Mails waren
/// nachweislich versendet (Gmail messageIds im Function-Log), beide Rechnungen
/// standen auf «offen». Der Serverfix existierte zu dem Zeitpunkt seit drei
/// Tagen — der Abschluss im Reinigungsformular schaltete ihn nur nie ein.
///
/// AUSNAHME Mahnungen: Dort ist `versendet_am` das Datum der Erstversendung
/// und der Status darf nicht auf «gesendet» zurückfallen. Die Function
/// erkennt sie an `pdfPath: 'mahnung_…'` und überspringt den Vermerk selbst.
void main() {
  test('jeder Rechnungs-Mailversand schickt markiereVersandt mit', () {
    final verstoesse = <String>[];

    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final f in dateien) {
      final text = _ohneKommentare(f.readAsStringSync());
      var start = text.indexOf("'send-rechnung-mail'");
      while (start != -1) {
        final block = _argumentBlock(text, start);
        // Nur Aufrufe mit Rechnungsbezug sind betroffen: ohne `rechnungId`
        // gäbe es nichts zu vermerken (Materialbestellung, HeiGenie-Protokoll).
        final hatRechnung = block.contains('rechnungId');
        // Mahnungen sind ausgenommen — siehe Kopfkommentar.
        final istMahnung = block.contains('mahnung_');
        if (hatRechnung && !istMahnung && !block.contains('markiereVersandt')) {
          final zeile = '\n'.allMatches(text.substring(0, start)).length + 1;
          verstoesse.add('${f.path}:$zeile');
        }
        start = text.indexOf("'send-rechnung-mail'", start + 1);
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Aufruf von send-rechnung-mail mit rechnungId, aber ohne '
          'markiereVersandt. Die Function ueberspringt dann ihren '
          'serverseitigen Vermerk, und der Status haengt allein an der '
          'Antwort. Bricht die Verbindung ab, liegt die Rechnung beim Kunden '
          'und steht in der App auf «offen» — Gefahr Doppelversand '
          '(Vorfaelle 27.08., 07.09., 11.09. und zweimal am 14.09.2026). '
          "Ergaenze 'markiereVersandt': MailConfig.istScharf('reinigung') "
          'bzw. true.',
    );
  });
}

/// Blendet Zeilenkommentare aus.
///
/// Ohne das schlaegt der Waechter auf seine eigene Erklaerung an — genau der
/// Fehler, der am 10.09.2026 zwei andere Waechter-Tests unbrauchbar machte.
String _ohneKommentare(String quelle) => quelle
    .split('\n')
    .map((z) {
      final k = z.indexOf('//');
      return k == -1 ? z : z.substring(0, k);
    })
    .join('\n');

/// Der Argument-Block ab [start] bis zur schliessenden Klammer auf gleicher
/// Tiefe. Ein fester Zeichenabstand reichte nicht: Die `bodyText`-Vorlagen im
/// Reinigungsformular sind mehrere hundert Zeichen lang, und `markiereVersandt`
/// steht dahinter.
String _argumentBlock(String text, int start) {
  var tiefe = 0;
  var gesehen = false;
  for (var i = start; i < text.length; i++) {
    final c = text[i];
    if (c == '(') {
      tiefe++;
      gesehen = true;
    } else if (c == ')') {
      tiefe--;
      if (gesehen && tiefe <= 0) return text.substring(start, i);
    }
  }
  return text.substring(start);
}
