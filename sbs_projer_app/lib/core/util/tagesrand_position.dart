/// Welcher Standort wird an einem Tagesrand (Arbeitsbeginn / Feierabend)
/// gestempelt? Reine Funktion — testbar, ohne IO.
///
/// Hintergrund (Daniel 11.08.2026): Der Feierabend wird oft am PC erfasst, und
/// der hat keinen Standortdienst. Bis dahin blockierte die GPS-Abfrage das
/// Speichern komplett — Arbeitszeit und km-Stand gingen wortlos verloren.
/// Seither gilt: Erst speichern, dann Standort; und fehlt GPS, greift beim
/// **Feierabend** der hinterlegte Startort («zuhause ist der Standort sowieso
/// definiert»).
///
/// Beim **Arbeitsbeginn** gibt es diesen Rückfall bewusst NICHT: Daniel startet
/// nicht immer zuhause, sondern oft anderswo (Chur) — ein erfundener Startort
/// würde Anfahrt und Fahrzeiten der Zeitachse verfälschen.
library;

enum PositionsQuelle {
  /// Frisch gemessen.
  gps,

  /// Aus den Geschäftseinstellungen (Startort / zuhause).
  startort,

  /// Nichts verfügbar.
  keine,
}

typedef Koordinate = ({double lat, double lng});

typedef Standortwahl = ({Koordinate? position, PositionsQuelle quelle});

/// GPS hat Vorrang; [startort] greift nur, wenn er erlaubt ist
/// ([startortErlaubt], beim Feierabend true) und GPS nichts geliefert hat.
Standortwahl tagesrandPosition({
  required Koordinate? gps,
  required Koordinate? startort,
  required bool startortErlaubt,
}) {
  if (gps != null) return (position: gps, quelle: PositionsQuelle.gps);
  if (startortErlaubt && startort != null) {
    return (position: startort, quelle: PositionsQuelle.startort);
  }
  return (position: null, quelle: PositionsQuelle.keine);
}
