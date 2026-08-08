import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';

class JahresrechnungService {
  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  static double _mwstFaktor = 0.081;
  static double _mwstSatzProzent = 8.10;

  static Future<void> _loadMwst({DateTime? datum}) async {
    final preis = await PreisRepository.getAktuell(datum: datum);
    if (preis != null) {
      _mwstFaktor = preis.mwstFaktor;
      _mwstSatzProzent = preis.mwstSatz;
    }
  }

  /// Berechnet den tatsächlichen Netto-Betrag einer Reinigung aus allen Komponenten.
  /// preis_netto in der DB enthält manchmal nur den Grundtarif — deshalb
  /// berechnen wir hier immer aus Grundtarif + Zusatz-Hähne + Bergkunden-Zuschlag.
  static double calcNetto(ReinigungLocal r) {
    // OCR/direkt: Netto aus Brutto zurückrechnen
    final hatGrundtarif = r.preisGrundtarif != null && r.preisGrundtarif! > 0;
    if (!hatGrundtarif && r.preisBrutto != null && r.preisBrutto! > 0) {
      return _round2(r.preisBrutto! / (1 + _mwstFaktor));
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

    // Im Jahr filtern, abgeschlossen, Netto > 0, keine Kulanz/Heineken
    final kandidaten = alle.where((r) {
      if (r.status != 'abgeschlossen') return false;
      if (r.datum.year != jahr) return false;
      if (r.istKulanz || r.istHeinekenMonteur) return false;
      if (calcNetto(r) <= 0) return false;
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
      String betriebId) async {
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

    // MwSt-Satz laden
    await _loadMwst(datum: DateTime(jahr, 12, 31));

    final dateFormat = DateFormat('dd.MM.yyyy');
    final betriebNr = (betrieb.betriebNr ?? '0000').padLeft(4, '0');
    final rechnungsnummer = '$jahr-JR-$betriebNr';

    // Positionen aufbauen: Eine pro Reinigung
    final positionen = <Map<String, dynamic>>[];
    double totalNetto = 0;

    for (int i = 0; i < reinigungen.length; i++) {
      final r = reinigungen[i];
      final netto = calcNetto(r);
      final mwst = _round2(netto * _mwstFaktor);
      totalNetto += netto;

      positionen.add({
        'position': i + 1,
        'beschreibung': 'Reinigung ${dateFormat.format(r.datum)}',
        'betrag_netto': netto,
        'mwst_satz': _mwstSatzProzent,
        'mwst_betrag': mwst,
        'betrag_brutto': _round2(netto + mwst),
        'service_typ': 'reinigung',
        'service_id': r.serverId,
      });
    }

    // Auch die Jahresrechnung ist eine Kundenrechnung → 5 Rappen. Die MwSt wird
    // aus dem gerundeten Brutto abgeleitet, sonst ergibt Netto + MwSt nicht
    // exakt das Brutto (Differenz bis 1 Rappen).
    final bruttoTotal = bruttoKundenrechnung(totalNetto, _mwstFaktor);
    final mwstTotal = _round2(bruttoTotal - totalNetto);

    // Rechnungsdatum: 31.12. des Jahres
    final rechnungsdatum = DateTime(jahr, 12, 31);
    // Fälligkeitsdatum: 30.01. des Folgejahres
    final faelligkeitsdatum = DateTime(jahr + 1, 1, 30);

    // Rechnung in DB erstellen
    final rechnung = await RechnungRepository.create({
      'rechnungsnummer': rechnungsnummer,
      'rechnungstyp': 'jahresrechnung',
      'betrieb_id': betrieb.serverId,
      'rechnungsdatum': rechnungsdatum.toIso8601String().split('T').first,
      'faelligkeitsdatum': faelligkeitsdatum.toIso8601String().split('T').first,
      'betrag_netto': totalNetto,
      'mwst_betrag': mwstTotal,
      'betrag_brutto': bruttoTotal,
      'zahlungsstatus': 'offen',
      'versandart': 'jahresrechnung',
    });

    // Positionen erstellen
    for (final p in positionen) {
      p['rechnung_id'] = rechnung.id;
    }
    final createdPositionen =
        await RechnungsPositionRepository.createAll(positionen);

    // Rechnungsadresse laden
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
      final protokollBilder = await _ladeProtokollBilder(reinigungen);
      if (protokollBilder.isNotEmpty) {
        final protokollPdf = await _generiereProtokollePdf(
          protokollBilder,
          betrieb.name,
          jahr,
        );
        await RechnungPdfStorage.uploadProtokollePdf(
            rechnung.id, protokollPdf);
        protokollCount = protokollBilder.length;
      }
    } catch (e) {
      debugPrint('Protokolle-PDF Fehler (nicht kritisch): $e');
    }

    debugPrint('Jahresrechnung $rechnungsnummer erstellt: '
        '${reinigungen.length} Reinigungen, $protokollCount Protokolle, Total CHF $bruttoTotal');
    return rechnung;
  }

  /// Generiert ein separates PDF mit allen Reinigungsprotokollen.
  /// Jedes Protokollbild wird als eigene A4-Seite eingebettet.
  static Future<Uint8List> _generiereProtokollePdf(
    List<Uint8List> bilder,
    String betriebName,
    int jahr,
  ) async {
    final pdf = await pdfDokument();

    // Titelseite
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Reinigungsprotokolle',
                style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                betriebName,
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Jahr $jahr',
                style: const pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                '${bilder.length} Protokoll${bilder.length == 1 ? '' : 'e'}',
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    // Eine Seite pro Protokollbild
    for (int i = 0; i < bilder.length; i++) {
      try {
        final image = pw.MemoryImage(bilder[i]);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (context) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
        debugPrint('Protokoll $i/${bilder.length}: ${bilder[i].length} Bytes eingebettet');
      } catch (e) {
        debugPrint('Protokollbild $i konnte nicht eingebettet werden: $e');
      }
    }

    return pdf.save();
  }

  /// Lädt alle Reinigungsprotokolle als JPEG-Bilder.
  /// Strategie:
  /// 1. Versuche .jpg-Version direkt zu laden (neu hochgeladene Protokolle)
  /// 2. Fallback: PDF herunterladen und JPEG-Bytes extrahieren (alte Protokolle)
  static Future<List<Uint8List>> _ladeProtokollBilder(
    List<ReinigungLocal> reinigungen,
  ) async {
    final bilder = <Uint8List>[];
    for (final r in reinigungen) {
      final pfad = r.protokollFotoPfad;
      if (pfad == null || pfad.isEmpty) continue;
      try {
        Uint8List? imageBytes;

        // 1. Versuche direkt die .jpg-Version zu laden
        if (pfad.endsWith('.pdf')) {
          final jpgPfad = pfad.replaceAll('.pdf', '.jpg');
          try {
            imageBytes = await SupabaseService.client.storage
                .from('reinigung-fotos')
                .download(jpgPfad);
            debugPrint('Protokoll ${r.serverId}: JPG direkt geladen (${imageBytes.length} Bytes)');
          } catch (_) {
            // JPG existiert nicht (altes Protokoll), versuche PDF-Extraktion
          }
        }

        // 2. Fallback: Original-Datei laden
        if (imageBytes == null) {
          final bytes = await SupabaseService.client.storage
              .from('reinigung-fotos')
              .download(pfad);

          // Direktes Bild? (JPEG: FF D8, PNG: 89 50)
          if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
            imageBytes = bytes;
          } else if (bytes.length > 4 &&
              bytes[0] == 0x89 && bytes[1] == 0x50 &&
              bytes[2] == 0x4E && bytes[3] == 0x47) {
            imageBytes = bytes;
          } else {
            // PDF-Hülle: JPEG extrahieren
            imageBytes = _extractJpegFromPdf(bytes);
            if (imageBytes != null) {
              debugPrint('Protokoll ${r.serverId}: JPEG aus PDF extrahiert (${imageBytes.length} Bytes)');
            } else {
              debugPrint('Protokoll ${r.serverId}: Kein Bild gefunden (${bytes.length} Bytes, '
                  'erste: ${bytes.length > 4 ? [bytes[0], bytes[1], bytes[2], bytes[3]] : bytes})');
            }
          }
        }

        if (imageBytes != null && imageBytes.length > 1000) {
          bilder.add(imageBytes);
        }
      } catch (e) {
        debugPrint('Protokoll-Download fehlgeschlagen für ${r.serverId}: $e');
      }
    }
    debugPrint('_ladeProtokollBilder: ${bilder.length}/${reinigungen.length} Protokolle geladen');
    return bilder;
  }

  /// Extrahiert JPEG-Bytes aus einer PDF-Datei.
  /// Sucht nach dem JPEG SOI-Marker (FF D8 FF) und EOI-Marker (FF D9).
  /// Der Dart `pdf` Package speichert JPEG mit /DCTDecode Filter — die rohen
  /// JPEG-Bytes liegen direkt im PDF-Stream.
  static Uint8List? _extractJpegFromPdf(Uint8List pdfBytes) {
    // JPEG Start-Marker: FF D8 FF (SOI + erstes Marker-Byte)
    int startIdx = -1;
    for (int i = 0; i < pdfBytes.length - 2; i++) {
      if (pdfBytes[i] == 0xFF &&
          pdfBytes[i + 1] == 0xD8 &&
          pdfBytes[i + 2] == 0xFF) {
        startIdx = i;
        break;
      }
    }
    if (startIdx < 0) return null;

    // JPEG End-Marker: FF D9 (letztes Vorkommen nach Start)
    int endIdx = -1;
    for (int i = pdfBytes.length - 2; i > startIdx; i--) {
      if (pdfBytes[i] == 0xFF && pdfBytes[i + 1] == 0xD9) {
        endIdx = i + 2; // inklusive der 2 Marker-Bytes
        break;
      }
    }
    if (endIdx < 0) return null;

    // Sanity check: JPEG sollte mindestens ein paar KB gross sein
    final length = endIdx - startIdx;
    if (length < 1000) {
      debugPrint('_extractJpegFromPdf: Verdächtig klein ($length Bytes)');
      return null;
    }

    // WICHTIG: fromList erstellt eine KOPIE! sublistView wäre nur ein View
    // auf den Original-Buffer — MemoryImage greift intern auf .buffer zu
    // und würde dann den gesamten PDF-Buffer sehen statt nur das JPEG.
    return Uint8List.fromList(pdfBytes.sublist(startIdx, endIdx));
  }
}
