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
  // Echte Fälle aus dem Live-Test (Gattungswort, abweichender/fehlender Ort):
  const BetriebKandidat(betriebId: 'b-pagiger', name: 'Pagigerstübli', ort: 'Arosa'),
  const BetriebKandidat(betriebId: 'b-loewen-gd', name: 'Gasthof Löwen', ort: 'Grossdietwil'),
  const BetriebKandidat(betriebId: 'b-loewen-mf', name: 'Löwen', ort: 'Maienfeld'),
  const BetriebKandidat(betriebId: 'b-paradies', name: 'Pizzeria Paradies', ort: 'Bad Ragaz'),
  const BetriebKandidat(betriebId: 'b-fasan', name: 'Fasan', ort: 'Seewis Dorf'),
  const BetriebKandidat(betriebId: 'b-oa-lumnezia', name: 'Openair Val Lumnezia', ort: 'Vella'),
  const BetriebKandidat(betriebId: 'b-oa-gampel', name: 'Openair Gampel', ort: 'Steg'),
  const BetriebKandidat(betriebId: 'b-seehof', name: 'Seehof', ort: 'Davos'),
  const BetriebKandidat(betriebId: 'b-chesa', name: 'Chesa', ort: 'Davos Dorf'),
  const BetriebKandidat(betriebId: 'b-oldtimer', name: 'Oldtimer', ort: 'Chur'),
  const BetriebKandidat(betriebId: 'b-twelve', name: 'Twelve', ort: 'Chur'),
  const BetriebKandidat(betriebId: 'b-schuetzenhaus', name: 'Schützenhaus', ort: 'Chur'),
  const BetriebKandidat(betriebId: 'b-schuetzenmatt', name: 'Schützenmatt', ort: 'Inwil'),
  // Betrieb, dessen Name = Ort (darf "Chur - X"-Titel nicht kapern):
  const BetriebKandidat(betriebId: 'b-hotelchur', name: 'Hotel Chur', ort: 'Chur'),
  // Fuzzy-Kollision: Token "crusch" ~ "grusch" (Ort in "Grüsch - Fasan"):
  const BetriebKandidat(
      betriebId: 'b-ustria', name: 'Ustria Crusch Alva', ort: 'Tavanasa'),
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

  // ── Fälle aus dem Live-Test ───────────────────────────────────
  test('Gattungswort-Präfix + Ort: Grossdietwil - Löwen -> Gasthof Löwen', () {
    final m = matcheTitel('Grossdietwil - Löwen', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-loewen-gd');
  });

  test('Gattungswort + zusammengeschriebener Ort: BadRagaz - Paradies', () {
    final m = matcheTitel('BadRagaz - Paradies', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-paradies');
  });

  test('Eindeutiger Name, abweichender Ort im Titel: Pagig - Pagigerstübli', () {
    final m = matcheTitel('Pagig - Pagigerstübli', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-pagiger');
  });

  test('Eindeutiger Name, falscher Ort: Grüsch - Fasan', () {
    final m = matcheTitel('Grüsch - Fasan', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-fasan');
  });

  test('Fehlendes Mittelwort: Openair Lumnezia -> Openair Val Lumnezia', () {
    final m = matcheTitel('Openair Lumnezia', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-oa-lumnezia');
  });

  test('Openair Gampel eindeutig (Ort fehlt)', () {
    final m = matcheTitel('Openair Gampel', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-oa-gampel');
  });

  test('Zwei Betriebe in einem Eintrag: Davos - Seehof und Chesa -> mehrdeutig', () {
    final m = matcheTitel('Davos - Seehof und Chesa', _betriebe);
    expect(m.bucket, MatchBucket.mehrdeutig);
    final ids = m.kandidaten.map((k) => k.betriebId).toSet();
    expect(ids, containsAll(['b-seehof', 'b-chesa']));
  });

  test('Geburtstag -> privat', () {
    expect(matcheTitel('Geburtstag Lorena', _betriebe).bucket, MatchBucket.privat);
    expect(matcheTitel('Mama Geburi', _betriebe).bucket, MatchBucket.privat);
  });

  test('Ferien -> privat', () {
    expect(matcheTitel('Ferien Lorena', _betriebe).bucket, MatchBucket.privat);
  });

  test('Pikett -> pikett', () {
    expect(matcheTitel('Pikett KW 32', _betriebe).bucket, MatchBucket.pikett);
  });

  test('Kurzname ohne Ort, aber nicht eindeutig (Löwen) -> kein Treffer', () {
    // "Löwen" gibt es in Grossdietwil UND Maienfeld -> ohne Ort nicht auflösbar
    final m = matcheTitel('Znacht im Löwen', _betriebe);
    expect(m.bucket, MatchBucket.keinTreffer);
  });

  test('Chur - Oldtimer -> eindeutig', () {
    final m = matcheTitel('Chur - Oldtimer', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-oldtimer');
  });

  test('Chur - Twelve -> eindeutig', () {
    final m = matcheTitel('Chur - Twelve', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-twelve');
  });

  test('Chur - Schützenhaus -> eindeutig (nicht Schützenmatt)', () {
    final m = matcheTitel('Chur - Schützenhaus', _betriebe);
    expect(m.bucket, MatchBucket.eindeutig);
    expect(m.treffer!.betriebId, 'b-schuetzenhaus');
  });
}
