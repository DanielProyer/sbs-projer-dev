/// Eigene Aufgaben mit Fälligkeitsdatum an einem Tag — für den Tourenplan
/// (27.09.2026: Aufgaben erschienen dort bisher nicht, nur in Glocke,
/// Startkarte und Aufgaben-Screen).
///
/// Quelle sind die rohen Zeilen der Tabelle `aufgaben` (Migration 150,
/// `aufgabenZeilenProvider`). Nur `typ = 'eigene'` trägt Titel und
/// `faellig_am`; Marker- und Snooze-Zeilen liegen in derselben Tabelle und
/// fallen weg. Die Tabelle kennt keinen Betrieb — eine Aufgabe ist Freitext.
library;

/// Eine Aufgabe am Tag, nur zur Anzeige.
typedef AufgabeAmTag = ({String id, String titel, bool erledigt});

/// Die eigenen Aufgaben, die am Kalendertag [tag] fällig sind — auch die
/// erledigten (der Tourenplan zeigt den Haken). Offene zuerst, dann nach
/// Titel. Zeilen ohne Id oder mit unlesbarem Datum fallen weg.
List<AufgabeAmTag> aufgabenAmTag(
  List<Map<String, dynamic>> zeilen,
  DateTime tag,
) {
  final liste = <AufgabeAmTag>[];
  for (final z in zeilen) {
    if (z['typ'] != 'eigene') continue;
    final id = z['id'];
    final faellig = DateTime.tryParse(z['faellig_am'] as String? ?? '');
    if (id is! String || faellig == null) continue;
    // `faellig_am` ist eine date-Spalte («2026-09-27») — Kalendertag
    // vergleichen, nie über Stunden rechnen.
    if (faellig.year != tag.year ||
        faellig.month != tag.month ||
        faellig.day != tag.day) {
      continue;
    }
    final titel = (z['titel'] as String?)?.trim();
    liste.add((
      id: id,
      titel: titel == null || titel.isEmpty ? '?' : titel,
      erledigt: z['erledigt_am'] != null,
    ));
  }
  liste.sort((a, b) {
    if (a.erledigt != b.erledigt) return a.erledigt ? 1 : -1;
    return a.titel.toLowerCase().compareTo(b.titel.toLowerCase());
  });
  return liste;
}
