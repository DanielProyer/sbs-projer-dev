import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class ProtokollFotoStorage {
  static const _bucket = 'reinigung-fotos';
  static String get _userId => SupabaseService.currentUser!.id;

  /// Foto als PDF + Raw-JPEG in Supabase Storage hochladen, gibt den Storage-Pfad zurück.
  static Future<String> uploadFoto(
      String reinigungId, Uint8List imageBytes) async {
    // JPEG in PDF einbetten
    final pdfBytes = await _wrapImageInPdf(imageBytes);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$_userId/$reinigungId/$timestamp.pdf';
    final jpgPath = '$_userId/$reinigungId/$timestamp.jpg';

    // PDF hochladen (für Protokoll-Ansicht)
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          pdfBytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );

    // Raw JPEG daneben speichern (für Jahresrechnung-PDF)
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          jpgPath,
          imageBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return path;
  }

  /// Bild (JPEG) in ein einseitiges PDF-Dokument einbetten.
  static Future<Uint8List> _wrapImageInPdf(Uint8List imageBytes) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );

    return pdf.save();
  }

  /// Gibt den JPEG-Pfad für einen PDF-Pfad zurück.
  /// z.B. "user/reinigung/123.pdf" → "user/reinigung/123.jpg"
  static String jpgPathFromPdf(String pdfPath) {
    return pdfPath.replaceAll('.pdf', '.jpg');
  }

  /// Signed URL für das Protokoll (1 Stunde gültig).
  static Future<String> getSignedUrl(String pfad) async {
    return await SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(pfad, 3600);
  }

  /// Prüft ob der Pfad ein PDF ist (neues Format) oder ein JPG (altes Format).
  static bool isPdf(String pfad) => pfad.endsWith('.pdf');

  /// Foto/PDF aus Storage löschen.
  static Future<void> deleteFoto(String pfad) async {
    final paths = [pfad];
    // Auch JPEG-Version löschen falls vorhanden
    if (pfad.endsWith('.pdf')) {
      paths.add(jpgPathFromPdf(pfad));
    }
    await SupabaseService.client.storage.from(_bucket).remove(paths);
  }
}
