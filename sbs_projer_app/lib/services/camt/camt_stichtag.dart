/// Ab diesem Buchungsdatum greift die automatische Rechnungskontrolle/Buchung.
/// Alles davor bleibt im bestehenden System.
class CamtStichtag {
  static final DateTime stichtag = DateTime(2026, 3, 11);
  static bool istAutomatisierbar(DateTime bookingDate) =>
      !bookingDate.isBefore(stichtag);
}
