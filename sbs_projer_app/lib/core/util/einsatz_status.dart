/// Status eines Einsatzes (Montage oder Störung) nach dem Speichern.
/// Reine Funktion — testbar, ohne IO.
///
/// Warum (Fall Sartons, Daniel 11.08.2026): Der «Arbeit beginnen»-Knopf setzt
/// den Status sofort auf `in_bearbeitung`. Beim nächsten Öffnen las das
/// Formular daraus «Erst geplant = an» zurück und schrieb beim Speichern
/// wieder `in_bearbeitung` — der Einsatz liess sich über den normalen Weg
/// **nie** abschliessen und stand endlos im Tourenplan. Einziger Ausweg war
/// der Schalter «Erst geplant», dessen Beschriftung nichts mit «fertig» zu
/// tun hat.
///
/// Die Regel jetzt: **Ist die Arbeit zu Ende erfasst, ist der Einsatz
/// erledigt.** Ein erfasstes Arbeitsende ist die eindeutige Aussage «fertig»
/// — deutlicher als jeder Schalter.
library;

/// [offenWert]/[erledigtWert] unterscheiden die beiden Tabellen:
/// Montage `geplant`/`abgeschlossen`, Störung `offen`/`behoben`.
String einsatzStatusNachSpeichern({
  required bool geplant,
  required String? arbeitVon,
  required String? arbeitBis,
  required String offenWert,
  required String erledigtWert,
}) {
  if (!geplant) return erledigtWert;

  final von = (arbeitVon ?? '').trim();
  final bis = (arbeitBis ?? '').trim();

  // Arbeitsende erfasst = fertig, unabhängig vom «Erst geplant»-Schalter.
  if (bis.isNotEmpty) return erledigtWert;
  if (von.isNotEmpty) return 'in_bearbeitung';
  return offenWert;
}
