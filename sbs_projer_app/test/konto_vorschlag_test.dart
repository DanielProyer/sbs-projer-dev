import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';
import 'package:sbs_projer_app/data/models/kreditor_regel.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/konto_vorschlag.dart';

final _kategorien = [
  const EingangsrechnungKategorie(
      code: 'busse', bezeichnung: 'Busse', defaultAufwandskonto: 6280),
  const EingangsrechnungKategorie(
      code: 'telekom_it',
      bezeichnung: 'Telekom & IT',
      defaultAufwandskonto: 6510,
      defaultVorsteuerKonto: 1171),
  const EingangsrechnungKategorie(
      code: 'sonstiges', bezeichnung: 'Sonstiges'),
];

KreditorRegel _regel({int aufwand = 6301, int? vorsteuer = 1170}) =>
    KreditorRegel(
      id: 'test-id',
      userId: 'test-user',
      lieferantNamePattern: 'Heineken',
      aufwandskonto: aufwand,
      vorsteuerKonto: vorsteuer,
    );

void main() {
  test('Aussteller-Regel gewinnt über Kategorie-Default', () {
    final v = schlageKontoVor(
        kategorie: 'busse', kategorien: _kategorien, regelTreffer: _regel());
    expect(v.aufwandskonto, 6301);
    expect(v.vorsteuerKonto, 1170);
  });

  test('ohne Regel: Kategorie-Default greift (Busse -> 6280)', () {
    final v = schlageKontoVor(kategorie: 'busse', kategorien: _kategorien);
    expect(v.aufwandskonto, 6280);
    expect(v.vorsteuerKonto, isNull);
  });

  test('Kategorie mit Vorsteuer-Default', () {
    final v = schlageKontoVor(kategorie: 'telekom_it', kategorien: _kategorien);
    expect(v.aufwandskonto, 6510);
    expect(v.vorsteuerKonto, 1171);
  });

  test('Kategorie mit Vorsteuer-Default, aber nicht MwSt-relevant -> '
      'Vorsteuer unterdrückt', () {
    final v = schlageKontoVor(
        kategorie: 'telekom_it',
        kategorien: _kategorien,
        mwstRelevant: false);
    expect(v.aufwandskonto, 6510);
    expect(v.vorsteuerKonto, isNull);
  });

  test('Kategorie mit Vorsteuer-Default + MwSt-relevant -> Vorsteuer gesetzt',
      () {
    final v = schlageKontoVor(
        kategorie: 'telekom_it',
        kategorien: _kategorien,
        mwstRelevant: true);
    expect(v.aufwandskonto, 6510);
    expect(v.vorsteuerKonto, 1171);
  });

  test('Kategorie ohne Default -> leer', () {
    final v = schlageKontoVor(kategorie: 'sonstiges', kategorien: _kategorien);
    expect(v.aufwandskonto, isNull);
    expect(v.vorsteuerKonto, isNull);
  });

  test('keine Kategorie + keine Regel -> leer', () {
    final v = schlageKontoVor(kategorie: null, kategorien: _kategorien);
    expect(v.aufwandskonto, isNull);
  });

  test('unbekannte Kategorie -> leer (kein Crash)', () {
    final v = schlageKontoVor(kategorie: 'gibtsnicht', kategorien: _kategorien);
    expect(v.aufwandskonto, isNull);
  });
}
