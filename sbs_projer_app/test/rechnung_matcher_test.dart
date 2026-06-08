import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/rechnung_matcher.dart';

Rechnung _rg(String id, double brutto) => Rechnung(
  id: id, userId: 'u', rechnungstyp: 'kundenrechnung', betriebId: 'b1',
  rechnungsdatum: DateTime(2026, 7, 1), faelligkeitsdatum: DateTime(2026, 7, 31),
  betragBrutto: brutto, zahlungsstatus: 'offen');

void main() {
  test('Genau 1 Rechnung, Betrag exakt → eindeutig', () {
    final r = RechnungMatcher.match(zahlbetrag: 130.30, offeneRechnungen: [_rg('a', 130.30), _rg('b', 99.00)]);
    expect(r.eindeutig, true);
    expect(r.rechnungen.map((e) => e.id), ['a']);
  });
  test('Summe zweier Rechnungen = Betrag, eindeutige Kombination → Sammel', () {
    final r = RechnungMatcher.match(zahlbetrag: 229.30, offeneRechnungen: [_rg('a', 130.30), _rg('b', 99.00)]);
    expect(r.eindeutig, true);
    expect(r.rechnungen.map((e) => e.id).toSet(), {'a', 'b'});
  });
  test('Mehrdeutige Kombination → nicht eindeutig', () {
    final r = RechnungMatcher.match(zahlbetrag: 100.00,
        offeneRechnungen: [_rg('a', 100.00), _rg('b', 100.00)]);
    expect(r.eindeutig, false);
  });
  test('Kein passender Betrag → nicht eindeutig', () {
    final r = RechnungMatcher.match(zahlbetrag: 55.00, offeneRechnungen: [_rg('a', 130.30)]);
    expect(r.eindeutig, false);
  });
}
