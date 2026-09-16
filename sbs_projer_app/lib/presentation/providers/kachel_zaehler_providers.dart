// ─── Zähler für die Startseiten-Kacheln (A2) ───
//
// Ursprünglich (A2) lieferte diese Datei Zähler für offene Arbeit statt
// Jahrestotalen (Betriebe 443, Reinigungen 933, ...) für alle zehn Kacheln
// der Startseite. Seit v0.107.0 (B1) führt die Navigationsleiste zu sieben
// dieser Ziele direkt — ihre Zähler-Provider sind mit den Kacheln entfernt.
// `kommenderSonntag` bleibt: reine Datumslogik, unabhängig von den Kacheln.

/// Der Sonntag, der die Woche von [tag] abschliesst. Fällt [tag] selbst auf
/// einen Sonntag, ist es dieser Tag — nicht der Sonntag darauf.
DateTime kommenderSonntag(DateTime tag) {
  final ohneZeit = DateTime(tag.year, tag.month, tag.day);
  final bisSonntag = DateTime.sunday - ohneZeit.weekday; // Mo=1 … So=7
  return ohneZeit.add(Duration(days: bisSonntag));
}

// ─── Eröffnungsreinigungen: bewusst ausgelassen ───
//
// Der Plan sah einen Zähler „anstehende Eröffnungen" vor, analog zu den
// beiden Providern oben (Status != 'abgeschlossen'). Geprüft am Code
// (13.09.2026): `EroeffnungsreinigungLocal` (lib/data/local/
// eroeffnungsreinigung_local.dart) hat gar kein Status-Feld — im Gegensatz zu
// Störung/Montage/Eigenauftrag ist das kein Auftrag mit Lebenszyklus, sondern
// ein nachträglich erfasster Beleg (Formular „Eröffnungsreinigung erfassen",
// Datum defaultet auf `DateTime.now()`, dazu nur `preis`/`abgerechnet` für die
// Abrechnung — kein „geplant"-Zustand). Ein „anstehend"-Zähler auf dieser
// Datenquelle wäre geraten, nicht gemessen.
//
// Das fachliche Gegenstück existiert bereits: `getFaelligkeit()` in
// tour_providers.dart liefert `FaelligkeitsStatus.eroeffnungFaellig` für
// Anlagen, deren saisonale Wiedereröffnung ansteht.
//
// Entschieden am 13.09.2026: Die Eröffnungen-Kachel bekommt KEINEN Zähler.
// Ein zweiter Zähler zählte dieselbe anstehende Arbeit ein zweites Mal — die
// Kachel behält Symbol und Namen, wie Betriebe, Kontakte und Spesen auch.
//
// Seit v0.107.0 (B1): die Eröffnungen-Kachel selbst ist von der Startseite
// verschwunden (führt jetzt über die Navigationsleiste zu Einsätze), dieser
// Entscheid bleibt als Begründung stehen, falls sie einmal zurückkommt.
