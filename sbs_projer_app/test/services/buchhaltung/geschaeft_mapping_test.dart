// test/services/buchhaltung/geschaeft_mapping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/services/buchhaltung/geschaeft_mapping.dart';

void main() {
  const g = GeschaeftEinstellungen(
    firmaName: 'SBS Projer GmbH',
    strasse: 'Via Rezia 8',
    plzOrt: '7013 Domat/Ems',
    gfVorname: 'Daniel',
    gfName: 'Projer',
  );

  test('arbeitgeber liefert Firma/Strasse/PLZ-Ort aus Geschäft', () {
    final ag = GeschaeftMapping.arbeitgeber(g);
    expect(ag.name, 'SBS Projer GmbH');
    expect(ag.adresse, 'Via Rezia 8');
    expect(ag.plzOrt, '7013 Domat/Ems');
  });

  test('arbeitnehmerPrefill füllt nur leere Felder', () {
    final pf = GeschaeftMapping.arbeitnehmerPrefill(
        (name: null, vorname: '', adresse: 'Eigene Strasse 1', plzOrt: null), g);
    expect(pf.name, 'Projer');
    expect(pf.vorname, 'Daniel');
    expect(pf.adresse, 'Eigene Strasse 1');
    expect(pf.plzOrt, '7013 Domat/Ems');
  });
}
