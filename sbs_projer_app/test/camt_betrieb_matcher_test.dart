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
}
