/// Ob ein täglicher Google-Kalender-Vollabgleich fällig ist.
///
/// Liefert `true`, wenn noch nie abgeglichen wurde ([letzterSync] == null)
/// oder der letzte Abgleich an einem **früheren Kalendertag** (lokale Zeit)
/// lag. So läuft der Abgleich genau einmal pro Kalendertag — auch bei einem
/// tagelang offenen Browser-Tab (periodischer Aufruf).
bool brauchtTagesSync(DateTime? letzterSync, DateTime jetzt) {
  if (letzterSync == null) return true;
  final l = letzterSync.toLocal();
  final n = jetzt.toLocal();
  return l.year != n.year || l.month != n.month || l.day != n.day;
}
