import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/data/models/material_artikel.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Heineken Artikelstamm.
class MaterialArtikelRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<MaterialArtikel>> getAll() async {
    final rows = await SupabaseService.client
        .from('material')
        .select()
        .eq('user_id', _userId)
        .order('dbo_nr');
    return rows.map((r) => MaterialArtikel.fromJson(r)).toList();
  }

  static Future<MaterialArtikel?> getById(String id) async {
    final rows = await SupabaseService.client
        .from('material')
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return MaterialArtikel.fromJson(rows.first);
  }

  static Future<List<MaterialArtikel>> search(String query) async {
    final rows = await SupabaseService.client
        .from('material')
        .select()
        .eq('user_id', _userId)
        .or('name.ilike.%$query%,dbo_nr.ilike.%$query%')
        .order('dbo_nr')
        .limit(50);
    return rows.map((r) => MaterialArtikel.fromJson(r)).toList();
  }

  /// Foto hochladen und foto_storage_path setzen.
  /// Pfad: {userId}/{materialId}.jpg
  /// ImagePicker reduziert bereits auf 1600px / 85% Qualität.
  static Future<void> uploadFoto(String materialId, Uint8List bytes) async {
    final userId = SupabaseService.currentUser!.id;
    final fullPath = '$userId/$materialId.jpg';

    debugPrint('Foto-Upload: ${bytes.length} bytes → $fullPath');

    await SupabaseService.client.storage
        .from('material-fotos')
        .uploadBinary(
          fullPath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    await SupabaseService.client
        .from('material')
        .update({'foto_storage_path': fullPath})
        .eq('id', materialId);

    debugPrint('Foto-Upload erfolgreich: $fullPath');
  }

  /// Foto löschen
  static Future<void> deleteFoto(
      String materialId, String storagePath) async {
    await SupabaseService.client.storage
        .from('material-fotos')
        .remove([storagePath]);

    await SupabaseService.client
        .from('material')
        .update({'foto_storage_path': null})
        .eq('id', materialId);
  }

  /// Signed URL generieren (1h gültig)
  static Future<String> getSignedUrl(String storagePath) async {
    return await SupabaseService.client.storage
        .from('material-fotos')
        .createSignedUrl(storagePath, 3600);
  }
}
