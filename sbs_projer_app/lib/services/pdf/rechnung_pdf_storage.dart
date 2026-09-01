import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class RechnungPdfStorage {
  static const _bucket = 'rechnung-pdfs';
  static String get _userId => SupabaseService.currentUser!.id;

  /// PDF in Supabase Storage hochladen
  static Future<void> uploadPdf(String rechnungId, Uint8List bytes) async {
    final path = '$_userId/$rechnungId/rechnung.pdf';

    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
  }

  /// Liegt das Rechnungs-PDF wirklich im Storage?
  ///
  /// Bewusst am Storage geprüft und nicht an `pdf_url` in der Datenbank: Am
  /// 01.09.2026 brach ein Upload ab, während die Rechnung selbst angelegt war.
  /// Nur die Ablage weiss, ob die Datei existiert — die DB kennt bestenfalls
  /// eine alte Signatur.
  static Future<bool> existiert(String rechnungId) async {
    try {
      final eintraege = await SupabaseService.client.storage
          .from(_bucket)
          .list(path: '$_userId/$rechnungId');
      return eintraege.any((f) => f.name == 'rechnung.pdf');
    } catch (_) {
      return false;
    }
  }

  /// Signed URL für das PDF (1 Stunde gültig)
  static Future<String> getSignedUrl(String rechnungId) async {
    final path = '$_userId/$rechnungId/rechnung.pdf';
    return await SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(path, 3600);
  }

  /// Protokolle-PDF hochladen (separate Datei neben der Rechnung)
  static Future<void> uploadProtokollePdf(String rechnungId, Uint8List bytes) async {
    final path = '$_userId/$rechnungId/protokolle.pdf';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
  }

  /// Signed URL für das Protokolle-PDF (1 Stunde gültig)
  static Future<String> getProtokollSignedUrl(String rechnungId) async {
    final path = '$_userId/$rechnungId/protokolle.pdf';
    return await SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(path, 3600);
  }

  /// Mahnungs-PDF hochladen (mahnung_0=Erinnerung, mahnung_1, mahnung_2)
  static Future<void> uploadMahnungPdf(
      String rechnungId, int stufe, Uint8List bytes) async {
    final path = '$_userId/$rechnungId/mahnung_$stufe.pdf';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
  }

  /// Signed URL für Mahnungs-PDF
  static Future<String> getMahnungSignedUrl(
      String rechnungId, int stufe) async {
    final path = '$_userId/$rechnungId/mahnung_$stufe.pdf';
    return await SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(path, 3600);
  }

  /// PDF aus Storage löschen
  static Future<void> deletePdf(String rechnungId) async {
    final path = '$_userId/$rechnungId/rechnung.pdf';
    await SupabaseService.client.storage.from(_bucket).remove([path]);
  }
}
