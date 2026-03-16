import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class RechnungService {
  static const _invoiceRechnungsstellungen = [
    'rechnung_mail',
    'rechnung_post',
    'rechnung_tresen',
  ];

  /// Erstellt eine Kundenrechnung aus einer abgeschlossenen Reinigung.
  /// Gibt null zurück wenn der Betrieb keine Rechnung benötigt.
  static Future<Rechnung?> createFromReinigung(
    ReinigungLocal reinigung,
    BetriebLocal betrieb,
  ) async {
    if (!_invoiceRechnungsstellungen.contains(betrieb.rechnungsstellung)) {
      return null;
    }

    try {
      // 1. Rechnungsnummer bauen
      final nr = (betrieb.betriebNr ?? '0000').padLeft(4, '0');
      final d = reinigung.datum;
      final rechnungsnummer =
          '${nr}_${d.year}_${d.month.toString().padLeft(2, '0')}_${d.day.toString().padLeft(2, '0')}';

      // 2. Positionen aufbauen
      final positionen = _buildPositionen(reinigung);
      double netto = 0;
      for (final p in positionen) {
        netto += (p['betrag_netto'] as double);
      }
      final mwst = _round2(netto * 0.081);
      final brutto = _round2(netto + mwst);

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
        'versandart': betrieb.rechnungsstellung,
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
      final pdfBytes = await RechnungPdfService.generate(
        rechnung: rechnung,
        positionen: createdPositionen,
        betrieb: betrieb,
        rechnungsadresse: ra,
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
  static List<Map<String, dynamic>> _buildPositionen(
      ReinigungLocal reinigung) {
    final positionen = <Map<String, dynamic>>[];
    int pos = 0;

    // Grundtarif (immer)
    if (reinigung.preisGrundtarif != null && reinigung.preisGrundtarif! > 0) {
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

    // Weitere zusätzliche Leitungen
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

    // Bergkunden-Zuschlag
    if (reinigung.istBergkunde &&
        reinigung.bergkundenZuschlag != null &&
        reinigung.bergkundenZuschlag! > 0) {
      pos++;
      positionen.add(_position(
        pos: pos,
        beschreibung: 'Bergkunden-Zuschlag',
        netto: reinigung.bergkundenZuschlag!,
      ));
    }

    return positionen;
  }

  static Map<String, dynamic> _position({
    required int pos,
    required String beschreibung,
    required double netto,
    String? serviceTyp,
    String? serviceId,
  }) {
    final mwst = _round2(netto * 0.081);
    return {
      'position': pos,
      'beschreibung': beschreibung,
      'betrag_netto': _round2(netto),
      'mwst_satz': 8.10,
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
