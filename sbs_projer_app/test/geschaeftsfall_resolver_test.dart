import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/services/buchhaltung/geschaeftsfall_resolver.dart';

BuchungsVorlage _v({
  String art = 'ausgabe',
  int? hauptkonto,
  int? soll,
  int? haben,
  int? mwstKonto,
}) =>
    BuchungsVorlage(
      id: 'x',
      userId: 'u',
      geschaeftsfallId: 'g',
      bezeichnung: 'b',
      art: art,
      hauptkonto: hauptkonto,
      sollKonto: soll,
      habenKonto: haben,
      mwstKonto: mwstKonto,
      erlaubteZahlungswege: const ['kasse', 'bank', 'privat', 'kreditor'],
    );

void main() {
  test('ausgabe + bank → Soll=Hauptkonto, Haben=1020', () {
    final r = GeschaeftsfallResolver.aufloesen(
        _v(hauptkonto: 6200, mwstKonto: 1171), 'bank');
    expect(r.sollKonto, 6200);
    expect(r.habenKonto, 1020);
    expect(r.mwstKonto, 1171);
  });

  test('ausgabe + kreditor → Haben=2000', () {
    final r = GeschaeftsfallResolver.aufloesen(_v(hauptkonto: 6301), 'kreditor');
    expect(r.habenKonto, 2000);
  });

  test('ausgabe + privat → Haben=2260', () {
    final r = GeschaeftsfallResolver.aufloesen(_v(hauptkonto: 6500), 'privat');
    expect(r.habenKonto, 2260);
  });

  test('einnahme + debitor → Soll=1100, Haben=Hauptkonto, MWST=Umsatzsteuer', () {
    final r = GeschaeftsfallResolver.aufloesen(
        _v(art: 'einnahme', hauptkonto: 3400, mwstKonto: 2200), 'debitor');
    expect(r.sollKonto, 1100);
    expect(r.habenKonto, 3400);
    expect(r.mwstKonto, 2200);
  });

  test('fix → Soll/Haben direkt aus Vorlage', () {
    final r = GeschaeftsfallResolver.aufloesen(
        _v(art: 'fix', soll: 6301, haben: 2000, mwstKonto: 1170), null);
    expect(r.sollKonto, 6301);
    expect(r.habenKonto, 2000);
  });

  test('unbekannter Zahlungsweg → ArgumentError', () {
    expect(() => GeschaeftsfallResolver.aufloesen(_v(hauptkonto: 6200), 'paypal'),
        throwsArgumentError);
  });
}
