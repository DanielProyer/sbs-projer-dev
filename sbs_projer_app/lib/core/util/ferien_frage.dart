/// Entscheidet, ob beim Abschluss einer Reinigung die Frage nach den
/// naechsten Betriebsferien gezeigt werden soll.
///
/// [bestaetigtAm] = `betriebe.ferien_bestaetigt_am` (wann zuletzt jemand die
/// Frage beantwortet hat). [ruhtBis] = `betriebe.ferien_frage_ruht_bis`
/// (Antwort "weiss nicht" laesst die Frage 30 Tage ruhen). [heute] = der
/// Zeitpunkt, gegen den geprueft wird (Aufrufer uebergibt i.d.R. `DateTime.now()`).
///
/// Reihenfolge der Regeln (Ruhephase hat immer Vorrang):
/// 1. [ruhtBis] liegt in der Zukunft ODER ist heute -> NICHT fragen,
///    unabhaengig davon, wie lange [bestaetigtAm] zurueckliegt.
/// 2. [ruhtBis] liegt in der Vergangenheit -> zaehlt nicht mehr, es gilt
///    nur noch [bestaetigtAm].
/// 3. [bestaetigtAm] fehlt -> fragen.
/// 4. [bestaetigtAm] liegt 12 Monate oder laenger zurueck -> fragen.
/// 5. sonst -> nicht fragen.
bool ferienFrageZeigen({
  required DateTime? bestaetigtAm,
  required DateTime? ruhtBis,
  required DateTime heute,
}) {
  final heuteTag = _dateOnly(heute);

  if (ruhtBis != null && !_dateOnly(ruhtBis).isBefore(heuteTag)) {
    return false;
  }

  if (bestaetigtAm == null) return true;

  final faelligAb = _dateOnly(
    DateTime(bestaetigtAm.year + 1, bestaetigtAm.month, bestaetigtAm.day),
  );
  return !faelligAb.isAfter(heuteTag);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
