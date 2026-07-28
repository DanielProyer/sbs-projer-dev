// Zeitfenster für den camt-Forderungsabgleich.

/// Standardfenster: Forderungen bis zu einem Jahr zurück.
const int kAbgleichFensterJahre = 1;

/// Ist diese Forderung jung genug für den camt-Abgleich?
///
/// Der Abgleich soll nur Rechnungen anbieten, die höchstens ein Jahr alt sind
/// (Regel Daniel 28.07.2026). Ältere offene Posten stammen aus der Zeit, in der
/// Rechnungen per Mail/Post gar nicht gestellt wurden — sie werden abgeschrieben
/// und würden im Abgleich nur Fehlgriffe provozieren: Bei einem Betrieb stehen
/// dann zehn gleich hohe Altposten zur Auswahl, und eine neue Zahlung landet
/// womöglich auf einer Rechnung von 2019.
///
/// Die Grenze ist einschliessend: genau ein Jahr alt zählt noch dazu.
/// Rechnungen mit Datum in der Zukunft bleiben drin — die kommen von
/// Vorauszahlungen oder Tippfehlern und sollen sichtbar bleiben.
bool istImAbgleichsfenster(DateTime rechnungsdatum, DateTime heute,
    {int jahre = kAbgleichFensterJahre}) {
  final grenze = DateTime(heute.year - jahre, heute.month, heute.day);
  final datum = DateTime(rechnungsdatum.year, rechnungsdatum.month, rechnungsdatum.day);
  return !datum.isBefore(grenze);
}
