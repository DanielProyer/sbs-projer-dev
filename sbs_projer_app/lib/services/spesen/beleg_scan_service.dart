import 'dart:convert';
import 'dart:typed_data';
import 'package:sbs_projer_app/data/models/beleg_scan_result.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ruft die Supabase Edge Function "parse-beleg" auf, die Claude Haiku
/// zur OCR-Analyse eines Kassenzettels verwendet.
class BelegScanService {
  /// Analysiert ein Beleg-Bild und gibt strukturierte Daten zurück.
  static Future<BelegScanResult> parseBeleg({
    required Uint8List bytes,
    required String mediaType,
  }) async {
    final base64 = base64Encode(bytes);

    final response = await SupabaseService.client.functions.invoke(
      'parse-beleg',
      body: {
        'image_base64': base64,
        'media_type': mediaType,
      },
    );

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unbekannter Fehler';
      throw Exception('Beleg-Analyse fehlgeschlagen: $error');
    }

    final data = response.data as Map<String, dynamic>;
    return BelegScanResult.fromJson(data);
  }
}
