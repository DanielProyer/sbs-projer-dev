import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/data/models/buchungs_beleg.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BuchungsBelegRepository {
  static String get _userId => SupabaseService.dataUserId;
  static const _bucket = 'buchungs-belege';

  /// Alle Belege einer Buchung laden.
  static Future<List<BuchungsBeleg>> getByBuchung(String buchungId) async {
    final rows = await SupabaseService.client
        .from('buchungs_belege')
        .select()
        .eq('buchung_id', buchungId)
        .order('created_at');
    return rows.map((r) => BuchungsBeleg.fromJson(r)).toList();
  }

  /// Beleg hochladen: Storage + DB-Record.
  static Future<BuchungsBeleg> upload({
    required String buchungId,
    required String dateiname,
    required String dateityp,
    required Uint8List bytes,
    String belegQuelle = 'manuell',
    String? beschreibung,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$_userId/$buchungId/${timestamp}_$dateiname';

    // Content-Type bestimmen
    String contentType = 'application/octet-stream';
    if (dateityp == 'pdf') contentType = 'application/pdf';
    if (dateityp == 'jpg' || dateityp == 'jpeg') contentType = 'image/jpeg';
    if (dateityp == 'png') contentType = 'image/png';

    // 1. Upload zu Supabase Storage
    await SupabaseService.client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    // 2. DB-Record erstellen
    final rows = await SupabaseService.client.from('buchungs_belege').insert({
      'user_id': _userId,
      'buchung_id': buchungId,
      'dateiname': dateiname,
      'dateityp': dateityp,
      'storage_pfad': path,
      'beleg_quelle': belegQuelle,
      'beschreibung': beschreibung,
    }).select();

    return BuchungsBeleg.fromJson(rows.first);
  }

  /// Beleg löschen: DB-Record + Storage.
  static Future<void> delete(String belegId, String storagePfad) async {
    await SupabaseService.client
        .from('buchungs_belege')
        .delete()
        .eq('id', belegId);

    await SupabaseService.client.storage
        .from(_bucket)
        .remove([storagePfad]);
  }

  /// Signed URL für einen Beleg generieren (1h gültig).
  static Future<String> getSignedUrl(String storagePfad) async {
    return await SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(storagePfad, 3600);
  }
}
