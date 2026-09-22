/// Steht ein Event gerade an? Ab 7 Tagen vor dem Start bis und mit dem
/// letzten Tag (v0.132.0).
///
/// WARUM in UTC-Kalendertagen: Lokale Differenzen über eine Zeitumstellung
/// fressen einen Tag (23-Stunden-Tag, Memory «Datumsdifferenzen in UTC»).
library;

int _tag(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

bool eventImFenster(DateTime? von, DateTime? bis, DateTime jetzt) {
  if (von == null) return false;
  final heute = _tag(jetzt);
  final start = _tag(von);
  final ende = _tag(bis ?? von);
  return heute >= start - 7 && heute <= ende;
}
