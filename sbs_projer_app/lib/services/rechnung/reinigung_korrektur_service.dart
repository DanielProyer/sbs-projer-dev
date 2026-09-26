import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/reinigung_korrektur_regel.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/mahnfall_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/buchung_nachhol_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';

/// Stand der Buchhaltung zu einer Reinigung, wie ihn das Formular braucht.
class KorrekturStand {
  final Rechnung? rechnung;
  final KorrekturSperre sperre;
  const KorrekturStand({required this.rechnung, required this.sperre});
  String get text => sperrText(sperre, rechnung?.rechnungsnummer);
}

class KorrekturErgebnis {
  final bool buchungVerbucht;
  final String? buchungTypLabel;
  final Rechnung? rechnung;
  const KorrekturErgebnis({
    required this.buchungVerbucht,
    required this.buchungTypLabel,
    required this.rechnung,
  });
}

/// Korrektur einer abgeschlossenen Reinigung. Seit R1: erst prüfen, dann
/// stornieren (nie löschen), und jeder Fehler wandert zum Aufrufer.
class ReinigungKorrekturService {
  /// Rechnung zur Reinigung und die Sperre dazu. Zahlungsbuchungen tragen
  /// `beleg_id` = Rechnung; Ertragsbuchungen `beleg_id` = Reinigung.
  static Future<KorrekturStand> sperrePruefen(String reinigungServerId) async {
    final rechnungId = await RechnungsPositionRepository
        .getRechnungIdByServiceId(reinigungServerId);
    if (rechnungId == null) {
      return const KorrekturStand(rechnung: null, sperre: KorrekturSperre.keine);
    }
    final rechnung = await RechnungRepository.getById(rechnungId);
    final zahlungen = await BuchungRepository.getByBeleg(rechnungId);
    final hatZahlung = zahlungen.any(
      (b) => zaehltFuerSaldo(istStorniert: b.istStorniert, stornoVonId: b.stornoVonId),
    );
    final mahnfaelle = await MahnfallRepository.getByRechnung(rechnungId);
    final grenze = await BuchungNachholService.nachbuchGrenze();
    return KorrekturStand(
      rechnung: rechnung,
      sperre: korrekturSperre(
        rechnung: rechnung,
        hatZahlungsbuchung: hatZahlung,
        imMahnfall: mahnfaelle.isNotEmpty,
        nachbuchGrenze: grenze,
      ),
    );
  }

  /// Storniert die aktiven Ertragsbuchungen der Reinigung und entfernt die
  /// (unversendete, unbezahlte) Rechnung samt PDF. Wirft, wenn eine Sperre
  /// besteht — der Aufrufer MUSS vorher [sperrePruefen] gezeigt haben.
  static Future<void> zuruecknehmen(String reinigungServerId) async {
    final stand = await sperrePruefen(reinigungServerId);
    if (stand.sperre != KorrekturSperre.keine) {
      throw StateError(stand.text);
    }
    final buchungen = await BuchungRepository.getByBeleg(reinigungServerId);
    for (final b in buchungen) {
      if (!zaehltFuerSaldo(istStorniert: b.istStorniert, stornoVonId: b.stornoVonId)) {
        continue;
      }
      // `stornieren` nimmt MwSt-Trennbuchungen desselben Belegs gleich mit.
      // Die Liste oben ist also nach dem ersten Storno teils veraltet: jede
      // Zeile vor ihrem Storno frisch lesen und überspringen, wenn sie schon
      // als Geschwister storniert wurde. Kein try/catch auf die Fehlermeldung
      // — ein echter Fehler soll zum Aufrufer durchschlagen.
      final frisch = await BuchungRepository.getById(b.id);
      if (frisch == null ||
          !zaehltFuerSaldo(
              istStorniert: frisch.istStorniert, stornoVonId: frisch.stornoVonId)) {
        continue;
      }
      await BuchungRepository.stornieren(b.id);
    }
    final rechnung = stand.rechnung;
    if (rechnung != null) {
      await RechnungPdfStorage.deletePdf(rechnung.id);
      await RechnungRepository.delete(rechnung.id);
      debugPrint('[Korrektur] Rechnung ${rechnung.rechnungsnummer} entfernt');
    }
  }

  /// Zurücknehmen + neu erstellen (Rechnung, PDF, Ertragsbuchung). Kein
  /// Versand — die alte Rechnung war noch nicht beim Kunden.
  static Future<KorrekturErgebnis> korrigieren(
    ReinigungLocal reinigung,
    BetriebLocal betrieb,
  ) async {
    await zuruecknehmen(reinigung.serverId!);
    final rechnung = await RechnungService.createFromReinigung(reinigung, betrieb);
    final buchung = await ReinigungBuchungService.createFromReinigung(reinigung, betrieb);
    String? label;
    if (buchung != null) {
      final art = resolveZahlungsart(reinigung.zahlungsart, betrieb.rechnungsstellung);
      label = art == 'barzahlung' ? 'Barzahlung' : 'Rechnung';
    }
    return KorrekturErgebnis(
      buchungVerbucht: buchung != null,
      buchungTypLabel: label,
      rechnung: rechnung,
    );
  }
}
