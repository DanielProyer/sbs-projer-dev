/// Eine Suchregel für alle Betriebs-Auswahlfelder (A9).
///
/// WARUM: Die Betriebssuche war siebenmal gebaut, mit drei verschiedenen
/// Regeln (App-Analyse 08.09.2026, Befund 6.5). Störung und Reinigung suchten
/// in Name, Ort und Betriebsnummer; Kontakt und Montage in Name und Ort;
/// Eigenauftrag und Eröffnungsreinigung nur im Namen — dort lieferte «Chur»
/// nichts, obwohl es woanders funktionierte. Wer das einmal erlebt, glaubt
/// der Suche nicht mehr und tippt überall den vollen Namen.
///
/// Die Oberfläche bleibt, wie sie ist: Alle Formulare verwenden ohnehin
/// dasselbe `Autocomplete`. Vereinheitlicht wird nur, wonach gesucht wird.
library;

/// Passt ein Betrieb auf die Sucheingabe [suche]?
///
/// Gesucht wird in Name, Ort und Betriebsnummer, Gross-/Kleinschreibung
/// spielt keine Rolle. Eine leere Eingabe passt immer — die Aufrufer zeigen
/// dann ihre (ggf. gekürzte) Gesamtliste.
bool betriebPasst({
  required String name,
  String? ort,
  String? betriebNr,
  required String suche,
}) {
  final q = suche.trim().toLowerCase();
  if (q.isEmpty) return true;
  return name.toLowerCase().contains(q) ||
      (ort?.toLowerCase().contains(q) ?? false) ||
      (betriebNr?.toLowerCase().contains(q) ?? false);
}
