/// Aggregierter Inbetriebnahme-Fortschritt eines Stands (über seine Anlagen).
typedef Fortschritt = ({int inBetrieb, int total, bool komplett, String label});

/// [anlagen] = Liste aus (anzahl, inBetrieb). Zählt Anzahl-gewichtet.
Fortschritt inbetriebnahmeFortschritt(
    List<({int anzahl, bool inBetrieb})> anlagen) {
  var total = 0;
  var inBetrieb = 0;
  for (final a in anlagen) {
    total += a.anzahl;
    if (a.inBetrieb) inBetrieb += a.anzahl;
  }
  final komplett = total > 0 && inBetrieb == total;
  final label = total == 0
      ? '—'
      : komplett
          ? '✓ komplett'
          : '$inBetrieb/$total in Betrieb';
  return (inBetrieb: inBetrieb, total: total, komplett: komplett, label: label);
}
