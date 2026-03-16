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

  /// Signed URL für das PDF (1 Stunde gültig)
  static Future<String> getSignedUrl(String rechnungId) async {
    final path = '$_userId/$rechnungId/rechnung.pdf';
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
