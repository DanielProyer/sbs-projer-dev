import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/models/camt_regel.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/heineken_buchung_service.dart';
import 'package:sbs_projer_app/services/camt/camt_ausgabe_booker.dart';
import 'package:sbs_projer_app/services/camt/camt_kreditor_booker.dart';
import 'package:sbs_projer_app/services/camt/camt_klassifizierer.dart';
import 'package:sbs_projer_app/services/camt/camt_vorschlag.dart';
import 'package:sbs_projer_app/services/camt/heineken_matcher.dart';
import 'package:sbs_projer_app/services/camt/regel_matcher.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/kreditoren_abgleich_service.dart';

class CamtAutoBooker {
  /// Bestätigungs-Modus: klassifiziert + matcht Bereich-2-Transaktionen, BUCHT
  /// aber NICHTS. Liefert bestätigbare Vorschläge (Regel-/Heineken-Treffer),
  /// die ungetroffenen für die Prüfliste und die Anzahl übersprungener.
  /// Rein (ohne IO) — testbar.
  static CamtPlanErgebnis plan({
    required List<CamtTransaction> transactions,
    required List<Rechnung> heinekenRechnungen,
    required List<CamtRegel> regeln,
    required Map<String, BuchungsVorlage> vorlagenById,
    List<Eingangsrechnung> offeneKreditoren = const [],
  }) {
    final vorschlaege = <CamtVorschlag>[];
    final pruefliste = <CamtTransaction>[];
    // Pro Plan-Lauf bereits zugeordnete Kreditoren — verhindert, dass zwei
    // Belastungen dieselbe offene Rechnung treffen (zweite -> Prüfliste).
    final verbrauchteKreditoren = <String>{};
    int uebersprungen = 0;

    for (final tx in transactions) {
      final kat = CamtKlassifizierer.kategorie(tx, betriebErkannt: false);
      switch (kat) {
        case TxKategorie.saldovortrag:
          uebersprungen++;
          break;
        case TxKategorie.heinekenEingang:
          final hr = HeinekenMatcher.match(
              zahlbetrag: tx.amount, heinekenRechnungen: heinekenRechnungen);
          if (hr != null) {
            vorschlaege.add(CamtVorschlag(
              tx: tx,
              typ: CamtVorschlagTyp.heineken,
              heinekenRechnung: hr,
              label: 'Heineken-Zahlung ${hr.rechnungsnummer ?? ''}',
            ));
          } else {
            pruefliste.add(tx);
          }
          break;
        case TxKategorie.bargeldEinzahlung:
        case TxKategorie.ausgabe:
          // TP-5: Kreditor-Abschluss VOR dem Ausgaben-Regelwerk (nur Belastungen).
          if (!tx.isCredit) {
            final kandidaten = offeneKreditoren
                .where((e) => !verbrauchteKreditoren.contains(e.id))
                .toList();
            final e = KreditorenAbgleichService.match(tx, kandidaten);
            if (e != null) {
              verbrauchteKreditoren.add(e.id);
              vorschlaege.add(CamtVorschlag(
                tx: tx,
                typ: CamtVorschlagTyp.kreditor,
                eingangsrechnung: e,
                label:
                    'Kreditor-Zahlung ${e.ausstellerName ?? ''} → bezahlt (${e.betragBrutto.toStringAsFixed(2)})',
              ));
              break;
            }
          }
          final vid = RegelMatcher.matchVorlageId(
            partyName: tx.partyName,
            partyIban: tx.partyIban,
            additionalInfo: tx.additionalInfo,
            remittanceInfo: tx.remittanceInfo,
            regeln: regeln,
          );
          final vorlage = vid != null ? vorlagenById[vid] : null;
          if (vorlage != null) {
            vorschlaege.add(CamtVorschlag(
              tx: tx,
              typ: CamtVorschlagTyp.ausgabe,
              vorlage: vorlage,
              label: '${vorlage.bezeichnung} → ${vorlage.sollKonto}',
            ));
          } else {
            pruefliste.add(tx);
          }
          break;
        case TxKategorie.kundenzahlung:
        case TxKategorie.unbekannt:
          pruefliste.add(tx);
          break;
      }
    }
    return CamtPlanErgebnis(vorschlaege, pruefliste, uebersprungen);
  }

  /// Bucht EINEN bestätigten Vorschlag über die bestehenden Booker
  /// (mit korrektem Datum + camt_tx_key).
  /// [steuer] (nur bei Ausgabe-Vorschlägen auf Steuerkonten) kontiert die
  /// Zahlung auf 2208/8900/2202 und stempelt Steuerjahr/Steuerart.
  static Future<void> bucheVorschlag(CamtVorschlag v,
      {SteuerZuordnung? steuer}) async {
    switch (v.typ) {
      case CamtVorschlagTyp.kreditor:
        await CamtKreditorBooker.book(v.tx, v.eingangsrechnung!);
        break;
      case CamtVorschlagTyp.ausgabe:
        await CamtAusgabeBooker.book(v.tx, v.vorlage!, steuer: steuer);
        break;
      case CamtVorschlagTyp.heineken:
        // Zwischen Vorschlag und Bestätigung kann der Status gewechselt
        // haben (z. B. im Detail auf «gesendet» zurückgesetzt) — frisch
        // lesen, sonst ginge eine nicht freigegebene Rechnung auf «bezahlt».
        final frisch =
            await RechnungRepository.getById(v.heinekenRechnung!.id);
        final sperre = heinekenSperrgrund(frisch);
        if (sperre != null) throw HeinekenZahlungGesperrt(sperre);
        // Buchung + «bezahlt» + camt-Schlüssel atomar (ZahlungKern, Runde 3);
        // die DB prüft die Sperren ein zweites Mal unter Zeilensperre.
        await HeinekenBuchungService.createZahlungseingang(frisch!,
            datum: v.tx.bookingDate, camtTxKey: v.tx.txKey);
        break;
    }
    // Ein evtl. offener Prüflisten-Eintrag derselben Transaktion (aus einem
    // früheren Import, als noch kein Treffer möglich war) ist damit erledigt.
    await CamtPrueflisteRepository.deleteByTxKey(v.tx.txKey);
  }

  /// Schreibt ungetroffene Transaktionen in die Prüfliste (manuell zu klären).
  static Future<void> zuPruefliste(List<CamtTransaction> txs) async {
    for (final tx in txs) {
      final kat = CamtKlassifizierer.kategorie(tx, betriebErkannt: false);
      await _zurPruefliste(tx, kat);
    }
  }

  static Future<void> _zurPruefliste(CamtTransaction tx, TxKategorie kat,
      {String? vorschlagBetrieb}) async {
    await CamtPrueflisteRepository.insert(CamtPrueflisteEintrag(
      txKey: tx.txKey,
      bookingDatum: tx.bookingDate,
      betrag: tx.amount,
      istGutschrift: tx.isCredit,
      parteiName: tx.partyName,
      parteiIban: tx.partyIban,
      belegRef: tx.accountServiceRef,
      referenz: tx.strukturierteReferenz ?? tx.remittanceInfo,
      kategorie: kat.name,
      vorschlag: vorschlagBetrieb != null ? {'betrieb': vorschlagBetrieb} : null,
    ));
  }
}
