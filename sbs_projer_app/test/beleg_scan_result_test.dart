import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/beleg_scan_result.dart';

void main() {
  Map<String, dynamic> json({dynamic drehung}) => {
        'geschaeft': 'Coop Pronto',
        'datum': '2026-07-18',
        'total_brutto': 10.10,
        'konfidenz': 0.95,
        'positionen': [
          {
            'mwst_satz': 8.1,
            'betrag_brutto': 10.10,
            'beschreibung': 'Diesel',
            'kategorie': 'benzin',
          }
        ],
        if (drehung != null) 'bild_drehung': drehung,
      };

  group('bildDrehung', () {
    test('fehlendes Feld -> 0 (ältere Antworten bleiben gültig)', () {
      expect(BelegScanResult.fromJson(json()).bildDrehung, 0);
    });
    test('90er-Schritte werden übernommen', () {
      for (final grad in [0, 90, 180, 270]) {
        expect(BelegScanResult.fromJson(json(drehung: grad)).bildDrehung, grad);
      }
    });
    test('Zahl als String wird gelesen', () {
      expect(BelegScanResult.fromJson(json(drehung: '90')).bildDrehung, 90);
    });
    test('krummer Wert -> 0 statt schief gespeichertem Beleg', () {
      expect(BelegScanResult.fromJson(json(drehung: 45)).bildDrehung, 0);
      expect(BelegScanResult.fromJson(json(drehung: -90)).bildDrehung, 0);
      expect(BelegScanResult.fromJson(json(drehung: 'quer')).bildDrehung, 0);
    });
  });
}
