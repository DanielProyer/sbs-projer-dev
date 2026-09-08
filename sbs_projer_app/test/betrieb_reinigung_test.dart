import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_reinigung.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _b() => BetriebLocal()
  ..userId = 't'
  ..name = 'Calanda'
  ..ort = 'Chur';

/// Fester Bezugstag für alle Struktur-Tests: sonst fielen die Termine
/// irgendwann durch den Vergangenheits-Filter und die Tests würden mit der
/// Zeit von selbst rot — genau das war am 08.09.2026 der Fall.
final _heute = DateTime(2026, 1, 1);

void main() {
  test('kein Saisonbetrieb, keine Ferien → leer', () {
    expect(betriebReinigungen(_b(), heute: _heute), isEmpty);
  });

  group('Vergangene Termine werden nicht vorgeschlagen (Befund 08.09.2026)', () {
    // Acla Grischuna schlug beim Speichern die Wintersaison 13.12.2025–
    // 29.03.2026 für den Google-Kalender vor — beide Termine lagen Monate
    // zurück. Die Saison-Daten sind konkrete Daten je Saison, kein
    // wiederkehrendes Muster; ein abgelaufener Termin gehört weggelassen,
    // nicht ins nächste Jahr geschoben.
    test('abgelaufene Wintersaison ergibt keinen Vorschlag', () {
      final b = _b()
        ..istSaisonbetrieb = true
        ..winterSaisonAktiv = true
        ..winterStartDatum = DateTime(2025, 12, 13)
        ..winterEndeDatum = DateTime(2026, 3, 29);
      expect(betriebReinigungen(b, heute: DateTime(2026, 9, 8)), isEmpty);
    });

    test('nur der noch offene Teil der Saison bleibt', () {
      final b = _b()
        ..istSaisonbetrieb = true
        ..winterSaisonAktiv = true
        ..winterStartDatum = DateTime(2026, 12, 11)
        ..winterEndeDatum = DateTime(2027, 3, 28);
      final r = betriebReinigungen(b, heute: DateTime(2027, 1, 15));
      expect(r.map((x) => x.slotKey), ['winter_endreinigung']);
    });

    test('Termin heute zählt noch als offen', () {
      final b = _b()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 9, 8);
      // Uhrzeit am Stichtag darf nichts ändern.
      final r = betriebReinigungen(b, heute: DateTime(2026, 9, 8, 17, 30));
      expect(r.map((x) => x.slotKey), ['sommer_eroeffnung']);
    });

    test('abgelaufene Ferien ergeben keinen Vorschlag', () {
      final b = _b()
        ..ferienStart = DateTime(2026, 7, 10)
        ..ferienEnde = DateTime(2026, 7, 20);
      expect(betriebReinigungen(b, heute: DateTime(2026, 9, 8)), isEmpty);
    });
  });

  test('Sommer-Saison → Eröffnung=Start, Endreinigung=Ende', () {
    final b = _b()
      ..istSaisonbetrieb = true
      ..sommerSaisonAktiv = true
      ..sommerStartDatum = DateTime(2026, 5, 1)
      ..sommerEndeDatum = DateTime(2026, 9, 30);
    final r = betriebReinigungen(b, heute: _heute);
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
    final r = betriebReinigungen(b, heute: _heute);
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
    expect(betriebReinigungen(b, heute: _heute), isEmpty);
  });

  test('nur belegte Ferien-Slots', () {
    final b = _b()
      ..ferien2Start = DateTime(2026, 8, 1)
      ..ferien2Ende = DateTime(2026, 8, 10);
    final keys = betriebReinigungen(b, heute: _heute).map((x) => x.slotKey).toSet();
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
    final ds = betriebReinigungen(b, heute: _heute).map((x) => x.datum).toList();
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
    expect(betriebReinigungen(b, heute: _heute).first.label, 'Calanda');
  });
}
