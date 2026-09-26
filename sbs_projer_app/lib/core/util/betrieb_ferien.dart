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
/// Prueft NICHT [BetriebLocal.keineBetriebsferien] — dafuer gibt es
/// [wirksameFerienSlots], ueber das alle auswertenden Leser gehen.
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

/// Die Ferien-Slots, die tatsaechlich gelten: leer, sobald der Schalter
/// [BetriebLocal.keineBetriebsferien] gesetzt ist.
///
/// WARUM: Seit v0.141.0 loescht der Schalter die Perioden nicht mehr, er
/// blendet sie nur aus (Analyse R7). Jeder Leser, der Ferien auswertet
/// (Tourenplan, Schliessungs-Gruende, Kalender, Raster), geht deshalb ueber
/// diese Funktion — sonst plante der Tourenplan um ausgeblendete Ferien herum.
/// [ferienSlots] bleibt fuer die seltenen Stellen, die den Rohbestand brauchen.
List<FerienSlot> wirksameFerienSlots(BetriebLocal b) =>
    b.keineBetriebsferien ? const [] : ferienSlots(b);

/// Alle belegten Ferien-Startdaten (leer bei keineBetriebsferien).
List<DateTime> ferienStarts(BetriebLocal b) => [
  for (final s in wirksameFerienSlots(b))
    if (s.start != null) s.start!,
];

/// Alle belegten Ferien-Enddaten (leer bei keineBetriebsferien).
List<DateTime> ferienEnden(BetriebLocal b) => [
  for (final s in wirksameFerienSlots(b))
    if (s.ende != null) s.ende!,
];

/// True wenn [datum] in einer vollstaendig erfassten Ferienperiode liegt
/// (Randtage inklusive). Immer false bei keineBetriebsferien.
bool istInFerien(BetriebLocal b, DateTime datum) {
  for (final s in wirksameFerienSlots(b)) {
    if (s.start == null || s.ende == null) continue;
    if (!datum.isBefore(s.start!) && !datum.isAfter(s.ende!)) return true;
  }
  return false;
}
