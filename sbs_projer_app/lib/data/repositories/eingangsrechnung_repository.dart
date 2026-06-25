import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Eingangsrechnungen (Kreditoren, kein Isar).
class EingangsrechnungRepository {
  static String get _userId => SupabaseService.currentUser!.id;
  static const _bucket = 'buchungs-belege';

  /// Erstellt eine Eingangsrechnung und gibt das DB-Ergebnis zurück (inkl. ID).
  static Future<Eingangsrechnung> create(Map<String, dynamic> json) async {
    json['user_id'] = _userId;
    json.remove('id');
    final rows = await SupabaseService.client
        .from('eingangsrechnung')
        .insert(json)
        .select();
    return Eingangsrechnung.fromJson(rows.first);
  }

  /// Aktualisiert einzelne Felder einer Eingangsrechnung.
  static Future<void> update(String id, Map<String, dynamic> fields) async {
    await SupabaseService.client
        .from('eingangsrechnung')
        .update(fields)
        .eq('id', id);
  }

  /// Liefert alle Eingangsrechnungen des Users mit einem der gegebenen Stati,
  /// neueste zuerst (nach Rechnungsdatum).
  static Future<List<Eingangsrechnung>> getByStatus(List<String> stati) async {
    final rows = await SupabaseService.client
        .from('eingangsrechnung')
        .select()
        .eq('user_id', _userId)
        .inFilter('status', stati)
        .order('rechnungsdatum', ascending: false);
    return rows.map((r) => Eingangsrechnung.fromJson(r)).toList();
  }

  static Future<Eingangsrechnung?> getById(String id) async {
    final rows = await SupabaseService.client
        .from('eingangsrechnung')
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return Eingangsrechnung.fromJson(rows.first);
  }

  /// Lädt den Beleg (PDF/Bild) einer Eingangsrechnung in den Storage-Bucket
  /// `buchungs-belege` und gibt den Storage-Pfad zurück.
  static Future<String> uploadBeleg({
    required String eingangsrechnungId,
    required String dateiname,
    required String dateityp,
    required Uint8List bytes,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        '$_userId/eingangsrechnung/$eingangsrechnungId/${timestamp}_$dateiname';

    String contentType = 'application/octet-stream';
    if (dateityp == 'pdf') contentType = 'application/pdf';
    if (dateityp == 'jpg' || dateityp == 'jpeg') contentType = 'image/jpeg';
    if (dateityp == 'png') contentType = 'image/png';

    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    return path;
  }

  /// Signed URL für einen Beleg-Pfad generieren (1h gültig).
  static Future<String> signedBelegUrl(String pfad) async {
    return SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(pfad, 3600);
  }
}
