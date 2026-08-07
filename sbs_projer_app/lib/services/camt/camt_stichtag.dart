/// Nach diesem Buchungsdatum greift die automatische Rechnungskontrolle/
/// Buchung. Alles bis und mit Stichtag bleibt im bestehenden System.
///
/// Der 11.03.2026 ist der LETZTE Excel-Banktag — seine Bewegungen (u. a.
/// SVA 5'962.20 + Kehricht 153.00) sind bereits aus dem Excel gebucht.
/// camt übernimmt ab dem 12.03. Ein inklusiver Vergleich buchte den Tag
/// doppelt (Off-by-One-Befund, Datenprüfung 05.08.2026).
class CamtStichtag {
  static final DateTime stichtag = DateTime(2026, 3, 11);
  static bool istAutomatisierbar(DateTime bookingDate) =>
      bookingDate.isAfter(stichtag);
}
