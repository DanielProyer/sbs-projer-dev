import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_rechnungsadresse_mapper.dart';
import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/core/util/guthaben_verrechnung.dart';
import 'package:sbs_projer_app/services/rechnung/zahlung_kern.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/repositories/guthaben_repository.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/models/rechnungs_position.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_faktor.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';

class RechnungService {
  static const _invoiceRechnungsstellungen = [
    'rechnung_mail',
    'rechnung_post',
    'rechnung_tresen',
  ];

  /// Rechnet den Bruttobetrag aus, den [createFromReinigung] für diese
  /// Reinigung erzeugen würde — ohne etwas zu schreiben. Nutzt exakt dieselben
  /// Schritte, damit eine Vorschau nicht lügen kann.
  static Future<double> vorschauBrutto(ReinigungLocal reinigung) async {
    final mwst = await mwstAusPreisliste(reinigung.datum);
    return bruttoAusReinigung(reinigung, mwst);
  }

  /// Reiner Kern von [vorschauBrutto] und [createFromReinigung]: Brutto der
  /// Kundenrechnung einer Reinigung beim Satz [mwst], auf 5 Rappen.
  static double bruttoAusReinigung(ReinigungLocal reinigung, MwstAngabe mwst) =>
      bruttoKundenrechnung(
          _nettoSumme(buildPositionen(reinigung, mwst)), mwst.faktor);

  /// Kundenguthaben (Konto 2030), das auf eine neue Rechnung dieses Betriebs
  /// verrechnet wird: min(Guthaben, Brutto), auf 5 Rappen.
  ///
  /// **Wirft nie.** Eine Rechnung darf nicht am Guthaben scheitern — schlägt
  /// das Laden fehl, wird nichts verrechnet (Guthaben bleibt stehen).
  static Future<double> guthabenFuerNeueRechnung(
    String? betriebId,
    double brutto,
  ) async {
    if (betriebId == null || betriebId.isEmpty || brutto <= 0) return 0;
    try {
      final guthaben = await GuthabenRepository.offenesGuthaben(betriebId);
      return guthabenAbzug(guthaben: guthaben, brutto: brutto);
    } catch (e) {
      debugPrint('Kundenguthaben nicht geladen (nicht verrechnet): $e');
      return 0;
    }
  }

  /// Ganz durch Guthaben gedeckte Rechnung (zu zahlen = 0, Review I2):
  /// sofort Soll 2030 / Haben 1100 buchen und die Rechnung bezahlt setzen
  /// (`zahlung_betrag` 0, Eingang = Rechnungsdatum). Sonst stünde sie mit
  /// 0.00 im Mahnlauf, und das Guthaben bliebe bis zu einem Zahlungseingang
  /// reserviert, der nie kommt.
  ///
  /// **Wirft nie** (wie [guthabenFuerNeueRechnung]) — scheitert es, bleibt
  /// die Rechnung offen und erscheint im Mahnlauf unter «Mit Guthaben
  /// verrechnet — manuell prüfen». Gibt die (ggf. bezahlte) Rechnung zurück.
  static Future<Rechnung> guthabenVollVerrechnen(Rechnung rechnung) async {
    if (!istVollMitGuthabenGedeckt(rechnung)) return rechnung;
    try {
      // Verrechnung 2030/1100 + «bezahlt» atomar (ZahlungKern, Runde 3) —
      // vorher zwei Schritte: brach der zweite ab, war das Guthaben
      // verbraucht und die Rechnung trotzdem offen.
      await ZahlungKern.erfassen(
        rechnungen: [rechnung],
        betrag: 0,
        datum: rechnung.rechnungsdatum,
        weg: ZahlungWeg.verrechnung,
      );
      return (await RechnungRepository.getById(rechnung.id)) ?? rechnung;
    } catch (e) {
      debugPrint('Guthaben-Vollverrechnung fehlgeschlagen '
          '(${rechnung.rechnungsnummer}): $e');
      return rechnung;
    }
  }

  static double _nettoSumme(List<Map<String, dynamic>> positionen) {
    var netto = 0.0;
    for (final p in positionen) {
      netto += (p['betrag_netto'] as double);
    }
    return _round2(netto);
  }

  /// Erstellt eine Kundenrechnung aus einer abgeschlossenen Reinigung.
  /// Gibt null zurück wenn der Betrieb keine Rechnung benötigt.
  static Future<Rechnung?> createFromReinigung(
    ReinigungLocal reinigung,
    BetriebLocal betrieb,
  ) async {
    final art = resolveZahlungsart(reinigung.zahlungsart, betrieb.rechnungsstellung);
    if (!_invoiceRechnungsstellungen.contains(art)) {
      return null;
    }

    // Keine Rechnung bei Kulanz oder Heineken-Monteur
    if (reinigung.istKulanz || reinigung.istHeinekenMonteur) {
      return null;
    }

    try {
      // 0. MwSt-Satz dieses Datums — pro Aufruf, nie aus einem Vorlauf
      final mwstSatz = await mwstAusPreisliste(reinigung.datum);

      // 1. Rechnungsnummer bauen
      final nr = (betrieb.betriebNr ?? '0000').padLeft(4, '0');
      final d = reinigung.datum;
      final rechnungsnummer =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}-$nr';

      // 2. Positionen aufbauen
      final positionen = buildPositionen(reinigung, mwstSatz);
      // Kundenrechnungen sind IMMER auf 5 Rappen gerundet (nur die
      // Heineken-Monatsrechnung ist ungerundet — die entsteht woanders).
      // Zuerst das Brutto runden, dann die MwSt als Differenz ableiten, damit
      // Netto + MwSt exakt das Brutto ergibt. Dieselben Aufrufe wie in
      // [vorschauBrutto] — sonst könnte die Vorschau etwas anderes zeigen als
      // am Ende gebucht wird.
      final netto = _nettoSumme(positionen);
      final brutto = bruttoKundenrechnung(netto, mwstSatz.faktor);
      final mwst = _round2(brutto - netto);
      final guthaben =
          await guthabenFuerNeueRechnung(betrieb.serverId, brutto);

      // 3. Rechnung erstellen
      final angelegt = await RechnungRepository.create({
        'rechnungsnummer': rechnungsnummer,
        'rechnungstyp': 'kundenrechnung',
        'betrieb_id': betrieb.serverId,
        'rechnungsdatum': d.toIso8601String().split('T').first,
        'faelligkeitsdatum': d
            .add(const Duration(days: 30))
            .toIso8601String()
            .split('T')
            .first,
        'betrag_netto': netto,
        'mwst_betrag': mwst,
        'betrag_brutto': brutto,
        'guthaben_verrechnet': guthaben,
        'zahlungsstatus': 'offen',
        'versandart': art,
      });
      // Nichts zu zahlen? Dann sofort verrechnen und bezahlt setzen.
      final rechnung = await guthabenVollVerrechnen(angelegt);

      // 4. Positionen mit rechnung_id erstellen
      for (final p in positionen) {
        p['rechnung_id'] = rechnung.id;
      }
      final createdPositionen =
          await RechnungsPositionRepository.createAll(positionen);

      // 5.–7. PDF erzeugen und ablegen. Schlägt das fehl, bleibt die Rechnung
      // trotzdem bestehen — sie ist der Geschäftsvorfall, das PDF nur seine
      // Darstellung. Der Aufrufer erfährt es über `pdfErzeugenUndAblegen`
      // bzw. beim nächsten Nachholen (siehe RechnungNachholPlan).
      await pdfErzeugenUndAblegen(
        rechnung,
        betrieb,
        positionen: createdPositionen,
      );

      debugPrint('Rechnung $rechnungsnummer erstellt');
      return rechnung;
    } catch (e) {
      debugPrint('RechnungService.createFromReinigung fehlgeschlagen: $e');
      rethrow;
    }
  }

  /// Erzeugt das Rechnungs-PDF, legt es im Storage ab und setzt `pdf_url`.
  ///
  /// **Wirft bewusst nicht.** Ein abgebrochener Upload darf weder die Rechnung
  /// noch die Buchung noch den Übergabevermerk am Tresen verhindern — genau
  /// das passierte am 01.09.2026: Die Rechnung stand, die Buchung stand, aber
  /// weil der Upload eine Exception warf, blieb `uebergeben_am` leer.
  ///
  /// Gibt zurück, ob das PDF danach vorliegt.
  static Future<bool> pdfErzeugenUndAblegen(
    Rechnung rechnung,
    BetriebLocal betrieb, {
    List<RechnungsPosition>? positionen,
  }) async {
    try {
      final pos = positionen ??
          await RechnungsPositionRepository.getByRechnung(rechnung.id);

      BetriebRechnungsadresse? ra;
      final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(
          betrieb.serverId ?? betrieb.routeId);
      if (raLocal != null) {
        ra = BetriebRechnungsadresseMapper.toDto(raLocal,
            betriebId: betrieb.serverId ?? '');
      }

      final geschaeft = await GeschaeftRepository.get();
      final pdfBytes = await RechnungPdfService.generate(
        rechnung: rechnung,
        positionen: pos,
        betrieb: betrieb,
        rechnungsadresse: ra,
        firmaName: geschaeft.firma,
        firmaStrasse: geschaeft.adresseStrasse,
        firmaPlzOrt: geschaeft.adressePlzOrt,
        firmaMwst: geschaeft.mwstZeile,
        geschaeft: geschaeft,
      );
      await RechnungPdfStorage.uploadPdf(rechnung.id, pdfBytes);

      final signedUrl = await RechnungPdfStorage.getSignedUrl(rechnung.id);
      await RechnungRepository.update(rechnung.id, {'pdf_url': signedUrl});
      return true;
    } catch (e) {
      debugPrint('[Rechnung-PDF] Ablage fehlgeschlagen (${rechnung.id}): $e');
      return false;
    }
  }

  /// Baut Rechnungspositionen aus einer Reinigung.
  /// Wenn preisBrutto direkt gesetzt ist (OCR/manuell) und kein Grundtarif vorhanden,
  /// wird eine einzige Position "Reinigung gemäss Protokoll" erstellt.
  ///
  /// Rein (kein I/O) — der Satz [mwst] kommt vom Aufrufer, damit jede
  /// Reinigung mit dem Satz ihres eigenen Datums rechnet.
  static List<Map<String, dynamic>> buildPositionen(
      ReinigungLocal reinigung, MwstAngabe mwst) {
    final positionen = <Map<String, dynamic>>[];
    int pos = 0;

    // Neuer Workflow: Preis direkt aus Protokoll-Foto (OCR)
    final hatGrundtarif =
        reinigung.preisGrundtarif != null && reinigung.preisGrundtarif! > 0;

    if (!hatGrundtarif &&
        reinigung.preisBrutto != null &&
        reinigung.preisBrutto! > 0) {
      // Einzige Position: Netto aus Brutto zurückrechnen
      final brutto = reinigung.preisBrutto!;
      final netto = _round2(brutto / (1 + mwst.faktor));
      pos++;
      positionen.add(_position(
        mwst: mwst,
        pos: pos,
        beschreibung: 'Reinigung gemäss Protokoll',
        netto: netto,
        serviceTyp: 'reinigung',
        serviceId: reinigung.serverId,
      ));
      return positionen;
    }

    // Bisheriger Workflow: Detaillierte Preiskalkulation
    if (hatGrundtarif) {
      pos++;
      final netto = reinigung.preisGrundtarif!;
      positionen.add(_position(
        mwst: mwst,
        pos: pos,
        beschreibung: 'Grundtarif ${_serviceTypLabel(reinigung.serviceTyp)}',
        netto: netto,
        serviceTyp: 'reinigung',
        serviceId: reinigung.serverId,
      ));
    }

    // Weitere zusätzliche Leitungen (Eigen) — direkt nach Grundtarif
    if (reinigung.anzahlHaehneEigen > 0) {
      pos++;
      final netto = reinigung.anzahlHaehneEigen * 18.0;
      positionen.add(_position(
        mwst: mwst,
        pos: pos,
        beschreibung:
            'Weitere zusätzliche Leitungen (×${reinigung.anzahlHaehneEigen})',
        netto: netto,
      ));
    }

    // Zusätzliche Hähne Orion
    if (reinigung.anzahlHaehneOrion > 0) {
      pos++;
      final netto = reinigung.anzahlHaehneOrion * 18.0;
      positionen.add(_position(
        mwst: mwst,
        pos: pos,
        beschreibung:
            'Zusätzliche Hähne Orion (×${reinigung.anzahlHaehneOrion})',
        netto: netto,
      ));
    }

    // Zusätzliche Hähne fremd
    if (reinigung.anzahlHaehneFremd > 0) {
      pos++;
      final netto = reinigung.anzahlHaehneFremd * 23.0;
      positionen.add(_position(
        mwst: mwst,
        pos: pos,
        beschreibung:
            'Zusätzliche Hähne fremd (×${reinigung.anzahlHaehneFremd})',
        netto: netto,
      ));
    }

    // Zusätzliche Hähne Wein
    if (reinigung.anzahlHaehneWein > 0) {
      pos++;
      final netto = reinigung.anzahlHaehneWein * 23.0;
      positionen.add(_position(
        mwst: mwst,
        pos: pos,
        beschreibung:
            'Zusätzliche Hähne Wein (×${reinigung.anzahlHaehneWein})',
        netto: netto,
      ));
    }

    // Zusätzliche Hähne anderer Standort
    if (reinigung.anzahlHaehneAndererStandort > 0) {
      pos++;
      final netto = reinigung.anzahlHaehneAndererStandort * 30.0;
      positionen.add(_position(
        mwst: mwst,
        pos: pos,
        beschreibung:
            'Zusätzliche Hähne anderer Standort (×${reinigung.anzahlHaehneAndererStandort})',
        netto: netto,
      ));
    }

    // Bergkundenzuschlag wird Heineken verrechnet, NICHT dem Kunden

    return positionen;
  }

  static Map<String, dynamic> _position({
    required MwstAngabe mwst,
    required int pos,
    required String beschreibung,
    required double netto,
    String? serviceTyp,
    String? serviceId,
  }) {
    final mwstBetrag = _round2(netto * mwst.faktor);
    return {
      'position': pos,
      'beschreibung': beschreibung,
      'betrag_netto': _round2(netto),
      'mwst_satz': mwst.prozent,
      'mwst_betrag': mwstBetrag,
      'betrag_brutto': _round2(netto + mwstBetrag),
      if (serviceTyp != null) 'service_typ': serviceTyp,
      if (serviceId != null) 'service_id': serviceId,
    };
  }

  static String _serviceTypLabel(String? typ) {
    switch (typ) {
      case 'reinigung_bier':
        return 'Eigen';
      case 'reinigung_orion':
        return 'Eigen (Orion)';
      case 'heigenie':
        return 'Heigenie';
      case 'reinigung_fremd':
        return 'Fremd';
      case 'wein':
        return 'Wein';
      default:
        return typ ?? '';
    }
  }

  static double _round2(double v) =>
      (v * 100).roundToDouble() / 100;
}
