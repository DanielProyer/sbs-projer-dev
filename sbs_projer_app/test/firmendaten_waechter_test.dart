import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Firmendaten (IBAN, Adresse, Telefon) stehen in `lib/` nur in
/// `geschaeft_einstellungen.dart` — als Rückfall-Konstanten neben den
/// Gettern, über die PDFs, QR-Zahlteil, Rechnungsdetail und Mails sie lesen.
///
/// Vor Runde 4 (26.09.2026) stand die IBAN dreifach und die Adresse in
/// sieben Dateien. Ändert sich Bank oder Telefon, hätten QR-Rechnung und
/// PDF-Fuss auseinanderlaufen können.
void main() {
  test('Firmendaten-Literale nur in geschaeft_einstellungen.dart', () {
    const verboten = [
      'CH66 0077',
      'CH6600774010376550601',
      'Via Rezia',
      '566 58 06',
      'CHE-413.083.919',
    ];
    final treffer = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final pfad = f.path.replaceAll(r'\', '/');
      if (pfad.endsWith('data/models/geschaeft_einstellungen.dart')) continue;
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        for (final v in verboten) {
          if (zeilen[i].contains(v)) {
            treffer.add('$pfad:${i + 1}: ${zeilen[i].trim()}');
          }
        }
      }
    }
    expect(treffer, isEmpty,
        reason: 'Firmendaten über GeschaeftEinstellungen lesen '
            '(ibanFormatiert, ibanKompakt, adresseStrasse, telefonOrFallback …)');
  });
}
