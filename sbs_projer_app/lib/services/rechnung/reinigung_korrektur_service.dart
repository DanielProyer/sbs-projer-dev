import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';

class ReinigungKorrekturService {
  /// Löscht Rechnung, PDF und Buchungen einer Reinigung.
  /// rechnungs_positionen + buchungs_belege werden via ON DELETE CASCADE entfernt.
  static Future<void> cleanupBuchhaltung(String reinigungServerId) async {
    try {
      // 1. Rechnung-ID finden via Position mit service_id
      final rechnungId = await RechnungsPositionRepository
          .getRechnungIdByServiceId(reinigungServerId);

      // 2. Buchungen löschen (beleg_id = reinigungServerId)
      await BuchungRepository.deleteByBeleg(reinigungServerId);
      debugPrint('KorrekturService: Buchungen gelöscht für $reinigungServerId');

      // 3. Rechnung + PDF löschen
      if (rechnungId != null) {
        await RechnungPdfStorage.deletePdf(rechnungId);
        await RechnungRepository.delete(rechnungId);
        debugPrint('KorrekturService: Rechnung $rechnungId gelöscht');
      }
    } catch (e) {
      debugPrint('KorrekturService.cleanupBuchhaltung fehlgeschlagen: $e');
      rethrow;
    }
  }

  /// Erstellt Rechnung + Buchungen neu aus der aktualisierten Reinigung.
  /// Gibt die neue Rechnung zurück (null wenn keine Rechnung nötig).
  static Future<({dynamic rechnung, bool buchungVerbucht, String? buchungTypLabel})>
      recreateBuchhaltung(
    ReinigungLocal reinigung,
    BetriebLocal betrieb,
  ) async {
    try {
      final rechnung =
          await RechnungService.createFromReinigung(reinigung, betrieb);
      final buchung =
          await ReinigungBuchungService.createFromReinigung(reinigung, betrieb);

      String? buchungTypLabel;
      if (buchung != null) {
        final artKorrektur =
            resolveZahlungsart(reinigung.zahlungsart, betrieb.rechnungsstellung);
        buchungTypLabel =
            artKorrektur == 'barzahlung' ? 'Barzahlung' : 'Rechnung';
      }

      debugPrint('KorrekturService: Rechnung/Buchungen neu erstellt');
      return (
        rechnung: rechnung,
        buchungVerbucht: buchung != null,
        buchungTypLabel: buchungTypLabel,
      );
    } catch (e) {
      debugPrint('KorrekturService.recreateBuchhaltung fehlgeschlagen: $e');
      rethrow;
    }
  }
}
