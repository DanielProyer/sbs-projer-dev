import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/google_termin_match.dart';

// Kandidaten aus den echten Kollisions-Daten
final _betriebe = <BetriebKandidat>[
  const BetriebKandidat(betriebId: 'b-cal-chur', name: 'Calanda', ort: 'Chur'),
  const BetriebKandidat(betriebId: 'b-cal-fels', name: 'Calanda', ort: 'Felsberg'),
  const BetriebKandidat(betriebId: 'b-alp-vals', name: 'Alpina', ort: 'Vals'),
  const BetriebKandidat(betriebId: 'b-alp-breil', name: 'Alpina', ort: 'Breil/Brigels'),
  const BetriebKandidat(betriebId: 'b-bernina', name: 'Bernina', ort: 'Thusis'),
  const BetriebKandidat(betriebId: 'b-bernina-bar', name: 'Bernina Bar', ort: 'Thusis'),
  const BetriebKandidat(betriebId: 'b-raetia-ilanz', name: 'Rätia', ort: 'Ilanz'),
  const BetriebKandidat(betriebId: 'b-braema', name: 'Bräma', ort: 'Davos Platz'),
];

void main() {
  test('Ort disambiguiert Namenskollision: Chur -> Calanda Chur', () {
    final m = matcheTitel('Chur - Calanda Reinigung', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-cal-chur');
  });

  test('Anderer Ort -> anderer Calanda', () {
    final m = matcheTitel('Felsberg Calanda', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-cal-fels');
  });

  test('Name ohne Ort im Titel -> kein Treffer (konservativ)', () {
    final m = matcheTitel('Calanda', _betriebe);
    expect(m.bucket, MatchBucket.keinTreffer);
  });

  test('Alpina in 4 Orten: nur Vals passt', () {
    final m = matcheTitel('Alpina Vals', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-alp-vals');
  });

  test('Ort-Slash-Normalisierung: Breil matcht Breil/Brigels', () {
    final m = matcheTitel('Breil - Alpina', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-alp-breil');
  });

  test('Gattungswort bleibt unterscheidend: "Bernina Thusis" nur Bernina', () {
    final m = matcheTitel('Bernina Thusis', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-bernina');
  });

  test('Beide Bernina im Titel -> mehrdeutig', () {
    final m = matcheTitel('Bernina Bar Thusis', _betriebe);
    expect(m.bucket, MatchBucket.mehrdeutig);
    expect(m.kandidaten.length, 2);
  });

  test('Umlaut-Faltung: Rätia Ilanz', () {
    final m = matcheTitel('Raetia Ilanz Service', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-raetia-ilanz');
  });

  test('Davos-Suffix tolerant: "Davos" matcht "Davos Platz"', () {
    final m = matcheTitel('Davos - Bräma', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-braema');
  });

  test('Tippfehler im Namen (1 Zeichen): Alpna -> Alpina', () {
    final m = matcheTitel('Vals Alpna', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-alp-vals');
  });

  test('Privater Termin -> kein Treffer', () {
    final m = matcheTitel('Zahnarzt Termin 14:00', _betriebe);
    expect(m.bucket, MatchBucket.keinTreffer);
  });

  test('normalisiereOrt: Slash/Bindestrich/Davos', () {
    expect(normalisiereOrt('Breil/Brigels'), 'breil');
    expect(normalisiereOrt('Klosters-Serneus'), 'klosters');
    expect(normalisiereOrt('Davos Platz'), 'davos');
    expect(normalisiereOrt('Disentis/Mustér'), 'disentis');
  });
}
