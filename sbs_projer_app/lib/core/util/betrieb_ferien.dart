import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Ein Ferien-Slot (Start/Ende koennen einzeln null sein).
typedef FerienSlot = ({DateTime? start, DateTime? ende});

/// Alle Ferien-Slots eines Betriebs.
///
/// Liest aus [BetriebLocal.ferienPerioden] (Tabelle `betrieb_ferien`),
/// sobald diese geladen sind. `null` heisst «noch nicht geladen» — dann
/// faellt die Funktion auf die alten 5 festen Spaltenpaare zurueck.
///
/// Der Unterschied zwischen `null` und einer LEEREN Liste ist wesentlich:
/// - `null` = unbekannt → alte Spalten lesen. Das macht die Umstellung
///   gefahrlos: Wo die Perioden noch nicht da sind, verhaelt sich die App
///   wie bisher, statt Ferien stillschweigend zu "vergessen" — vergessene
///   Ferien waeren der schlimmste Fehlerfall, dann faehrt Daniel zu einem
///   geschlossenen Betrieb.
/// - leere Liste = geladen, dieser Betrieb hat keine Ferien → die alten
///   Spalten werden NICHT gelesen. Sonst kaeme eine geloeschte Periode
///   ueber den Altbestand zurueck und liesse sich nie entfernen.
///
/// Prueft NICHT [BetriebLocal.keineBetriebsferien] — das bleibt Sache der Aufrufer.
List<FerienSlot> ferienSlots(BetriebLocal b) {
  final perioden = b.ferienPerioden;
  if (perioden != null) {
    return [for (final p in perioden) (start: p.von, ende: p.bis)];
  }
  return [
    (start: b.ferienStart, ende: b.ferienEnde),
    (start: b.ferien2Start, ende: b.ferien2Ende),
    (start: b.ferien3Start, ende: b.ferien3Ende),
    (start: b.ferien4Start, ende: b.ferien4Ende),
    (start: b.ferien5Start, ende: b.ferien5Ende),
  ];
}

/// Alle belegten Ferien-Startdaten.
List<DateTime> ferienStarts(BetriebLocal b) => [
  for (final s in ferienSlots(b))
    if (s.start != null) s.start!,
];

/// Alle belegten Ferien-Enddaten.
List<DateTime> ferienEnden(BetriebLocal b) => [
  for (final s in ferienSlots(b))
    if (s.ende != null) s.ende!,
];

/// True wenn [datum] in einer vollstaendig erfassten Ferienperiode liegt
/// (Randtage inklusive).
bool istInFerien(BetriebLocal b, DateTime datum) {
  for (final s in ferienSlots(b)) {
    if (s.start == null || s.ende == null) continue;
    if (!datum.isBefore(s.start!) && !datum.isAfter(s.ende!)) return true;
  }
  return false;
}
