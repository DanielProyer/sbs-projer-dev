/// Ergebnis der XML-Dateiauswahl im camt-Import.
///
/// Drei Ausgänge statt `null` für alles: Bis 26.09.2026 lieferte ein
/// abgebrochener Dateidialog dasselbe `null` wie eine unlesbare Datei — der
/// Import-Reiter zeigte dann rot «Keine Datei ausgewählt …», obwohl der
/// Nutzer nur «Abbrechen» gedrückt hatte.
sealed class DateiWahl {
  const DateiWahl();
}

/// Dialog geschlossen, ohne eine Datei zu wählen — endet still.
final class DateiAbgebrochen extends DateiWahl {
  const DateiAbgebrochen();
}

/// Datei gewählt und als Text gelesen.
final class DateiGelesen extends DateiWahl {
  final String name;
  final String inhalt;
  const DateiGelesen({required this.name, required this.inhalt});
}

/// Datei gewählt, aber nicht lesbar (oder leer) — dem Nutzer zeigen.
final class DateiFehler extends DateiWahl {
  final String text;
  const DateiFehler(this.text);
}
