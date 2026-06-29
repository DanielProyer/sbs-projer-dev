import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
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
    // Frisch laden — der übergebene Snapshot kann veraltet sein (z.B. wenn die
    // Stufe-2-Buchung zwischenzeitlich anderswo storniert wurde).
    final akt = await EingangsrechnungRepository.getById(e.id) ?? e;
    final key = akt.camtTxKey;
    final stufe2Id = akt.buchungStufe2Id;
    if (stufe2Id != null) {
      final b = await BuchungRepository.getById(stufe2Id);
      // Nur die AKTIVE Stufe-2-Buchung löschen — eine bereits stornierte
      // Buchung oder eine Storno-Gegenbuchung NICHT anfassen (sonst Waise).
      if (b != null && !b.istStorniert && b.stornoVonId == null) {
        await BuchungRepository.delete(stufe2Id);
      }
    }
    await EingangsrechnungRepository.update(akt.id, resetFelder(akt));
    if (key != null) await CamtPrueflisteRepository.deleteByTxKey(key);
  }

  /// Konsistenz-Hook: wurde eine Stufe-2-Buchung anderswo storniert/gelöscht
  /// (z.B. im Buchungs-Detail), die zugehörige Eingangsrechnung zurücksetzen
  /// und den camt-Schlüssel der stornierten Buchung freigeben (re-importierbar).
  /// Liefert die betroffene Eingangsrechnung-ID oder null.
  static Future<String?> resetNachBuchungStorno(String buchungId) async {
    var e = await EingangsrechnungRepository.getByBuchungStufe2Id(buchungId);
    // Fallback: bei Teil-Schreibfehler (Buchung erstellt, aber buchung_stufe2_id
    // auf der Rechnung nie gesetzt) über die beleg_id der Zahlungs-Buchung
    // suchen — so wird auch eine verwaiste Zahlungs-Buchung sauber freigegeben.
    if (e == null) {
      final b = await BuchungRepository.getById(buchungId);
      if (b != null && b.belegTyp == 'zahlung' && b.belegId != null) {
        e = await EingangsrechnungRepository.getById(b.belegId!);
      }
    }
    if (e == null) return null;
    final key = e.camtTxKey;
    await EingangsrechnungRepository.update(e.id, resetFelder(e));
    // camt-Schlüssel der (stornierten) Original-Buchung freigeben.
    await BuchungRepository.update(buchungId, {'camt_tx_key': null});
    if (key != null) await CamtPrueflisteRepository.deleteByTxKey(key);
    return e.id;
  }
}
