import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';

/// Macht die Stufe-2-Zahlung (camt-Kreditor-Abschluss) einer Eingangsrechnung
/// rückgängig — sodass sowohl die Bank-Belastung (camt-Tx) wieder importierbar
/// als auch die Rechnung wieder zahlbar/abgleichbar wird.
class EingangsrechnungReversalService {
  /// Zielstatus nach Rücknahme der Stufe-2-Zahlung: zurück in den zahlbaren
  /// Zustand — `exportiert`, falls ein Zahlungsfile erzeugt wurde, sonst
  /// `gebucht`. (Stufe-1-Buchung + Export bleiben unberührt.)
  static String zielStatus(Eingangsrechnung e) =>
      e.exportiertAm != null ? 'exportiert' : 'gebucht';

  /// Felder, die beim Zurücksetzen der Stufe-2-Zahlung geschrieben werden.
  static Map<String, dynamic> resetFelder(Eingangsrechnung e) => {
        'status': zielStatus(e),
        'bezahlt_am': null,
        'buchung_stufe2_id': null,
        'camt_tx_key': null,
      };

  /// Löscht die Stufe-2-Zahlungs-Buchung (camt-Tx damit wieder importierbar)
  /// und setzt die Eingangsrechnung zurück. Idempotent gegenüber fehlender
  /// Stufe-2-Buchung (z.B. doppeltes Rückgängig).
  static Future<void> zahlungRueckgaengig(Eingangsrechnung e) async {
    if (e.buchungStufe2Id != null) {
      await BuchungRepository.delete(e.buchungStufe2Id!);
    }
    await EingangsrechnungRepository.update(e.id, resetFelder(e));
  }

  /// Konsistenz-Hook: wurde eine Stufe-2-Buchung anderswo storniert/gelöscht
  /// (z.B. im Buchungs-Detail), die zugehörige Eingangsrechnung zurücksetzen
  /// und den camt-Schlüssel der stornierten Buchung freigeben (re-importierbar).
  /// Liefert die betroffene Eingangsrechnung-ID oder null.
  static Future<String?> resetNachBuchungStorno(String buchungId) async {
    final e = await EingangsrechnungRepository.getByBuchungStufe2Id(buchungId);
    if (e == null) return null;
    await EingangsrechnungRepository.update(e.id, resetFelder(e));
    // camt-Schlüssel der (stornierten) Original-Buchung freigeben.
    await BuchungRepository.update(buchungId, {'camt_tx_key': null});
    return e.id;
  }
}
