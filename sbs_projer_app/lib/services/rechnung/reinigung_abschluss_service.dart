import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/versand_meldung.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/bergkundenpauschale_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/buchung_nachhol_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';
import 'package:sbs_projer_app/services/rechnung/reinigung_rechnung_versand.dart';

enum AbschlussStufe { info, warnung, fehler }

/// Eine Meldung aus der Kette — der Screen zeigt sie als Snackbar.
class AbschlussMeldung {
  final String text;
  final AbschlussStufe stufe;
  const AbschlussMeldung(this.text, this.stufe);

  Duration get dauer => switch (stufe) {
        AbschlussStufe.info => const Duration(seconds: 4),
        AbschlussStufe.warnung => const Duration(seconds: 8),
        AbschlussStufe.fehler => const Duration(seconds: 12),
      };
}

class AbschlussErgebnis {
  final bool rechnungErstellt;
  final bool buchungVerbucht;
  final String? buchungTypLabel;
  final int nachgeholt;
  final List<AbschlussMeldung> meldungen;

  const AbschlussErgebnis({
    required this.rechnungErstellt,
    required this.buchungVerbucht,
    required this.buchungTypLabel,
    required this.nachgeholt,
    required this.meldungen,
  });
}

/// Text der Abschluss-Snackbar (rein, getestet).
String abschlussSnackbarText(AbschlussErgebnis e) {
  if (!e.buchungVerbucht) return 'Reinigung abgeschlossen';
  final nach = e.nachgeholt > 0
      ? ' · ${e.nachgeholt} frühere Buchung${e.nachgeholt == 1 ? '' : 'en'} nachgeholt'
      : '';
  return 'Reinigung abgeschlossen – ${e.buchungTypLabel} verbucht$nach';
}

/// DIE Abschlusskette einer Reinigung. Bis v0.139.0 lag sie zweimal vor:
/// rund 500 Zeilen im Formular und (fürs Nachholen) in
/// `ReinigungRechnungVersand.erstelleUndSende` plus separater Buchung im
/// Detail-Screen; jeder Fix musste doppelt gemacht werden, und die Kette riss
/// am 03./04./07./11.09.2026 an je anderer Stelle. Jetzt rufen Formular und
/// Detail-Screen nur noch diese Methode. Reihenfolge und Fehlerhaltung:
///   1. Rechnung + Versand (Mail/Post/Tresen) — Fehler → Meldung, weiter.
///   2. Ertragsbuchung — UNABHÄNGIG von 1 — Fehler → Meldung, weiter.
///   3. Nachholen früherer Abschlüsse (nur wenn 2 durchlief, 14 Tage, 20 s).
///   4. Bergkundenpauschale (wird Heineken verrechnet) — nie doppelt.
///   5. Kulanz-Merker am Betrieb löschen.
/// Kulanz / Heineken-Monteur: 1 und 2 liefern selbst «nichts zu tun».
///
/// Wirft nie — jeder Schritt meldet über [AbschlussErgebnis.meldungen].
class ReinigungAbschlussService {
  static Future<AbschlussErgebnis> abschliessen(
    ReinigungLocal r,
    BetriebLocal betrieb, {
    bool nachholen = true,
  }) async {
    final meldungen = <AbschlussMeldung>[];
    var rechnungErstellt = false;

    // 1. Rechnung + Versand
    try {
      final erg = await ReinigungRechnungVersand.erstelleUndSende(r, betrieb);
      rechnungErstellt = erg.rechnungErstellt;
      // Ein fehlendes PDF wird immer gemeldet — auch wenn die Rechnung schon
      // bestand (Vorfall 01.09.2026: Erfolg gemeldet, Beleg fehlte). Eine
      // bereits vorhandene Rechnung ebenfalls: sonst stünde im
      // Detail-Screen nur «Reinigung abgeschlossen».
      if (erg.rechnungErstellt ||
          erg.warVorhanden ||
          erg.mailGesendet ||
          erg.pdfFehlt) {
        meldungen.add(AbschlussMeldung(
          erg.meldung,
          erg.keineKundenadresse || erg.pdfFehlt || erg.hinweis
              ? AbschlussStufe.warnung
              : AbschlussStufe.info,
        ));
      }
    } catch (e) {
      debugPrint('[Abschluss] Rechnung/Versand: $e');
      // VersandFehler trägt den genauen Server-Stand («Mail NICHT versendet
      // — im Rechnungs-Detail nachholen»), alles andere die vorsichtige
      // Ketten-Meldung («prüfen»).
      final text = e is VersandFehler ? e.text : kettenFehlerMeldung(e);
      meldungen.add(AbschlussMeldung(
        'Reinigung ist abgeschlossen. $text',
        AbschlussStufe.fehler,
      ));
    }

    // 2. Ertragsbuchung — unabhängig von 1: eine gescheiterte Rechnung darf
    //    NIE die Buchhaltung verhindern.
    var buchungVerbucht = false;
    String? buchungTypLabel;
    try {
      final buchung =
          await ReinigungBuchungService.createFromReinigung(r, betrieb);
      if (buchung != null) {
        buchungVerbucht = true;
        final art = resolveZahlungsart(r.zahlungsart, betrieb.rechnungsstellung);
        buchungTypLabel = art == 'barzahlung' ? 'Barzahlung' : 'Rechnung';
      }
    } catch (e) {
      debugPrint('[Abschluss] Buchung: $e');
      meldungen.add(
        AbschlussMeldung(buchungFehlerMeldung(e), AbschlussStufe.fehler),
      );
    }

    // 3. Frühere Abschlüsse nachziehen, deren Buchung nie ankam (03./04.09.:
    //    Handy weggesteckt). Nur wenn die eigene Buchung eben durchlief — dann
    //    ist die Verbindung nachweislich gut. Nur 14 Tage (ein Lauf über die
    //    ganze Historie darf nie unbemerkt starten), mit Timeout (der Nachlauf
    //    darf die Kette nicht selbst verlängern). Fehler sichtbar melden: bis
    //    10.09.2026 standen sie nur im Debug-Protokoll (Signina, Mountain
    //    Plaza blieben tagelang liegen).
    var nachgeholt = 0;
    if (nachholen && buchungVerbucht) {
      try {
        final erg = await BuchungNachholService.nachholen(
          ab: DateTime.now().subtract(const Duration(days: 14)),
        ).timeout(const Duration(seconds: 20));
        nachgeholt = erg.gebucht;
        if (erg.fehler.isNotEmpty) {
          // Details (mit Server-URL) ins Protokoll, nicht aufs Handy.
          debugPrint('[Nachbuchung] ${erg.fehler.join(' | ')}');
          meldungen.add(AbschlussMeldung(
            'NACHBUCHEN FEHLGESCHLAGEN (${erg.fehler.length}): '
            '${kurzeFehlermeldung(erg.fehler.first)}\n'
            'Über Buchhaltung → Forderungen erneut versuchen.',
            AbschlussStufe.fehler,
          ));
        }
      } catch (e) {
        debugPrint('[Nachbuchung] Fehler: $e');
        meldungen.add(AbschlussMeldung(
          'Nachbuchen älterer Reinigungen abgebrochen '
          '(${kurzeFehlermeldung(e)}).\n'
          'Die eigene Buchung ist gespeichert.',
          AbschlussStufe.warnung,
        ));
      }
    }

    // 4. Bergkundenpauschale (wird Heineken verrechnet, nicht dem Kunden).
    //    Vorher prüfen: Die Kette läuft auch als Nachhol-Weg und beim
    //    erneuten Abschliessen — die Pauschale darf nur einmal entstehen,
    //    und zwar pro BESUCH (Betrieb + Tag), nicht pro Anlage/Reinigung.
    if (r.istBergkunde && !r.istHeinekenMonteur && r.serverId != null) {
      try {
        final vorhanden =
            await BergkundenpauschaleRepository.existiertFuerBesuch(
          reinigungId: r.serverId!,
          betriebId: r.betriebId,
          datum: r.datum,
        );
        if (!vorhanden) {
          final preis = await PreisRepository.getAktuell(datum: r.datum);
          await BergkundenpauschaleRepository.create({
            'betrieb_id': r.betriebId,
            'reinigung_id': r.serverId,
            'datum': r.datum.toIso8601String().split('T').first,
            'betrag': preis?.bergkundenZuschlag ?? 180.0,
          });
        }
      } catch (e) {
        debugPrint('[Bergkundenpauschale] Fehler: $e');
        meldungen.add(AbschlussMeldung(
          'Bergkundenpauschale NICHT erfasst (${kurzeFehlermeldung(e)}) — '
          'unter Bergkundenpauschalen nachtragen.',
          AbschlussStufe.warnung,
        ));
      }
    }

    // 5. Kulanz-Merker löschen. Er ist EINMALIG: Beim Chleina Pub blieb der
    //    blosse Hinweis 40 Tage stehen; ein stehender Merker verschenkt die
    //    nächste Reinigung ungefragt. Scheitert das Löschen (Funkloch), ist
    //    die nächste Reinigung wieder vorgewählt — sichtbar und korrigierbar,
    //    deshalb nur ins Protokoll.
    if (r.istKulanz && betrieb.naechsteReinigungKulanz) {
      try {
        betrieb.naechsteReinigungKulanz = false;
        await BetriebRepository.save(betrieb);
      } catch (e) {
        debugPrint('[Kulanz-Merker] Zuruecksetzen fehlgeschlagen: $e');
      }
    }

    return AbschlussErgebnis(
      rechnungErstellt: rechnungErstellt,
      buchungVerbucht: buchungVerbucht,
      buchungTypLabel: buchungTypLabel,
      nachgeholt: nachgeholt,
      meldungen: meldungen,
    );
  }
}
