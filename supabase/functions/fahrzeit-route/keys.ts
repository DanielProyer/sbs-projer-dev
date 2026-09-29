// Schluessel der Routen-Enden im Cache `routen_punkte` (Migration 213).
//
// Ein Ende ist entweder ein Betrieb ('b:<uuid>') oder ein Punkt
// ('p:<lat>,<lng>' mit vier Nachkommastellen, ~11 m). Die App rechnet
// dieselben Schluessel (`lib/core/util/routen_punkt_key.dart`), um die
// gecachten Strecken ohne erneute Anfrage zu finden -- beide Fassungen
// muessen Zeichen fuer Zeichen gleich bleiben.
//
// Rundung: `toFixed(4)` (JS) bzw. `toStringAsFixed(4)` (Dart). Im Web ruft
// Dart dafuer dasselbe `toFixed` auf; die Dart-VM (Tests) rechnet gleich.
// Kleine negative Werte ergeben in BEIDEN "-0.0000" (geprueft 29.09.2026,
// `keys_test.ts` und `test/routen_punkt_key_test.dart`) -- deshalb ohne
// eigene Vorzeichen-Normalisierung. In Graubuenden kommt das ohnehin nie vor.

/** Schluessel eines Punkts: `p:<lat>,<lng>`, je vier Nachkommastellen. */
export function punktKey(lat: number, lng: number): string {
  return `p:${lat.toFixed(4)},${lng.toFixed(4)}`;
}

/** Schluessel eines Betriebs: `b:<betrieb uuid>`. */
export function betriebKey(id: string): string {
  return `b:${id}`;
}
