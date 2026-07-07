import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Ein Ferien-Slot (Start/Ende koennen einzeln null sein).
typedef FerienSlot = ({DateTime? start, DateTime? ende});

/// Alle 5 Ferien-Slots eines Betriebs in fester Reihenfolge.
/// Prueft NICHT [BetriebLocal.keineBetriebsferien] — das bleibt Sache der Aufrufer.
List<FerienSlot> ferienSlots(BetriebLocal b) => [
      (start: b.ferienStart, ende: b.ferienEnde),
      (start: b.ferien2Start, ende: b.ferien2Ende),
      (start: b.ferien3Start, ende: b.ferien3Ende),
      (start: b.ferien4Start, ende: b.ferien4Ende),
      (start: b.ferien5Start, ende: b.ferien5Ende),
    ];

/// Alle belegten Ferien-Startdaten.
List<DateTime> ferienStarts(BetriebLocal b) =>
    [for (final s in ferienSlots(b)) if (s.start != null) s.start!];

/// Alle belegten Ferien-Enddaten.
List<DateTime> ferienEnden(BetriebLocal b) =>
    [for (final s in ferienSlots(b)) if (s.ende != null) s.ende!];

/// True wenn [datum] in einer vollstaendig erfassten Ferienperiode liegt
/// (Randtage inklusive).
bool istInFerien(BetriebLocal b, DateTime datum) {
  for (final s in ferienSlots(b)) {
    if (s.start == null || s.ende == null) continue;
    if (!datum.isBefore(s.start!) && !datum.isAfter(s.ende!)) return true;
  }
  return false;
}
