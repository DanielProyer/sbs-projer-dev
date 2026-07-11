import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_reinigung.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _b() => BetriebLocal()
  ..userId = 't'
  ..name = 'Calanda'
  ..ort = 'Chur';

void main() {
  test('kein Saisonbetrieb, keine Ferien → leer', () {
    expect(betriebReinigungen(_b()), isEmpty);
  });

  test('Sommer-Saison → Eröffnung=Start, Endreinigung=Ende', () {
    final b = _b()
      ..istSaisonbetrieb = true
      ..sommerSaisonAktiv = true
      ..sommerStartDatum = DateTime(2026, 5, 1)
      ..sommerEndeDatum = DateTime(2026, 9, 30);
    final r = betriebReinigungen(b);
    final e = r.firstWhere((x) => x.slotKey == 'sommer_eroeffnung');
    final end = r.firstWhere((x) => x.slotKey == 'sommer_endreinigung');
    expect(e.art, 'eroeffnung');
    expect(e.datum, DateTime(2026, 5, 1));
    expect(end.art, 'endreinigung');
    expect(end.datum, DateTime(2026, 9, 30));
    expect(e.label, 'Calanda, Chur');
  });

  test('Ferien-Slot → Endreinigung=Start-1, Eröffnung=Ende+1', () {
    final b = _b()
      ..ferienStart = DateTime(2026, 7, 10)
      ..ferienEnde = DateTime(2026, 7, 20);
    final r = betriebReinigungen(b);
    final end = r.firstWhere((x) => x.slotKey == 'ferien1_endreinigung');
    final auf = r.firstWhere((x) => x.slotKey == 'ferien1_eroeffnung');
    expect(end.datum, DateTime(2026, 7, 9));
    expect(auf.datum, DateTime(2026, 7, 21));
  });

  test('keineBetriebsferien → Ferien ignoriert', () {
    final b = _b()
      ..keineBetriebsferien = true
      ..ferienStart = DateTime(2026, 7, 10)
      ..ferienEnde = DateTime(2026, 7, 20);
    expect(betriebReinigungen(b), isEmpty);
  });

  test('nur belegte Ferien-Slots', () {
    final b = _b()
      ..ferien2Start = DateTime(2026, 8, 1)
      ..ferien2Ende = DateTime(2026, 8, 10);
    final keys = betriebReinigungen(b).map((x) => x.slotKey).toSet();
    expect(keys, {'ferien2_endreinigung', 'ferien2_eroeffnung'});
  });

  test('sortiert nach Datum', () {
    final b = _b()
      ..istSaisonbetrieb = true
      ..sommerSaisonAktiv = true
      ..sommerStartDatum = DateTime(2026, 5, 1)
      ..sommerEndeDatum = DateTime(2026, 9, 30)
      ..ferienStart = DateTime(2026, 7, 10)
      ..ferienEnde = DateTime(2026, 7, 20);
    final ds = betriebReinigungen(b).map((x) => x.datum).toList();
    final sorted = [...ds]..sort();
    expect(ds, sorted);
  });

  test('label ohne Ort → nur Name', () {
    final b = _b()
      ..ort = null
      ..istSaisonbetrieb = true
      ..sommerSaisonAktiv = true
      ..sommerStartDatum = DateTime(2026, 5, 1)
      ..sommerEndeDatum = DateTime(2026, 9, 30);
    expect(betriebReinigungen(b).first.label, 'Calanda');
  });
}
