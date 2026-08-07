/// Sperre für «PDF neu generieren» bei Heineken-Monatsrechnungen.
///
/// Die Monatsrechnungen vor April 2026 tragen im Storage die von Hand
/// erstellten Original-PDFs (Import 07.08.2026). Neu-Generieren würde sie
/// durch eine 3-Seiten-Fassung ohne Formulare ersetzen — die per Excel
/// nacherfassten Werkstatt-Daten enthalten die Formularfelder nicht.
library;

/// Erster Monat, dessen Rechnung die App selbst erstellt hat.
final DateTime ersteAppMonatsrechnung = DateTime(2026, 4, 1);

bool darfHeinekenPdfNeuGenerieren(DateTime? heinekenMonat) {
  if (heinekenMonat == null) return true;
  return !heinekenMonat.isBefore(ersteAppMonatsrechnung);
}
