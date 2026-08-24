/// Abrechnungseinheit einer Montage: Viertelstunden (Entscheid Daniel,
/// 24.08.2026).
const int _viertelstundeMinuten = 15;

/// Rundet eine gemessene Dauer auf die nächste **Viertelstunde auf** — der
/// Vorschlag für das Abrechnungsfeld `dauerStunden`.
///
/// **Wozu:** «Arbeit beginnen»/«Beenden» misst die Zeit längst, der Wert
/// wurde aber weiterhin abends aus dem Gedächtnis eingetippt. Der
/// «übernehmen»-Knopf im Montage-Formular schrieb bis v0.91.x die *exakte*
/// Dauer ins Feld (1h20 → 1.33) — ein Wert, den man auf einer Rechnung so
/// nicht stehen lassen will und deshalb doch wieder von Hand glättete.
///
/// **Was diese Funktion NICHT tut:** `dauerStunden` automatisch setzen. Das
/// Feld ist das Abrechnungsfeld und enthält bewusst auch Anfahrtsanteile,
/// die in der reinen Arbeitszeit gar nicht stecken (Regel Daniel,
/// 31.07.2026). Der Wert wird nur *vorgeschlagen* und muss bestätigt werden.
///
/// `null` — und damit kein Vorschlag — bei fehlender, leerer oder negativer
/// Messung: Lieber nichts vorschlagen als eine falsche Zahl in ein Geldfeld.
double? aufViertelstunde(double? stunden) {
  if (stunden == null || stunden <= 0) return null;

  // Erst auf ganze Minuten runden, dann aufrunden: Rechnet man direkt mit
  // Stunden-Bruchteilen, kippt `ceil()` an Fliesskomma-Resten in die falsche
  // Stufe — 0.7500000000000001 / 0.25 ergibt 3.0000000000000004 und damit
  // 1.00 h statt 0.75 h. Uhrzeiten sind ohnehin minutengenau.
  var minuten = (stunden * 60).round();
  // Eine Messung unter 30 Sekunden gäbe sonst 0 — als Einsatz zählt sie
  // trotzdem mit dem Mindestansatz.
  if (minuten <= 0) minuten = 1;

  final viertel = (minuten / _viertelstundeMinuten).ceil();
  return viertel * _viertelstundeMinuten / 60;
}
