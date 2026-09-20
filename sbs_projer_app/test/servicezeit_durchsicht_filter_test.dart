import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Die Servicezeiten-Durchsicht zeigt nur eigene Reinigungskunden.
///
/// WARUM: Eine Servicezeit beantwortet «wann darf ich zum Reinigen kommen».
/// Bei einem Betrieb, den Daniel nicht reinigt, gibt es darauf keine Antwort.
/// Am 20.09.2026 waren alle 229 eigenen Kunden durchgesehen und fertig — die
/// Liste zeigte trotzdem noch 71 Einträge: Feste (Albani Fest, Churerfest),
/// Heigenie-/David-Anlagen und Karteileichen, allesamt ohne aktive Anlage und
/// ohne je eine Reinigung. Neun davon hatte Daniel schon durchgeklickt, bevor
/// es auffiel.
///
/// Als Quelltext-Wächter, weil die Abfrage gegen Supabase läuft und im
/// VM-Test nicht ausführbar ist — dasselbe Muster wie
/// `pagination_stabil_test.dart`.
void main() {
  final quelle = File(
    'lib/data/repositories/servicezeit_durchsicht_repository.dart',
  ).readAsStringSync();

  test('die Kandidaten-Abfrage filtert auf ist_mein_kunde', () {
    expect(
      quelle.contains("from('betriebe')"),
      isTrue,
      reason: 'Scanner kaputt — die Betriebe-Abfrage wurde umbenannt?',
    );
    expect(
      quelle.contains(".eq('ist_mein_kunde', true)"),
      isTrue,
      reason:
          'Ohne diesen Filter landen Feste, Heigenie-Anlagen und '
          'Karteileichen in der Durchsicht (Befund Daniel 20.09.2026).',
    );
  });

  test('die bisherigen Filter stehen weiterhin', () {
    expect(quelle.contains(".eq('status', 'aktiv')"), isTrue);
    expect(
      quelle.contains("isFilter('servicezeit_geprueft_am', null)"),
      isTrue,
      reason: 'sonst kommt jeder Betrieb in jeder Runde wieder',
    );
  });
}
