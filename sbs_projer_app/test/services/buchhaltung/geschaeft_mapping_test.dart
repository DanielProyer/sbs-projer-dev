import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/services/buchhaltung/geschaeft_mapping.dart';

void main() {
  final g = GeschaeftEinstellungen(
    firmaName: 'SBS Projer GmbH',
    strasse: 'Via Rezia 8',
    plzOrt: '7013 Domat/Ems',
    gfVorname: 'Daniel',
    gfName: 'Projer',
    gfAhvNr: '756.1234.5678.90',
    gfGeburtsdatum: DateTime(1985, 4, 12),
  );

  test('arbeitgeber liefert Firma/Strasse/PLZ-Ort aus Geschäft', () {
    final ag = GeschaeftMapping.arbeitgeber(g);
    expect(ag.name, 'SBS Projer GmbH');
    expect(ag.adresse, 'Via Rezia 8');
    expect(ag.plzOrt, '7013 Domat/Ems');
  });

  test('arbeitnehmer liefert vollständigen Snapshot inkl. Geburtsjahr', () {
    final an = GeschaeftMapping.arbeitnehmer(g);
    expect(an.name, 'Projer');
    expect(an.vorname, 'Daniel');
    expect(an.adresse, 'Via Rezia 8');
    expect(an.plzOrt, '7013 Domat/Ems');
    expect(an.ahvNr, '756.1234.5678.90');
    expect(an.geburtsdatum, DateTime(1985, 4, 12));
    expect(an.geburtsjahr, 1985);
  });

  test('arbeitnehmer ohne Geburtsdatum → Geburtsjahr 1990', () {
    final an = GeschaeftMapping.arbeitnehmer(const GeschaeftEinstellungen());
    expect(an.geburtsjahr, 1990);
    expect(an.geburtsdatum, isNull);
  });
}
