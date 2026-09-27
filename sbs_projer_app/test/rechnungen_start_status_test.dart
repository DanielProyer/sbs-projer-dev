import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/rechnungen_list_screen.dart';

/// `/rechnungen?status=` setzt den Start-Filter der Rechnungsliste
/// (Geld-Block der Betriebsseite, Review Runde 5). Seit Migration 211
/// (Entscheid 4, 27.09.2026): Vorgabe «Unbezahlt», der alte Filter «offen»
/// heisst «nicht zugestellt».
void main() {
  test('bekannter Status wird übernommen', () {
    expect(rechnungStartStatus('nicht_zugestellt'), 'nicht_zugestellt');
    expect(rechnungStartStatus('mahnung_1'), 'mahnung_1');
    expect(rechnungStartStatus('unbezahlt'), 'unbezahlt');
    expect(rechnungStartStatus('alle'), 'alle');
    expect(rechnungStartStatus('mahnfaellig'), 'mahnfaellig');
  });

  test('der alte Wert «offen» wird «nicht zugestellt»', () {
    expect(rechnungStartStatus('offen'), 'nicht_zugestellt');
  });

  test('fehlend oder unbekannt -> Vorgabe «unbezahlt»', () {
    expect(kRechnungStatusVorgabe, 'unbezahlt');
    expect(rechnungStartStatus(null), 'unbezahlt');
    expect(rechnungStartStatus(''), 'unbezahlt');
    expect(rechnungStartStatus('entwurf'), 'unbezahlt');
  });

  test('mit Suchbegriff ohne Status -> alle (bezahlter Treffer bleibt sichtbar)',
      () {
    expect(rechnungStartStatus(null, mitSuche: true), 'alle');
    expect(rechnungStartStatus('entwurf', mitSuche: true), 'alle');
    // Ein ausdrücklicher Status gilt auch mit Suche (Geld-Block der Akte).
    expect(rechnungStartStatus('unbezahlt', mitSuche: true), 'unbezahlt');
  });
}
