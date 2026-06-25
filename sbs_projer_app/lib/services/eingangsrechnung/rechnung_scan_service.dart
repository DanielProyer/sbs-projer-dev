import 'dart:convert';
import 'dart:typed_data';
import 'package:sbs_projer_app/data/models/rechnung_scan_result.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ruft die Supabase Edge Function "parse-rechnung" auf, die Claude
/// zur OCR-/Analyse einer Eingangsrechnung (Kreditor) verwendet.
class RechnungScanService {
  /// Analysiert ein Rechnungs-Dokument (PDF/Bild) und gibt strukturierte
  /// Daten zurück.
  static Future<RechnungScanResult> scan({
    required Uint8List bytes,
    required String mediaType,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'parse-rechnung',
      body: {
        'file_base64': base64Encode(bytes),
        'media_type': mediaType,
      },
    );

    if (response.status != 200) {
      final error =
          response.data is Map ? response.data['error'] : 'Unbekannter Fehler';
      throw Exception('Rechnungs-Analyse fehlgeschlagen: $error');
    }

    final data = response.data as Map<String, dynamic>;
    return RechnungScanResult.fromJson(data);
  }
}
