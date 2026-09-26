import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_rechnungsadresse_mapper.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_faktor.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/pdf/protokolle_pdf_service.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';

class JahresrechnungService {
  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  /// MwSt-Satz einer Jahresrechnung: der am Rechnungsdatum (31.12.) gültige.
  static Future<MwstAngabe> mwstFuerJahr(int jahr) =>
      mwstAusPreisliste(DateTime(jahr, 12, 31));

  /// Berechnet den tatsächlichen Netto-Betrag einer Reinigung aus allen Komponenten.
  /// preis_netto in der DB enthält manchmal nur den Grundtarif — deshalb
  /// berechnen wir hier immer aus Grundtarif + Zusatz-Hähne + Bergkunden-Zuschlag.
  /// [mwstFaktor] braucht nur die Brutto-Rückrechnung (OCR-Reinigungen).
  static double calcNetto(ReinigungLocal r, double mwstFaktor) {
    // OCR/direkt: Netto aus Brutto zurückrechnen
    final hatGrundtarif = r.preisGrundtarif != null && r.preisGrundtarif! > 0;
    if (!hatGrundtarif && r.preisBrutto != null && r.preisBrutto! > 0) {
      return _round2(r.preisBrutto! / (1 + mwstFaktor));
    }

    double netto = 0;
    if (hatGrundtarif) netto += r.preisGrundtarif!;
    netto += r.anzahlHaehneEigen * 18.0;
    netto += r.anzahlHaehneOrion * 18.0;
    netto += r.anzahlHaehneFremd * 23.0;
    netto += r.anzahlHaehneWein * 23.0;
    netto += r.anzahlHaehneAndererStandort * 30.0;
    // Bergkundenzuschlag wird Heineken verrechnet, NICHT dem Kunden
    return _round2(netto);
  }

  /// Sammelt alle noch nicht abgerechneten Reinigungen eines Betriebs im Jahr.
  /// Gibt nur Reinigungen zurück, die:
  /// - status == 'abgeschlossen'
  /// - berechneter Netto > 0
  /// - nicht Kulanz, nicht Heineken-Monteur
  /// - noch nicht in rechnungs_positionen enthalten
  static Future<List<ReinigungLocal>> sammleReinigungen(
    String betriebId,
    int jahr,
  ) async {
    // Alle Reinigungen des Betriebs laden
    final alle = await ReinigungRepository.getByBetrieb(betriebId);

    // Im Jahr filtern, abgeschlossen, Netto > 0, keine Kulanz/Heineken.
    // Für «Netto > 0» ist der Satz ohne Belang (positives Brutto ergibt bei
    // jedem Satz ein positives Netto) — deshalb hier kein Preislisten-Abruf.
    final kandidaten = alle.where((r) {
      if (r.status != 'abgeschlossen') return false;
      if (r.datum.year != jahr) return false;
      if (r.istKulanz || r.istHeinekenMonteur) return false;
      if (calcNetto(r, kMwstFaktorFallback) <= 0) return false;
      return true;
    }).toList();

    if (kandidaten.isEmpty) return [];

    // Bereits abgerechnete Reinigungen ausfiltern (via rechnungs_positionen)
    final bereitsAbgerechnet = await _getAbgerechneteServiceIds(betriebId);
    return kandidaten
        .where((r) => !bereitsAbgerechnet.contains(r.serverId))
        .toList()
      ..sort((a, b) => a.datum.compareTo(b.datum));
  }

  /// Prüft welche Reinigungs-IDs bereits als Position in einer Jahresrechnung existieren.
  static Future<Set<String>> _getAbgerechneteServiceIds(
    String betriebId,
  ) async {
    try {
      final rows = await SupabaseService.client
          .from('rechnungs_positionen')
          .select('service_id, rechnung_id')
          .eq('service_typ', 'reinigung')
          .not('service_id', 'is', null);

      // Nur Positionen von Jahresrechnungen dieses Betriebs
      final rechnungIds = <String>{};
      final rechnungen = await SupabaseService.client
          .from('rechnungen')
          .select('id')
          .eq('betrieb_id', betriebId)
          .eq('rechnungstyp', 'jahresrechnung');
      for (final r in rechnungen) {
        rechnungIds.add(r['id'] as String);
      }

      final ids = <String>{};
      for (final row in rows) {
        final rId = row['rechnung_id'] as String?;
        final sId = row['service_id'] as String?;
        if (rId != null && sId != null && rechnungIds.contains(rId)) {
          ids.add(sId);
        }
      }
      return ids;
    } catch (e) {
      debugPrint('JahresrechnungService: Fehler bei Duplikat-Check: $e');
      return {};
    }
  }

  /// Positionen und Totale einer Jahresrechnung beim Satz [mwst] — rein,
  /// ohne I/O (eine Position pro Reinigung).
  static ({
    List<Map<String, dynamic>> positionen,
    double netto,
    double mwst,
    double brutto,
  }) berechnePositionen(List<ReinigungLocal> reinigungen, MwstAngabe mwst) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final positionen = <Map<String, dynamic>>[];
    double totalNetto = 0;

    for (int i = 0; i < reinigungen.length; i++) {
      final r = reinigungen[i];
      final netto = calcNetto(r, mwst.faktor);
      final mwstBetrag = _round2(netto * mwst.faktor);
      totalNetto += netto;

      positionen.add({
        'position': i + 1,
        'beschreibung': 'Reinigung ${dateFormat.format(r.datum)}',
        'betrag_netto': netto,
        'mwst_satz': mwst.prozent,
        'mwst_betrag': mwstBetrag,
        'betrag_brutto': _round2(netto + mwstBetrag),
        'service_typ': 'reinigung',
        'service_id': r.serverId,
      });
    }

    // Auch die Jahresrechnung ist eine Kundenrechnung → 5 Rappen. Die MwSt wird
    // aus dem gerundeten Brutto abgeleitet, sonst ergibt Netto + MwSt nicht
    // exakt das Brutto (Differenz bis 1 Rappen).
    final bruttoTotal = bruttoKundenrechnung(totalNetto, mwst.faktor);
    return (
      positionen: positionen,
      netto: totalNetto,
      mwst: _round2(bruttoTotal - totalNetto),
      brutto: bruttoTotal,
    );
  }

  /// Erstellt eine Jahresrechnung für einen Betrieb.
  /// Gibt die erstellte Rechnung zurück.
  static Future<Rechnung> erstelleJahresrechnung({
    required BetriebLocal betrieb,
    required List<ReinigungLocal> reinigungen,
    required int jahr,
  }) async {
    if (reinigungen.isEmpty) {
      throw Exception('Keine Reinigungen zum Abrechnen vorhanden');
    }

    // MwSt-Satz des Rechnungsdatums — pro Aufruf, nie aus einem Vorlauf
    final mwstSatz = await mwstFuerJahr(jahr);

    final betriebNr = (betrieb.betriebNr ?? '0000').padLeft(4, '0');
    final rechnungsnummer = '$jahr-JR-$betriebNr';

    final berechnet = berechnePositionen(reinigungen, mwstSatz);
    final positionen = berechnet.positionen;
    final totalNetto = berechnet.netto;
    final bruttoTotal = berechnet.brutto;
    final mwstTotal = berechnet.mwst;
    // Offenes Kundenguthaben (2030) verrechnen — wirft nie.
    final guthaben = await RechnungService.guthabenFuerNeueRechnung(
      betrieb.serverId,
      bruttoTotal,
    );

    // Rechnungsdatum: 31.12. des Jahres
    final rechnungsdatum = DateTime(jahr, 12, 31);
    // Fälligkeitsdatum: 30.01. des Folgejahres
    final faelligkeitsdatum = DateTime(jahr + 1, 1, 30);

    // Rechnung in DB erstellen
    final angelegt = await RechnungRepository.create({
      'rechnungsnummer': rechnungsnummer,
      'rechnungstyp': 'jahresrechnung',
      'betrieb_id': betrieb.serverId,
      'rechnungsdatum': rechnungsdatum.toIso8601String().split('T').first,
      'faelligkeitsdatum': faelligkeitsdatum.toIso8601String().split('T').first,
      'betrag_netto': totalNetto,
      'mwst_betrag': mwstTotal,
      'betrag_brutto': bruttoTotal,
      'guthaben_verrechnet': guthaben,
      'zahlungsstatus': 'offen',
      'versandart': 'jahresrechnung',
    });
    // Nichts zu zahlen (Guthaben deckt alles)? Sofort verrechnen + bezahlt.
    final rechnung = await RechnungService.guthabenVollVerrechnen(angelegt);

    // Positionen erstellen
    for (final p in positionen) {
      p['rechnung_id'] = rechnung.id;
    }
    final createdPositionen = await RechnungsPositionRepository.createAll(
      positionen,
    );

    // Rechnungsadresse laden
    BetriebRechnungsadresse? ra;
    final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(
      betrieb.serverId ?? betrieb.routeId,
    );
    if (raLocal != null) {
      ra = BetriebRechnungsadresseMapper.toDto(
        raLocal,
        betriebId: betrieb.serverId ?? '',
      );
    }

    // 1. Rechnungs-PDF generieren (nur Rechnung, ohne Protokolle)
    final geschaeft = await GeschaeftRepository.get();
    final pdfBytes = await RechnungPdfService.generate(
      rechnung: rechnung,
      positionen: createdPositionen,
      betrieb: betrieb,
      rechnungsadresse: ra,
      firmaName: geschaeft.firma,
      firmaStrasse: geschaeft.adresseStrasse,
      firmaPlzOrt: geschaeft.adressePlzOrt,
      firmaMwst: geschaeft.mwstZeile,
    );

    // Rechnungs-PDF hochladen
    await RechnungPdfStorage.uploadPdf(rechnung.id, pdfBytes);
    final signedUrl = await RechnungPdfStorage.getSignedUrl(rechnung.id);
    await RechnungRepository.update(rechnung.id, {'pdf_url': signedUrl});

    // 2. Protokolle-PDF separat generieren (alle Reinigungsprotokolle)
    int protokollCount = 0;
    try {
      final protokollBilder = await ProtokollePdfService.ladeBilder(
        reinigungen,
      );
      if (protokollBilder.isNotEmpty) {
        final protokollPdf = await ProtokollePdfService.buendel(
          protokollBilder,
          betrieb.name,
          jahr,
        );
        await RechnungPdfStorage.uploadProtokollePdf(rechnung.id, protokollPdf);
        protokollCount = protokollBilder.length;
      }
    } catch (e) {
      debugPrint('Protokolle-PDF Fehler (nicht kritisch): $e');
    }

    debugPrint(
      'Jahresrechnung $rechnungsnummer erstellt: '
      '${reinigungen.length} Reinigungen, $protokollCount Protokolle, Total CHF $bruttoTotal',
    );
    return rechnung;
  }
}
