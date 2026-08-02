/// Sichtbarkeit geplanter Einsätze (Störungen, Montagen) je Tag.
///
/// Bisher liess `faelligeEintraegeProvider` Störungen und Montagen bewusst
/// ohne Datumsfilter durch — sie erschienen an JEDEM Tag gleich. Das war
/// folgerichtig, solange es kein Plandatum gab: Das einzige Datumsfeld war
/// das Meldedatum, danach zu filtern hätte keinen Sinn ergeben.
///
/// Mit `geplant_am` (Migration 163) ändert sich das. Diese Datei hält die
/// Regel, wann ein Einsatz an einem Tag auftaucht.
library;

/// Gehört der Einsatz in die Liste für [tag]?
///
/// Drei Fälle, jeder mit einem Grund:
/// - **geplant für diesen Tag** → ja, das ist der Termin.
/// - **kein Plandatum** → ja. Ein ungeplanter Einsatz ist genau das, was
///   noch eingeplant werden muss; würde er verschwinden, ginge er vergessen.
/// - **Plandatum liegt zurück** → ja. Verpasst ist nicht erledigt: Was
///   letzte Woche geplant war und nicht gemacht wurde, muss weiter auffallen.
///
/// Nur ein Einsatz, der für einen SPÄTEREN Tag geplant ist, verschwindet
/// aus der heutigen Liste — genau das war der Zweck der Übung.
bool einsatzGehoertZuTag({
  required DateTime? geplantAm,
  required DateTime tag,
}) {
  if (geplantAm == null) return true;
  final plan = DateTime(geplantAm.year, geplantAm.month, geplantAm.day);
  final ziel = DateTime(tag.year, tag.month, tag.day);
  return !plan.isAfter(ziel);
}

/// Liegt der geplante Termin vor [heute]? Ein ungeplanter Einsatz ist NICHT
/// überfällig — er ist ungeplant, das ist ein anderer Zustand.
bool einsatzIstUeberfaellig({
  required DateTime? geplantAm,
  required DateTime heute,
}) {
  if (geplantAm == null) return false;
  final plan = DateTime(geplantAm.year, geplantAm.month, geplantAm.day);
  final ziel = DateTime(heute.year, heute.month, heute.day);
  return plan.isBefore(ziel);
}

/// Muss der Eintrag beim Umplanen aus dem Tagesplan des ALTEN Tages entfernt
/// werden?
///
/// Nur wenn zuvor überhaupt ein Plandatum bestand UND sich das Datum durch
/// die Umplanung tatsächlich ändert — sonst bliebe ein „Geisterblock" am
/// alten Tag stehen (Fehlerbericht 02.08.2026: eine auf einen anderen Tag
/// umgeplante Störung/Montage stand danach an ZWEI Tagen in der Zeitachse,
/// weil der alte Tagesplan-Eintrag nie entfernt wurde). Ein Wechsel nur der
/// Uhrzeit (gleicher Tag) zählt NICHT als Umplanung auf einen anderen Tag.
bool mussAusAltemPlanEntfernt({
  required DateTime? altesDatum,
  required DateTime neuesDatum,
}) {
  if (altesDatum == null) return false;
  final alt = DateTime(altesDatum.year, altesDatum.month, altesDatum.day);
  final neu = DateTime(neuesDatum.year, neuesDatum.month, neuesDatum.day);
  return alt != neu;
}

/// Kurztext für die Anzeige: «01.08. 14:00», «01.08. ganztägig» oder
/// «nicht geplant». Ohne Uhrzeit heisst ganztägig — Daniels Entscheid vom
/// 31.07.2026: entweder fixer Termin oder ganztägig an einem Datum.
String planungsText({
  required DateTime? geplantAm,
  required String? geplantZeit,
}) {
  if (geplantAm == null) return 'nicht geplant';
  final d = geplantAm.day.toString().padLeft(2, '0');
  final m = geplantAm.month.toString().padLeft(2, '0');
  final datum = '$d.$m.';
  if (geplantZeit == null || geplantZeit.isEmpty) return '$datum ganztägig';
  return '$datum $geplantZeit';
}
