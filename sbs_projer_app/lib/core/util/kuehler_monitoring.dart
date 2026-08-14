// Durchlaufkühler-Monitoring: Sollbereich-Prüfung + Anzeigetext für eine
// Temperatur-Messung (reine Funktionen, testbar). Teil von V2-6.

/// Prüft, ob [temperatur] ausserhalb des Sollbereichs [sollMin]..[sollMax]
/// liegt. Eine nicht gesetzte Grenze ist unbegrenzt (kein Vergleich auf
/// dieser Seite); sind beide Grenzen null, ist der Wert nie ausserhalb.
/// Die Grenzen selbst zählen als innerhalb (Grenzfall <=, nicht <).
bool istAusserhalbSollbereich({
  required double temperatur,
  double? sollMin,
  double? sollMax,
}) {
  if (sollMin != null && temperatur < sollMin) return true;
  if (sollMax != null && temperatur > sollMax) return true;
  return false;
}

/// Kompakter Anzeigetext für eine Messung, z. B. «4.2 °C 14:05» am selben
/// Tag wie [jetzt], sonst «4.2 °C 13.08. 22:05». [jetzt] wird explizit
/// übergeben statt `DateTime.now()` zu lesen, damit die Funktion testbar
/// bleibt.
String messungText(DateTime gemessenAm, double temperatur, {required DateTime jetzt}) {
  final gleicherTag = gemessenAm.year == jetzt.year &&
      gemessenAm.month == jetzt.month &&
      gemessenAm.day == jetzt.day;
  final uhrzeit =
      '${_zweistellig(gemessenAm.hour)}:${_zweistellig(gemessenAm.minute)}';
  final zeit = gleicherTag
      ? uhrzeit
      : '${_zweistellig(gemessenAm.day)}.${_zweistellig(gemessenAm.month)}. $uhrzeit';
  return '${temperatur.toStringAsFixed(1)} °C $zeit';
}

String _zweistellig(int n) => n.toString().padLeft(2, '0');
