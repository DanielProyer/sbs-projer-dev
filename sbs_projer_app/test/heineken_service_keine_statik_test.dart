import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/preis.dart';
import 'package:sbs_projer_app/services/rechnung/heineken_rechnung_service.dart';

/// A3 (Runde 5, 26.09.2026): `HeinekenRechnungService` hielt Anfahrts-
/// pauschale und PO-Nummer in `static`-Feldern, die jedes Laden der
/// Preisliste überschrieb und alle späteren Aufrufe lasen — gleiches Muster
/// wie der MwSt-Fehler aus Runde 4: ein Aufruf für einen anderen Monat
/// bestimmte die Werte des nächsten. Die Werte reisen jetzt pro Aufruf mit.
///
/// Wächter: kein veränderliches `static`-Feld mehr in den Heineken-Diensten.
/// `static const` und `static final` sind erlaubt, Methoden und Getter auch.
/// Der PDF-Dienst ist mit dabei: sein `static String _heinekenPo` wurde erst
/// beim `pdf.save()` gelesen (die build-Closure läuft verzögert) und konnte
/// bis dahin von einer anderen Rechnung überschrieben sein.
final _veraenderlichesStatikFeld = RegExp(
  r'^\s*static\s+(?!const\b|final\b)[\w<>?,. ]+\s+\w+\s*(=(?!>)|;)',
);

const _dateien = [
  'lib/services/rechnung/heineken_rechnung_service.dart',
  'lib/services/pdf/heineken_pdf_service.dart',
];

Preis _preis({Object? zuschlag, String? po}) => Preis.fromJson({
  'id': 'p1',
  'user_id': 'u1',
  'gueltig_ab': '2026-01-01',
  'bergkunden_zuschlag': zuschlag,
  'heineken_po_nummer': po,
});

void main() {
  group('Wächter: keine veränderlichen static-Felder', () {
    test('Muster erkennt veränderliche Felder und lässt den Rest durch', () {
      for (final zeile in [
        '  static double _anfahrtPauschale = 180.0;',
        '  static String _heinekenPoNummer = \'6100259429\';',
        '  static int _zaehler;',
        '  static Map<String, int> _cache = {};',
      ]) {
        expect(_veraenderlichesStatikFeld.hasMatch(zeile), isTrue,
            reason: zeile);
      }
      for (final zeile in [
        '  static const double _anfahrtFallback = 180.0;',
        '  static final _format = DateFormat();',
        '  static String get _userId => SupabaseService.dataUserId;',
        '  static double _round2(double v) => (v * 100).roundToDouble() / 100;',
        '  static Future<Preis?> _loadPreise({DateTime? datum}) async {',
      ]) {
        expect(_veraenderlichesStatikFeld.hasMatch(zeile), isFalse,
            reason: zeile);
      }
    });

    for (final datei in _dateien) {
      test('$datei hat kein veränderliches static-Feld', () {
        final zeilen = File(datei).readAsLinesSync();
        final treffer = <String>[
          for (var i = 0; i < zeilen.length; i++)
            if (_veraenderlichesStatikFeld.hasMatch(zeilen[i]))
              '  Z. ${i + 1}: ${zeilen[i].trim()}',
        ];
        expect(
          treffer,
          isEmpty,
          reason:
              'Veränderliche static-Felder in $datei — Werte aus der '
              'Preisliste pro Aufruf durchreichen (Parameter / '
              'HeinekenMonatsDaten), nicht zwischen Aufrufen teilen:\n'
              '${treffer.join('\n')}',
        );
      });
    }
  });

  group('HeinekenRechnungService.werteAusPreis', () {
    test('ohne Preisliste → Rückfall 180.00 / Standard-PO', () {
      final w = HeinekenRechnungService.werteAusPreis(null);
      expect(w.anfahrtPauschale, 180.0);
      expect(w.poNummer, '6100259429');
    });

    test('Werte der Preisliste gewinnen', () {
      final w = HeinekenRechnungService.werteAusPreis(
        _preis(zuschlag: 195.5, po: '6100999999'),
      );
      expect(w.anfahrtPauschale, 195.5);
      expect(w.poNummer, '6100999999');
    });

    test('Preisliste ohne PO-Nummer → Standard-PO', () {
      final w = HeinekenRechnungService.werteAusPreis(_preis(zuschlag: 200));
      expect(w.anfahrtPauschale, 200.0);
      expect(w.poNummer, '6100259429');
    });

    test('Aufrufe beeinflussen sich nicht gegenseitig', () {
      HeinekenRechnungService.werteAusPreis(_preis(zuschlag: 999, po: 'X'));
      final w = HeinekenRechnungService.werteAusPreis(null);
      expect(w.anfahrtPauschale, 180.0);
      expect(w.poNummer, '6100259429');
    });
  });
}
