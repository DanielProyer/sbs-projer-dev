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
// Kleine negative Werte (z.B. -0.00004) ergeben in BEIDEN "-0.0000"
// (geprueft 29.09.2026) -- gleich, also unkritisch.
// Exakt -0 dagegen NICHT: JS `(-0).toFixed(4)` ist "0.0000", Dart im Web
// haengt bei -0.0 ein Minus an ("-0.0000"). Darum normalisieren BEIDE
// Seiten -0 auf 0, bevor gerundet wird. In Graubuenden kommt das ohnehin
// nie vor; es geht nur darum, dass die Schluessel nie auseinanderlaufen.

/** -0 -> 0 (siehe oben); jede andere Zahl unveraendert. */
function ohneMinusNull(v: number): number {
  return Object.is(v, -0) ? 0 : v;
}

/** Schluessel eines Punkts: `p:<lat>,<lng>`, je vier Nachkommastellen. */
export function punktKey(lat: number, lng: number): string {
  const breite = ohneMinusNull(lat).toFixed(4);
  const laenge = ohneMinusNull(lng).toFixed(4);
  return `p:${breite},${laenge}`;
}

/** Schluessel eines Betriebs: `b:<betrieb uuid>`. */
export function betriebKey(id: string): string {
  return `b:${id}`;
}
