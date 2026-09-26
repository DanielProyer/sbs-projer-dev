import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/einzel_abschreibung.dart';
import 'package:sbs_projer_app/core/util/guthaben_verrechnung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschreibung_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/zahlungsdifferenz_service.dart';

/// Abschreiben einer einzelnen Rechnung.
///
/// Das Mahnen selbst läuft seit v0.134.0 ausschliesslich über den
/// `MahnlaufService` (Sammelschreiben je Betrieb, Sicherungen gegen das
/// Mahnen bezahlter Rechnungen, Protokoll mit «Zurücknehmen»). Die frühere
/// Einzel-Eskalation `eskalieren` ging an allen Sicherungen vorbei und wurde
/// deshalb entfernt.
class MahnwesenService {
  /// Rechnung abschreiben + Debitorenverlust korrekt buchen (netto + MWST-Rückholung).
  /// [heute] nur für Tests; sonst der laufende Tag. Zum Datum und zu den
  /// Beträgen siehe [einzelAbschreibung].
  ///
  /// Reihenfolge (Review Mahnwesen Teil 2, I-2): ZUERST buchen, DANN den
  /// Status setzen. Umgekehrt stand nach einem Abbruch eine «abgeschriebene»
  /// Rechnung ohne Buchung da — unsichtbar, weil nichts mehr sie anbietet.
  /// So bleibt im Fehlerfall die Rechnung offen, und der zweite Versuch
  /// erkennt die schon gebuchte Abschreibung ([abschreibungSchonGebucht])
  /// und zieht nur den Status nach.
  static Future<void> abschreiben(Rechnung angezeigt, {DateTime? heute}) async {
    // Frisch laden: Die Liste kann einen veralteten Stand zeigen (Zahlung
    // inzwischen eingegangen). Sperre und Statusschutz auf dem DB-Stand.
    final rechnung = await RechnungRepository.getById(angezeigt.id) ?? angezeigt;
    final a = einzelAbschreibung(rechnung, heute: heute ?? DateTime.now());
    final buchungen = await BuchungRepository.getByBeleg(rechnung.id);
    // Analyse 25.09.2026 Befund D: nie eine Rechnung mit Zahlung abschreiben.
    final sperre =
        abschreibSperre(rechnung, hatZahlung: zahlungGebucht(buchungen));
    if (sperre != null) throw Exception(sperre);
    // Verrechnetes Kundenguthaben zuerst ausbuchen (2030/1100), dann nur
    // «zu zahlen» abschreiben (Review Kundenguthaben I3). Steht die
    // Verrechnung schon (Abbruch beim ersten Versuch), nicht doppelt.
    if (a.guthaben > 0 && !buchungen.any(istGuthabenVerrechnung)) {
      await ZahlungsdifferenzService.verrechnungBuchen(
          rechnung, a.guthaben, a.datum);
    }
    final schon = abschreibungSchonGebucht(buchungen);
    if (!schon && a.brutto >= 0.005) {
      await AbschreibungService.abschreiben(
        brutto: a.brutto,
        // Steuer der Rechnung, nicht Satz des Datums (Altjahrgänge!).
        mwst: a.mwst,
        datum: a.datum,
        beschreibung: a.beschreibung,
        belegnummer: rechnung.rechnungsnummer,
        belegId: rechnung.id,
      );
    }
    // Nur wenn der Status noch der geprüfte ist — sonst hat inzwischen ein
    // anderer Weg (Zahlung, Mahnlauf) die Rechnung angefasst.
    final ok = await RechnungRepository.updateWennStatus(
      rechnung.id,
      {'zahlungsstatus': 'abgeschrieben'},
      erwarteterStatus: rechnung.zahlungsstatus,
    );
    if (!ok) {
      throw Exception(
          'inzwischen geändert — Status nicht gesetzt, '
          'Rechnungsdetail prüfen');
    }
    debugPrint(
      schon
          ? '[Mahnwesen] Rechnung ${rechnung.rechnungsnummer}: Abschreibung war schon '
              'gebucht — nur Status nachgezogen'
          : '[Mahnwesen] Rechnung ${rechnung.rechnungsnummer} abgeschrieben '
              '(${a.netto} + ${a.mwst} MWST, per ${a.datum.toIso8601String().split('T').first})',
    );
  }
}
