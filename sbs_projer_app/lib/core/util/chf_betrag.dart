/// Betrags-Eingaben aus Formularen in eine Zahl wandeln (rein, testbar).
library;

/// Wandelt eine CHF-Eingabe in eine Zahl.
///
/// Toleriert beide Tausendertrennzeichen (`1'234.50` und `1’234.50`,
/// U+2019 kommt aus iOS-Tastaturen und aus kopierten Excel-Zellen),
/// Leerzeichen sowie das Komma als Dezimaltrenner (`1234,50`).
/// Gibt `null` zurück, wenn die Eingabe leer oder nicht lesbar ist —
/// der Aufrufer muss beide Fälle unterscheiden, damit ein Tippfehler
/// nicht still als «kein Betrag» gespeichert wird.
double? chfBetragParsen(String eingabe) {
  final bereinigt = eingabe
      .replaceAll("'", '')
      .replaceAll('’', '')
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll(',', '.');
  if (bereinigt.isEmpty) return null;
  return double.tryParse(bereinigt);
}
