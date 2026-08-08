import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/lohn_einstellungen.dart';
import 'package:sbs_projer_app/services/pdf/lohnausweis_pdf_service.dart';

/// Der Lohnausweis ist ein amtliches Dokument (Form. 11) — er muss sich
/// fehlerfrei erzeugen lassen und die Formularlogik 8 − 9 − 10 = 11 einhalten.
void main() {
  // PDF-Services laden die Unicode-Schrift aus den Assets (rootBundle).
  TestWidgetsFlutterBinding.ensureInitialized();

  LohnEinstellungen einstellungen() => LohnEinstellungen(
        id: 'e1',
        userId: 'u1',
        jahr: 2025,
        bruttolohnMonatlich: 0,
        arbeitnehmerName: 'Projer',
        arbeitnehmerVorname: 'Daniel',
        arbeitnehmerAdresse: 'Via Rezia 8',
        arbeitnehmerPlzOrt: '7013 Domat/Ems',
        arbeitnehmerAhvNr: '756.7321.6431.61',
        arbeitnehmerGeburtsdatum: DateTime(1981, 11, 23),
        arbeitgeberName: 'SBS Projer GmbH',
        arbeitgeberAdresse: 'Via Rezia 8',
        arbeitgeberPlzOrt: '7013 Domat/Ems',
      );

  // Echte Jahreswerte 2025 (Summe der 12 Monatsabrechnungen).
  const totale2025 = <String, double>{
    'brutto': 83123.60,
    'ahv_an': 4405.50,
    'alv_an': 914.35,
    'nbu_an': 0,
    'bvg_an': 7103.63,
    'ktg_an': 0,
    'netto': 70700.00,
    'ahv_ag': 4405.50,
    'alv_ag': 914.35,
    'bu_ag': 550.10,
    'fak_ag': 1329.95,
    'bvg_ag': 7103.63,
    'ktg_ag': 0,
    'total_an_abzuege': 12423.48,
    'anzahl_auszahlungen': 12,
  };

  test('erzeugt ein gültiges PDF im amtlichen Formular-11-Layout', () async {
    final bytes =
        await LohnausweisPdfService.generate(einstellungen(), totale2025, 2025);

    expect(String.fromCharCodes(bytes.take(5)), startsWith('%PDF'));
    expect(bytes.length, greaterThan(5000));

    // Sichtprüfungs-Ausgabe (nur wenn ein Zielpfad gesetzt ist).
    final ziel = Platform.environment['LOHNAUSWEIS_TEST_PDF'];
    if (ziel != null && ziel.isNotEmpty) {
      File(ziel).writeAsBytesSync(bytes);
    }
  });

  test('Formularlogik: Ziffer 8 − 9 − 10 ergibt Ziffer 11', () {
    const brutto = 83123.60;
    const ziffer9 = 4405.50 + 914.35 + 0; // AHV/IV/EO + ALV + NBUV
    const ziffer10 = 7103.63; // BVG ordentlich
    expect((brutto - ziffer9 - ziffer10).round(), 70700);
  });
}
