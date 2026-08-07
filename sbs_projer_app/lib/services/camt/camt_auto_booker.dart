import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/models/camt_regel.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/heineken_buchung_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/zahlungsdifferenz_service.dart';
import 'package:sbs_projer_app/services/camt/camt_ausgabe_booker.dart';
import 'package:sbs_projer_app/services/camt/camt_betrieb_matcher.dart';
import 'package:sbs_projer_app/services/camt/camt_kreditor_booker.dart';
import 'package:sbs_projer_app/services/camt/camt_klassifizierer.dart';
import 'package:sbs_projer_app/services/camt/camt_stichtag.dart';
import 'package:sbs_projer_app/services/camt/camt_vorschlag.dart';
import 'package:sbs_projer_app/services/camt/heineken_matcher.dart';
import 'package:sbs_projer_app/services/camt/rechnung_matcher.dart';
import 'package:sbs_projer_app/services/camt/regel_matcher.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/kreditoren_abgleich_service.dart';

class AutoBookerResult {
  int gebucht = 0, pruefliste = 0, uebersprungen = 0;
  final List<String> fehler = [];
}

class CamtAutoBooker {
  /// Verarbeitet alle Transaktionen ab Stichtag. Eindeutige → Buchung,
  /// Unklare → Prüfliste. Idempotent über txKey.
  static Future<AutoBookerResult> run({
    required List<CamtTransaction> transactions,
    required List<Map<String, String>> betriebe,
    required List<Rechnung> offeneRechnungen,
    required List<Rechnung> heinekenRechnungen,
    required Set<String> bereitsVerarbeitet,
    required List<CamtRegel> regeln,
    required Map<String, BuchungsVorlage> vorlagenById,
    List<Eingangsrechnung> offeneKreditoren = const [],
  }) async {
    final res = AutoBookerResult();
    final verbrauchteKreditoren = <String>{};

    for (final tx in transactions) {
      if (!CamtStichtag.istAutomatisierbar(tx.bookingDate)) {
        res.uebersprungen++;
        continue;
      }
      if (bereitsVerarbeitet.contains(tx.txKey)) {
        res.uebersprungen++;
        continue;
      }

      final match = CamtBetriebMatcher.findBestMatch(tx.partyName, betriebe);
      final betriebId = match?['id'];
      final kat = CamtKlassifizierer.kategorie(tx, betriebErkannt: betriebId != null);
      tx.kategorie = kat.name;
      final datumStr = tx.bookingDate.toIso8601String().split('T').first;

      try {
        switch (kat) {
          case TxKategorie.saldovortrag:
            res.uebersprungen++;
            break;

          case TxKategorie.kundenzahlung:
            final offen =
                offeneRechnungen.where((r) => r.betriebId == betriebId).toList();
            final m = RechnungMatcher.match(
                zahlbetrag: tx.amount, offeneRechnungen: offen);
            if (m.eindeutig) {
              final buchungen = await ZahlungsdifferenzService.verbuchenSammel(
                  rechnungen: m.rechnungen,
                  zahlungBetrag: tx.amount,
                  datum: tx.bookingDate);
              if (buchungen.isEmpty) {
                await _zurPrueflisteMitFehler(tx, kat,
                    'Zugeordnete Rechnung(en) bereits verbucht — bitte manuell prüfen');
                res.pruefliste++;
              } else {
                for (final b in buchungen) {
                  await BuchungRepository.setCamtTxKey(b.id, tx.txKey);
                }
                for (final r in m.rechnungen) {
                  await RechnungRepository.update(r.id, {
                    'zahlungsstatus': 'bezahlt',
                    'zahlung_eingegangen_am': datumStr,
                    'zahlung_betrag': r.betragBrutto,
                  });
                }
                res.gebucht++;
              }
            } else {
              await _zurPruefliste(tx, kat, vorschlagBetrieb: match?['name']);
              res.pruefliste++;
            }
            break;

          case TxKategorie.heinekenEingang:
            final hr = HeinekenMatcher.match(
                zahlbetrag: tx.amount, heinekenRechnungen: heinekenRechnungen);
            if (hr != null) {
              final b = await HeinekenBuchungService.createZahlungseingang(hr,
                  datum: tx.bookingDate);
              if (b == null) {
                await _zurPrueflisteMitFehler(tx, kat,
                    'Heineken-Rechnung bereits verbucht — bitte manuell prüfen');
                res.pruefliste++;
              } else {
                await BuchungRepository.setCamtTxKey(b.id, tx.txKey);
                await RechnungRepository.update(hr.id, {
                  'zahlungsstatus': 'bezahlt',
                  'zahlung_eingegangen_am': datumStr,
                  'zahlung_betrag': hr.betragBrutto,
                });
                res.gebucht++;
              }
            } else {
              await _zurPruefliste(tx, kat);
              res.pruefliste++;
            }
            break;

          case TxKategorie.bargeldEinzahlung:
          case TxKategorie.ausgabe:
            // TP-5: Kreditor-Abschluss VOR dem Ausgaben-Regelwerk (nur DBIT).
            if (!tx.isCredit) {
              final kandidaten = offeneKreditoren
                  .where((e) => !verbrauchteKreditoren.contains(e.id))
                  .toList();
              final e = KreditorenAbgleichService.match(tx, kandidaten);
              if (e != null) {
                await CamtKreditorBooker.book(tx, e);
                verbrauchteKreditoren.add(e.id);
                res.gebucht++;
                break;
              }
            }
            final vid = RegelMatcher.matchVorlageId(
              partyName: tx.partyName, partyIban: tx.partyIban,
              additionalInfo: tx.additionalInfo,
              remittanceInfo: tx.remittanceInfo, regeln: regeln);
            final vorlage = vid != null ? vorlagenById[vid] : null;
            if (vorlage != null) {
              await CamtAusgabeBooker.book(tx, vorlage);
              res.gebucht++;
            } else {
              await _zurPruefliste(tx, kat, vorschlagBetrieb: match?['name']);
              res.pruefliste++;
            }
            break;
          case TxKategorie.unbekannt:
            await _zurPruefliste(tx, kat, vorschlagBetrieb: match?['name']);
            res.pruefliste++;
            break;
        }
      } catch (e) {
        await _zurPrueflisteMitFehler(tx, kat, e.toString());
        res.pruefliste++;
        res.fehler.add('${tx.partyName ?? tx.txKey}: $e');
      }
    }
    return res;
  }

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
  static Future<void> bucheVorschlag(CamtVorschlag v) async {
    switch (v.typ) {
      case CamtVorschlagTyp.kreditor:
        await CamtKreditorBooker.book(v.tx, v.eingangsrechnung!);
        break;
      case CamtVorschlagTyp.ausgabe:
        await CamtAusgabeBooker.book(v.tx, v.vorlage!);
        break;
      case CamtVorschlagTyp.heineken:
        final b = await HeinekenBuchungService.createZahlungseingang(
            v.heinekenRechnung!,
            datum: v.tx.bookingDate);
        if (b != null) {
          await BuchungRepository.setCamtTxKey(b.id, v.tx.txKey);
          final datumStr = v.tx.bookingDate.toIso8601String().split('T').first;
          await RechnungRepository.update(v.heinekenRechnung!.id, {
            'zahlungsstatus': 'bezahlt',
            'zahlung_eingegangen_am': datumStr,
            'zahlung_betrag': v.heinekenRechnung!.betragBrutto,
          });
        }
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

  static Future<void> _zurPrueflisteMitFehler(
      CamtTransaction tx, TxKategorie kat, String fehler) async {
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
      fehlertext: fehler,
    ));
  }
}
