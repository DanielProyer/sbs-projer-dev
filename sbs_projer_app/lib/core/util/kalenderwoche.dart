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
  final tag = DateTime.utc(datum.year, datum.month, datum.day);
  // Donnerstag derselben Woche: Montag (1) + 3, Sonntag (7) − 3.
  final donnerstag = tag.add(Duration(days: 4 - tag.weekday));
  final jahresbeginn = DateTime.utc(donnerstag.year, 1, 1);
  return (donnerstag.difference(jahresbeginn).inDays / 7).floor() + 1;
}
