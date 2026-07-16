import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';

class RechnungService {
  static double _mwstFaktor = 0.081;
  static double _mwstSatzProzent = 8.10;

  static Future<void> _loadMwst({DateTime? datum}) async {
    final preis = await PreisRepository.getAktuell(datum: datum);
    if (preis != null) {
      _mwstFaktor = preis.mwstFaktor;
      _mwstSatzProzent = preis.mwstSatz;
    }
  }

  static const _invoiceRechnungsstellungen = [
    'rechnung_mail',
    'rechnung_post',
    'rechnung_tresen',
  ];

  /// Löst diese Rechnungsstellung eine Kundenrechnung pro Reinigung aus?
  /// (`heineken` läuft über den Monatslauf, `barzahlung`/`jahresrechnung`
  /// bekommen keine Einzelrechnung.)
  static bool brauchtRechnung(String? rechnungsstellung) =>
      _invoiceRechnungsstellungen.contains(rechnungsstellung);

  /// Rechnet den Bruttobetrag aus, den [createFromReinigung] für diese
  /// Reinigung erzeugen würde — ohne etwas zu schreiben. Nutzt exakt dieselben
  /// Schritte, damit eine Vorschau nicht lügen kann.
  static Future<double> vorschauBrutto(ReinigungLocal reinigung) async {
    await _loadMwst(datum: reinigung.datum);
    return bruttoKundenrechnung(_nettoSumme(_buildPositionen(reinigung)),
        _mwstFaktor);
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
      // 0. MwSt-Satz laden
      await _loadMwst(datum: reinigung.datum);

      // 1. Rechnungsnummer bauen
      final nr = (betrieb.betriebNr ?? '0000').padLeft(4, '0');
      final d = reinigung.datum;
      final rechnungsnummer =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}-$nr';

      // 2. Positionen aufbauen
      final positionen = _buildPositionen(reinigung);
      // Kundenrechnungen sind IMMER auf 5 Rappen gerundet (nur die
      // Heineken-Monatsrechnung ist ungerundet — die entsteht woanders).
      // Zuerst das Brutto runden, dann die MwSt als Differenz ableiten, damit
      // Netto + MwSt exakt das Brutto ergibt. Dieselben Aufrufe wie in
      // [vorschauBrutto] — sonst könnte die Vorschau etwas anderes zeigen als
      // am Ende gebucht wird.
      final netto = _nettoSumme(positionen);
      final brutto = bruttoKundenrechnung(netto, _mwstFaktor);
      final mwst = _round2(brutto - netto);

      // 3. Rechnung erstellen
      final rechnung = await RechnungRepository.create({
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
        'zahlungsstatus': 'offen',
        'versandart': art,
      });

      // 4. Positionen mit rechnung_id erstellen
      for (final p in positionen) {
        p['rechnung_id'] = rechnung.id;
      }
      final createdPositionen =
          await RechnungsPositionRepository.createAll(positionen);

      // 5. Rechnungsadresse laden
      BetriebRechnungsadresse? ra;
      final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(
          betrieb.serverId ?? betrieb.routeId);
      if (raLocal != null) {
        ra = BetriebRechnungsadresse(
          id: raLocal.serverId ?? '',
          userId: raLocal.userId,
          betriebId: betrieb.serverId ?? '',
          firma: raLocal.firma,
          vorname: raLocal.vorname,
          nachname: raLocal.nachname,
          strasse: raLocal.strasse,
          nr: raLocal.nr,
          plz: raLocal.plz,
          ort: raLocal.ort,
          email: raLocal.email,
          notizen: raLocal.notizen,
        );
      }

      // 6. PDF generieren und hochladen
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
      await RechnungPdfStorage.uploadPdf(rechnung.id, pdfBytes);

      // 7. pdf_url setzen
      final signedUrl = await RechnungPdfStorage.getSignedUrl(rechnung.id);
      await RechnungRepository.update(rechnung.id, {'pdf_url': signedUrl});

      debugPrint('Rechnung $rechnungsnummer erstellt');
      return rechnung;
    } catch (e) {
      debugPrint('RechnungService.createFromReinigung fehlgeschlagen: $e');
      rethrow;
    }
  }

  /// Baut Rechnungspositionen aus einer Reinigung.
  /// Wenn preisBrutto direkt gesetzt ist (OCR/manuell) und kein Grundtarif vorhanden,
  /// wird eine einzige Position "Reinigung gemäss Protokoll" erstellt.
  static List<Map<String, dynamic>> _buildPositionen(
      ReinigungLocal reinigung) {
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
      final netto = _round2(brutto / (1 + _mwstFaktor));
      pos++;
      positionen.add(_position(
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
    required int pos,
    required String beschreibung,
    required double netto,
    String? serviceTyp,
    String? serviceId,
  }) {
    final mwst = _round2(netto * _mwstFaktor);
    return {
      'position': pos,
      'beschreibung': beschreibung,
      'betrag_netto': _round2(netto),
      'mwst_satz': _mwstSatzProzent,
      'mwst_betrag': mwst,
      'betrag_brutto': _round2(netto + mwst),
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
