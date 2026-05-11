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

  /// Foto hochladen: High-Res + Preview (geringe Auflösung).
  /// High-Res: {userId}/{materialId}.jpg
  /// Preview:  {userId}/{materialId}_preview.jpg
  static Future<void> uploadFoto(
    String materialId, {
    required Uint8List highResBytes,
    required Uint8List previewBytes,
  }) async {
    final userId = SupabaseService.currentUser!.id;
    final fullPath = '$userId/$materialId.jpg';
    final previewPath = '$userId/${materialId}_preview.jpg';

    debugPrint(
        'Foto-Upload: HighRes ${highResBytes.length} bytes, '
        'Preview ${previewBytes.length} bytes');

    // Beide parallel hochladen
    await Future.wait([
      SupabaseService.client.storage
          .from('material-fotos')
          .uploadBinary(
            fullPath,
            highResBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          ),
      SupabaseService.client.storage
          .from('material-fotos')
          .uploadBinary(
            previewPath,
            previewBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          ),
    ]);

    await SupabaseService.client
        .from('material')
        .update({'foto_storage_path': fullPath})
        .eq('id', materialId);

    debugPrint('Foto-Upload erfolgreich');
  }

  /// Foto löschen (High-Res + Preview)
  static Future<void> deleteFoto(
      String materialId, String storagePath) async {
    final previewPath = storagePath.replaceAll('.jpg', '_preview.jpg');
    await SupabaseService.client.storage
        .from('material-fotos')
        .remove([storagePath, previewPath]);

    await SupabaseService.client
        .from('material')
        .update({'foto_storage_path': null})
        .eq('id', materialId);
  }

  /// Signed URL für High-Res (1h gültig)
  static Future<String> getSignedUrl(String storagePath) async {
    return await SupabaseService.client.storage
        .from('material-fotos')
        .createSignedUrl(storagePath, 3600);
  }

  /// Signed URL für Preview (geringe Auflösung). Null wenn nicht vorhanden.
  static Future<String?> getSignedUrlPreview(String storagePath) async {
    try {
      final previewPath = storagePath.replaceAll('.jpg', '_preview.jpg');
      return await SupabaseService.client.storage
          .from('material-fotos')
          .createSignedUrl(previewPath, 3600);
    } catch (_) {
      return null;
    }
  }
}
