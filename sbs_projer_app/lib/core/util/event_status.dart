/// Status eines Event-Jahres, abgeleitet aus dem Termin (kein DB-Feld).
enum EventStatus { offen, kommend, laufend, vorbei }

/// [von]/[bis] sind Datums-Werte (ohne Zeit); Randtage zählen als laufend.
/// Ohne Termin: offen. Nur [von] gesetzt: eintägiges Event.
EventStatus eventStatus(DateTime? von, DateTime? bis, DateTime heute) {
  if (von == null && bis == null) return EventStatus.offen;
  final h = DateTime(heute.year, heute.month, heute.day);
  final start = von ?? bis!;
  final ende = bis ?? von!;
  if (h.isBefore(DateTime(start.year, start.month, start.day))) {
    return EventStatus.kommend;
  }
  if (h.isAfter(DateTime(ende.year, ende.month, ende.day))) {
    return EventStatus.vorbei;
  }
  return EventStatus.laufend;
}
