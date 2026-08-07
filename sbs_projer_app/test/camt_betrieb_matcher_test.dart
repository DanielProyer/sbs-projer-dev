import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/camt_betrieb_matcher.dart';

void main() {
  final betriebe = [
    {'id': 'b1', 'name': 'Hotel Alpina', 'aliase': 'hotel alpina ag\nalpina gastro'},
    {'id': 'b2', 'name': 'Gastro Latina', 'aliase': 'latina gmbh'},
    {'id': 'b3', 'name': 'Ohne Alias', 'aliase': ''},
  ];

  test('eindeutiger Alias-Treffer (normalisiert)', () {
    final m = CamtBetriebMatcher.matchByAlias('  Hotel  Alpina AG ', betriebe);
    expect(m?['id'], 'b1');
  });

  test('zweiter Alias desselben Betriebs trifft', () {
    expect(CamtBetriebMatcher.matchByAlias('Alpina Gastro', betriebe)?['id'], 'b1');
  });

  test('kein Treffer → null', () {
    expect(CamtBetriebMatcher.matchByAlias('Unbekannt AG', betriebe), isNull);
  });

  test('mehrdeutig (zwei Betriebe, gleicher Alias) → null', () {
    final ambig = [
      {'id': 'b1', 'name': 'A', 'aliase': 'doppelt ag'},
      {'id': 'b2', 'name': 'B', 'aliase': 'doppelt ag'},
    ];
    expect(CamtBetriebMatcher.matchByAlias('Doppelt AG', ambig), isNull);
  });

  test('leerer/fehlender Name → null', () {
    expect(CamtBetriebMatcher.matchByAlias(null, betriebe), isNull);
    expect(CamtBetriebMatcher.matchByAlias('   ', betriebe), isNull);
  });

  test('matchExakt: exakter, eindeutiger Name', () {
    expect(CamtBetriebMatcher.matchExakt(' hotel alpina ', betriebe)?['id'], 'b1');
    expect(CamtBetriebMatcher.matchExakt('Hotel Alpina AG', betriebe), isNull); // nicht exakt
  });

  final mitNr = [
    {'id': 'b1', 'name': 'A', 'nr': '', 'we_nummer': '', 'ag_nummer': '', 'heineken_nr': '0151'},
    {'id': 'b2', 'name': 'B', 'nr': '', 'we_nummer': '77', 'ag_nummer': '', 'heineken_nr': ''},
    {'id': 'b3', 'name': 'Armando', 'nr': '21', 'we_nummer': '', 'ag_nummer': '', 'heineken_nr': '0088'},
  ];

  test('matchByNummer: leading-zero-tolerant über heineken_nr/we/ag', () {
    expect(CamtBetriebMatcher.matchByNummer('151', mitNr)?['id'], 'b1');
    expect(CamtBetriebMatcher.matchByNummer('0151', mitNr)?['id'], 'b1');
    expect(CamtBetriebMatcher.matchByNummer('77', mitNr)?['id'], 'b2');
    expect(CamtBetriebMatcher.matchByNummer('88', mitNr)?['id'], 'b3'); // heineken_nr
    expect(CamtBetriebMatcher.matchByNummer('0088', mitNr)?['id'], 'b3');
    expect(CamtBetriebMatcher.matchByNummer('999', mitNr), isNull);
    expect(CamtBetriebMatcher.matchByNummer(null, mitNr), isNull);
  });

  test('matchByNummer: heineken_nr schlägt Hausnummer-/WE-Kollision (Fix 07.08.)', () {
    // Betrieb b9 hat heineken_nr 0089; ein ANDERER Betrieb hat Hausnummer 89
    // und ein dritter die WE-Nummer 89. Früher → mehrdeutig → null; jetzt
    // gewinnt die eigene Betriebsnummer.
    final kollision = [
      {'id': 'b9', 'name': 'Bolgen Plaza', 'nr': '', 'we_nummer': '', 'ag_nummer': '', 'heineken_nr': '0089'},
      {'id': 'bx', 'name': 'Hausnr-Betrieb', 'nr': '89', 'we_nummer': '', 'ag_nummer': '', 'heineken_nr': '0500'},
      {'id': 'by', 'name': 'WE-Betrieb', 'nr': '', 'we_nummer': '89', 'ag_nummer': '', 'heineken_nr': '0501'},
    ];
    expect(CamtBetriebMatcher.matchByNummer('0089', kollision)?['id'], 'b9');
    expect(CamtBetriebMatcher.matchByNummer('89', kollision)?['id'], 'b9');
  });

  test('matchByNummer: Hausnummer allein matcht NICHT mehr', () {
    final nurHausnr = [
      {'id': 'b1', 'name': 'A', 'nr': '42', 'we_nummer': '', 'ag_nummer': '', 'heineken_nr': '0700'},
    ];
    expect(CamtBetriebMatcher.matchByNummer('42', nurHausnr), isNull);
  });

  test('matchByNummer: mehrdeutig innerhalb heineken_nr → null', () {
    final ambig = [
      {'id': 'b1', 'name': 'A', 'heineken_nr': '5'},
      {'id': 'b2', 'name': 'B', 'heineken_nr': '05'},
    ];
    expect(CamtBetriebMatcher.matchByNummer('5', ambig), isNull);
  });
}
