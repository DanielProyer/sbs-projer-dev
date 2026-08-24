/// Ergebnis eines satzweisen Push: was durchging und was nicht.
typedef PushErgebnis<T> = ({List<T> erfolgreich, List<String> fehler});

/// Schiebt [items] **einzeln** hoch und sammelt Teilfehler ein, statt sie zu
/// verschlucken.
///
/// Satzweise statt als Bulk, damit ein einzelner kaputter Datensatz nicht den
/// ganzen Rest blockiert — ein gescheiterter Satz bleibt unmarkiert und wird
/// beim nächsten Lauf erneut versucht.
///
/// **Warum es diese Funktion gibt:** Der Vorgänger im `SyncService` fing
/// Fehler pro Satz ab und schrieb sie nur in `debugPrint`. Der Aufrufer bekam
/// ausschliesslich die Erfolge zurück, `SyncResult.errors` blieb leer und die
/// App meldete «Sync erfolgreich», während Sätze still auf dem Server fehlten.
/// Nur ein Fehler, der die *ganze* Entity-Funktion warf, wurde je sichtbar.
/// Gefunden im Review zu v0.87.0, behoben am 24.08.2026.
Future<PushErgebnis<T>> pushEinzeln<T>({
  required List<T> items,
  required Future<String> Function(T) push,
  required void Function(T item, String serverId) beiErfolg,
  required String Function(T) bezeichnung,
}) async {
  final erfolgreich = <T>[];
  final fehler = <String>[];
  for (final item in items) {
    try {
      final serverId = await push(item);
      beiErfolg(item, serverId);
      erfolgreich.add(item);
    } catch (e) {
      fehler.add('${bezeichnung(item)}: $e');
    }
  }
  return (erfolgreich: erfolgreich, fehler: fehler);
}

/// Eine Zeile für die Sync-Fehlerliste, oder `null` wenn nichts schieflief.
///
/// Bewusst mit Anzahl **und** erstem Klartext-Fehler: Die Anzahl sagt, wie
/// viel fehlt, der Klartext sagt warum — beides zusammen entscheidet, ob es
/// ein vorübergehender Netzfehler oder ein kaputter Datensatz ist.
String? pushFehlerMeldung(String tabelle, List<String> fehler) {
  if (fehler.isEmpty) return null;
  return '$tabelle: ${fehler.length} Satz/Sätze nicht übertragen '
      '(${fehler.first})';
}
