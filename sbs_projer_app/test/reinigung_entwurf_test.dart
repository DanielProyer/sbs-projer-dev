import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/reinigung_entwurf.dart';

void main() {
  final gespeichert = DateTime(2026, 9, 26, 9, 12, 30);

  ReinigungEntwurf voll() => ReinigungEntwurf(
    betriebId: 'b-1',
    anlageIds: const ['a-1', 'a-2'],
    datum: DateTime(2026, 9, 26),
    uhrzeitStart: '08:45',
    serviceArt: 'endreinigung',
    serviceTyp: 'reinigung_orion',
    anzahlHaehneEigen: 3,
    anzahlHaehneOrion: 2,
    anzahlHaehneFremd: 1,
    anzahlHaehneWein: 4,
    anzahlHaehneAndererStandort: 5,
    istKulanz: true,
    istBergkunde: true,
    notizen: 'Hahn 3 tropft',
    protokollFotoPfad: 'x/y.jpg',
    fotoReinigungId: 'r-9',
    zahlungsart: null,
    gespeichertAm: gespeichert,
  );

  test('Roundtrip toJson/fromJson behält alle Felder', () {
    final e = ReinigungEntwurf.fromJson(voll().toJson());
    expect(e.betriebId, 'b-1');
    expect(e.anlageIds, ['a-1', 'a-2']);
    expect(e.datum, DateTime(2026, 9, 26));
    expect(e.uhrzeitStart, '08:45');
    expect(e.serviceArt, 'endreinigung');
    expect(e.serviceTyp, 'reinigung_orion');
    expect(e.anzahlHaehneEigen, 3);
    expect(e.anzahlHaehneOrion, 2);
    expect(e.anzahlHaehneFremd, 1);
    expect(e.anzahlHaehneWein, 4);
    expect(e.anzahlHaehneAndererStandort, 5);
    expect(e.istKulanz, isTrue);
    expect(e.istBergkunde, isTrue);
    expect(e.notizen, 'Hahn 3 tropft');
    expect(e.protokollFotoPfad, 'x/y.jpg');
    expect(e.fotoReinigungId, 'r-9');
    expect(e.zahlungsart, isNull);
    expect(e.gespeichertAm, gespeichert);
  });

  test('kaputtes/leeres JSON wirft nie, liefert Standardwerte', () {
    final e = ReinigungEntwurf.fromJson({
      'betrieb_id': 42,
      'anlage_ids': 'kein array',
      'datum': 'murks',
      'anzahl_haehne_eigen': 'drei',
      'anzahl_haehne_orion': -4,
      'ist_kulanz': 'ja',
      'gespeichert_am': null,
    });
    expect(e.betriebId, '');
    expect(e.anlageIds, isEmpty);
    expect(e.anzahlHaehneEigen, 0);
    expect(e.anzahlHaehneOrion, 0);
    expect(e.istKulanz, isFalse);
    expect(e.serviceArt, 'standardservice');
    expect(e.serviceTyp, isNull);
    expect(e.notizen, isNull);

    final leer = ReinigungEntwurf.fromJson(const {});
    expect(leer.betriebId, '');
    // Ohne Zeitstempel gilt der Entwurf als uralt — lieber verwerfen als
    // einen unbekannten Stand vorschlagen.
    expect(leer.istAbgelaufen(DateTime(2026, 9, 26)), isTrue);
  });

  test('Anlage-Liste mit Fremdkörpern: nur Strings bleiben', () {
    final e = ReinigungEntwurf.fromJson({
      'anlage_ids': ['a', 3, null, 'b'],
    });
    expect(e.anlageIds, ['a', 'b']);
  });

  test('istAbgelaufen: älter als 2 Tage', () {
    final e = voll();
    expect(e.istAbgelaufen(gespeichert.add(const Duration(hours: 47))), isFalse);
    expect(e.istAbgelaufen(gespeichert.add(const Duration(days: 2, minutes: 1))),
        isTrue);
  });

  test('kurzText zeigt die Uhrzeit der Sicherung', () {
    expect(voll().kurzText(), '09:12');
  });
}
