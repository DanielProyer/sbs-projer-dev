/// Setzt die Jahreszahl für Saisonfenster, die Kundenwebsites nur mit
/// Tag und Monat angeben ("Sommersaison 15. Juni bis 20. Oktober").
///
/// Der Knackpunkt: Ein Winterfenster läuft typischerweise über den
/// Jahreswechsel (z.B. Start 1. Dezember, Ende 1. April). Das Enddatum
/// gehört dann ins FOLGEJAHR des Startdatums, sonst liegt "Ende" rechnerisch
/// vor "Start" — was z.B. Datumsbereichs-Vergleiche und Anzeigen kaputt macht.
library;

/// Bestimmt Start- und Enddatum eines Saisonfensters, das nur als
/// (Tag, Monat)-Paar bekannt ist, bezogen auf ein Referenzdatum [heute].
///
/// Liegt (vonMonat, vonTag) im Jahreslauf VOR (bisMonat, bisTag) — also ein
/// normales Fenster innerhalb eines Kalenderjahres wie "15.6.–20.10." —
/// werden beide Daten ins Jahr von [heute] gelegt.
///
/// Andernfalls handelt es sich um ein Fenster über den Jahreswechsel (z.B.
/// "1.12.–1.4."). In diesem Fall gehört [bis] ins Jahr NACH [von].
///
/// Sonderfall: Steckt [heute] bereits mitten in einem solchen
/// Jahreswechsel-Fenster (z.B. heute=10.02.2027 bei Fenster 1.12.–1.4.),
/// darf das Fenster nicht ein Jahr nach vorne verschoben werden — der Start
/// muss im zurückliegenden Jahr bleiben (01.12.2026), das Ende im laufenden
/// Jahr (01.04.2027). Sonst würde z.B. eine "läuft die Saison gerade"-Prüfung
/// fälschlich "nein" liefern.
({DateTime von, DateTime bis}) saisonFenster({
  required int vonTag,
  required int vonMonat,
  required int bisTag,
  required int bisMonat,
  required DateTime heute,
}) {
  final vorImJahreslauf =
      vonMonat < bisMonat || (vonMonat == bisMonat && vonTag < bisTag);

  if (vorImJahreslauf) {
    // Normales Fenster: Start und Ende liegen im selben Kalenderjahr wie heute.
    return (
      von: DateTime(heute.year, vonMonat, vonTag),
      bis: DateTime(heute.year, bisMonat, bisTag),
    );
  }

  // Fenster über den Jahreswechsel. Zuerst prüfen, ob heute bereits in dem
  // Fenster steckt, das letztes Jahr begonnen hat (von = heute.year - 1).
  final vonVorjahr = DateTime(heute.year - 1, vonMonat, vonTag);
  final bisLaufendesJahr = DateTime(heute.year, bisMonat, bisTag);
  final heuteImLaufendenFenster =
      !heute.isBefore(vonVorjahr) && !heute.isAfter(bisLaufendesJahr);

  if (heuteImLaufendenFenster) {
    return (von: vonVorjahr, bis: bisLaufendesJahr);
  }

  // Heute liegt ausserhalb — das nächste (oder gerade erst begonnene)
  // Fenster startet im laufenden Jahr, endet im Folgejahr.
  return (
    von: DateTime(heute.year, vonMonat, vonTag),
    bis: DateTime(heute.year + 1, bisMonat, bisTag),
  );
}

/// Korrigiert ein bereits bestehendes (von, bis)-Datumspaar, dessen
/// Jahreszahlen inkonsistent gesetzt wurden: Liegt [bis] vor [von] (z.B.
/// weil beide Daten fälschlich ins selbe Jahr gesetzt wurden, obwohl das
/// Fenster über den Jahreswechsel läuft), wird ein Jahr auf [bis] addiert.
///
/// Reparatur-Fall in der Datenbank: Winterfenster wie beim Robinson Club
/// Arosa standen mit 01.12.2026–01.04.2026 (beide Daten im selben Jahr)
/// in der DB. Diese Funktion macht daraus 01.12.2026–01.04.2027.
({DateTime von, DateTime bis}) jahreszahlenRichten({
  required DateTime von,
  required DateTime bis,
}) {
  if (bis.isBefore(von)) {
    final bisKorrigiert = DateTime(
      bis.year + 1,
      bis.month,
      bis.day,
      bis.hour,
      bis.minute,
      bis.second,
      bis.millisecond,
      bis.microsecond,
    );
    return (von: von, bis: bisKorrigiert);
  }
  return (von: von, bis: bis);
}
