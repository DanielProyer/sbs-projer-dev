import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Reinigungsprotokolle als PDF — einzeln oder gebündelt.
///
/// WARUM diese Datei (21.09.2026): Die Bündel-Logik lag privat in
/// `jahresrechnung_service.dart` und lief nur als Nebenprodukt der
/// Jahresrechnung. Daniel wollte die Protokolle auch direkt herunterladen
/// können. Die drei Funktionen sind von dort unverändert hierher gezogen; die
/// Jahresrechnung ruft sie jetzt hier auf.
///
/// ⚠️ NICHT zu verwechseln mit `reinigung_pdf_service.dart`: Das erzeugt das
/// alte Heineken-Formular aus Checkliste und Unterschriften. Diese Felder
/// werden seit der Foto-Umstellung nicht mehr gefüllt — für eine heutige
/// Reinigung käme ein fast leeres Blatt heraus. Das echte Protokoll ist das
/// abfotografierte Papier in `protokoll_foto_pfad`.
class ProtokollePdfService {
  static const _bucket = 'reinigung-fotos';

  /// Das Protokoll EINER Reinigung als PDF.
  ///
  /// Die gespeicherte Datei ist in aller Regel bereits ein PDF (das Foto in
  /// eine A4-Seite gehüllt) — dann wird sie unverändert durchgereicht, ohne
  /// Neuberechnung und ohne Qualitätsverlust. Nur bei Altbeständen, die als
  /// reines Bild abgelegt wurden, wird eine Seite darum gebaut.
  ///
  /// null, wenn die Reinigung kein Protokoll hat oder die Datei fehlt.
  static Future<Uint8List?> einzeln(ReinigungLocal r) async {
    final pfad = r.protokollFotoPfad;
    if (pfad == null || pfad.isEmpty) return null;
    try {
      final bytes = await SupabaseService.client.storage
          .from(_bucket)
          .download(pfad);
      if (bytes.length > 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46) {
        return bytes; // schon ein PDF
      }
      final pdf = await pdfDokument();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (_) => pw.Center(
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
          ),
        ),
      );
      return pdf.save();
    } catch (e) {
      debugPrint('Protokoll-Download fehlgeschlagen für ${r.serverId}: $e');
      return null;
    }
  }

  /// Generiert ein separates PDF mit allen Reinigungsprotokollen.
  /// Jedes Protokollbild wird als eigene A4-Seite eingebettet.
  static Future<Uint8List> buendel(
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
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(betriebName, style: const pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 10),
              pw.Text('Jahr $jahr', style: const pw.TextStyle(fontSize: 16)),
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
            build: (context) =>
                pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
        debugPrint(
          'Protokoll $i/${bilder.length}: ${bilder[i].length} Bytes eingebettet',
        );
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
  static Future<List<Uint8List>> ladeBilder(
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
            debugPrint(
              'Protokoll ${r.serverId}: JPG direkt geladen (${imageBytes.length} Bytes)',
            );
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
              bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4E &&
              bytes[3] == 0x47) {
            imageBytes = bytes;
          } else {
            // PDF-Hülle: JPEG extrahieren
            imageBytes = extractJpegFromPdf(bytes);
            if (imageBytes != null) {
              debugPrint(
                'Protokoll ${r.serverId}: JPEG aus PDF extrahiert (${imageBytes.length} Bytes)',
              );
            } else {
              debugPrint(
                'Protokoll ${r.serverId}: Kein Bild gefunden (${bytes.length} Bytes, '
                'erste: ${bytes.length > 4 ? [bytes[0], bytes[1], bytes[2], bytes[3]] : bytes})',
              );
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
    debugPrint(
      'ladeBilder: ${bilder.length}/${reinigungen.length} Protokolle geladen',
    );
    return bilder;
  }

  /// Extrahiert JPEG-Bytes aus einer PDF-Datei.
  /// Sucht nach dem JPEG SOI-Marker (FF D8 FF) und EOI-Marker (FF D9).
  /// Der Dart `pdf` Package speichert JPEG mit /DCTDecode Filter — die rohen
  /// JPEG-Bytes liegen direkt im PDF-Stream.
  static Uint8List? extractJpegFromPdf(Uint8List pdfBytes) {
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
      debugPrint('extractJpegFromPdf: Verdächtig klein ($length Bytes)');
      return null;
    }

    // WICHTIG: fromList erstellt eine KOPIE! sublistView wäre nur ein View
    // auf den Original-Buffer — MemoryImage greift intern auf .buffer zu
    // und würde dann den gesamten PDF-Buffer sehen statt nur das JPEG.
    return Uint8List.fromList(pdfBytes.sublist(startIdx, endIdx));
  }
}
