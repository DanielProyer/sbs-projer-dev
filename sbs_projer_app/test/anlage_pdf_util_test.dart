import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/anlage_pdf_util.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';

AnlageLocal _a(String typ, String status, {DateTime? naechste, String rhythmus = '4-Wochen'}) {
  final a = AnlageLocal();
  a.typAnlage = typ;
  a.status = status;
  a.naechsteReinigung = naechste;
  a.reinigungRhythmus = rhythmus;
  return a;
}

void main() {
  // PDF-Services laden die Unicode-Schrift aus den Assets (rootBundle).
  TestWidgetsFlutterBinding.ensureInitialized();
  final jetzt = DateTime(2026, 7, 10);

  group('anlagenKennzahlen', () {
    test('zaehlt nur aktive, gruppiert nach Typ', () {
      final k = anlagenKennzahlen([
        _a('Warmanstich', 'aktiv'),
        _a('Warmanstich', 'aktiv'),
        _a('Orion', 'aktiv'),
        _a('Warmanstich', 'inaktiv'), // zaehlt nicht
      ], jetzt);
      expect(k.gesamt, 3);
      expect(k.nachTyp['Warmanstich'], 2);
      expect(k.nachTyp['Orion'], 1);
    });

    test('unbekannter Typ -> Sonstige', () {
      final k = anlagenKennzahlen([_a('Exotic', 'aktiv')], jetzt);
      expect(k.nachTyp['Sonstige'], 1);
    });

    test('ueberfaellig = naechste Reinigung vor jetzt (nur aktive)', () {
      final k = anlagenKennzahlen([
        _a('Warmanstich', 'aktiv', naechste: DateTime(2026, 7, 1)), // ueberfaellig
        _a('Warmanstich', 'aktiv', naechste: DateTime(2026, 8, 1)), // nicht
        _a('Warmanstich', 'inaktiv', naechste: DateTime(2026, 1, 1)), // inaktiv -> nicht
      ], jetzt);
      expect(k.ueberfaellig, 1);
    });

    test('ohneRhythmus zaehlt leer/keiner', () {
      final k = anlagenKennzahlen([
        _a('Warmanstich', 'aktiv', rhythmus: ''),
        _a('Warmanstich', 'aktiv', rhythmus: 'keiner'),
        _a('Warmanstich', 'aktiv', rhythmus: '4-Wochen'),
      ], jetzt);
      expect(k.ohneRhythmus, 2);
    });
  });

  group('Dateiname/Betreff', () {
    test('Dateiname ersetzt Sonderzeichen/Slashes', () {
      expect(anlageSteckbriefDateiname('Sonne/Bar', 'Warm 1'),
          'Steckbrief_Sonne-Bar_Warm-1.pdf');
    });
    test('Dateiname faellt auf Anlage zurueck wenn Bezeichnung leer', () {
      expect(anlageSteckbriefDateiname('Sonne', ''), 'Steckbrief_Sonne_Anlage.pdf');
    });
    test('Betreff enthaelt Betrieb + Anlage', () {
      expect(anlageMailBetreff('Sonne', 'Warm 1'), 'Anlagen-Steckbrief: Sonne — Warm 1');
    });
  });
}
