/// Kalenderwoche nach ISO 8601 (Woche 1 enthält den ersten Donnerstag).
///
/// Eine Stelle für die ganze App (seit 23.09.2026): Die Wochenleiste im
/// Tourenplan, die Pikett-Zeile in den Einsätzen und die Pikett-Detailseite
/// rechneten vorher je für sich — und die früheste Fassung im Tourenplan lag
/// am Jahreswechsel daneben, weil sie ab dem 1. Januar zählte.
library;

int kalenderwoche(DateTime datum) {
  // In UTC rechnen. `difference().inDays` auf lokalen Daten verliert über
  // einen Sommerzeit-Wechsel eine Stunde und damit einen ganzen Tag: Vom
  // 1. Januar zum 17. September 2026 ergäbe das 258 statt 259 Tage — und
  // damit KW 37 statt 38. Der Fehler zeigt sich nur im Sommerhalbjahr.
  final donnerstag = _donnerstagDerWoche(datum);
  final jahresbeginn = DateTime.utc(donnerstag.year, 1, 1);
  return (donnerstag.difference(jahresbeginn).inDays / 7).floor() + 1;
}

/// Das Jahr, zu dem die ISO-Kalenderwoche von [datum] gehört — das Jahr
/// ihres Donnerstags, NICHT `datum.year`.
///
/// Am Jahreswechsel gehen beide auseinander: Mo 29.12.2025 liegt in
/// KW 1/2026, Fr 01.01.2027 in KW 53/2026. Wer «Jahr + KW» speichert oder
/// anzeigt, braucht dieses Jahr — sonst wird aus KW 1/2026 die KW 1/2025,
/// ein ganzes Jahr daneben (Pikett-Formular bis 26.09.2026).
int isoWochenjahr(DateTime datum) => _donnerstagDerWoche(datum).year;

/// Donnerstag derselben ISO-Woche (UTC): Montag (1) + 3, Sonntag (7) − 3.
DateTime _donnerstagDerWoche(DateTime datum) {
  final tag = DateTime.utc(datum.year, datum.month, datum.day);
  return tag.add(Duration(days: DateTime.thursday - tag.weekday));
}
