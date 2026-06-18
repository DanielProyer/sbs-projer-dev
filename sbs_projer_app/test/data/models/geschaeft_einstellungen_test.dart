import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';

void main() {
  test('leeres Model liefert Fallback-Konstanten', () {
    const g = GeschaeftEinstellungen();
    expect(g.firma, 'SBS Projer GmbH');
    expect(g.adresseStrasse, 'Via Rezia 8');
    expect(g.adressePlzOrt, '7013 Domat/Ems');
    expect(g.mailEmpfaenger, 'dani.proyer@gmail.com');
  });

  test('mailEmpfaenger Reihenfolge geschaeft → privat → default', () {
    expect(const GeschaeftEinstellungen(mailGeschaeft: 'a@x.ch').mailEmpfaenger, 'a@x.ch');
    expect(const GeschaeftEinstellungen(mailPrivat: 'b@x.ch').mailEmpfaenger, 'b@x.ch');
    expect(const GeschaeftEinstellungen(mailGeschaeft: '  ', mailPrivat: 'b@x.ch').mailEmpfaenger, 'b@x.ch');
  });

  test('gesetzte Werte überschreiben Fallback; gfVollname + mwstZeile', () {
    const g = GeschaeftEinstellungen(
      firmaName: 'Meine AG', gfVorname: 'Max', gfName: 'Muster', mwstNummer: 'CHE-123.456.789');
    expect(g.firma, 'Meine AG');
    expect(g.gfVollname, 'Max Muster');
    expect(g.mwstZeile, 'CHE-123.456.789 MWST');
    expect(const GeschaeftEinstellungen().mwstZeile, '');
  });

  test('gfGeburtsjahr aus Geburtsdatum, sonst 1990; AN-Felder via JSON', () {
    final g = GeschaeftEinstellungen(gfGeburtsdatum: DateTime(1985, 4, 12), gfAhvNr: '756.1234.5678.90');
    expect(g.gfGeburtsjahr, 1985);
    expect(const GeschaeftEinstellungen().gfGeburtsjahr, 1990);
    final json = g.toJson();
    expect(json['gf_ahv_nr'], '756.1234.5678.90');
    expect(json['gf_geburtsdatum'], '1985-04-12');
    final back = GeschaeftEinstellungen.fromJson({'id': '1', 'user_id': 'u', 'gf_geburtsdatum': '1985-04-12'});
    expect(back.gfGeburtsdatum, DateTime(1985, 4, 12));
  });
}
