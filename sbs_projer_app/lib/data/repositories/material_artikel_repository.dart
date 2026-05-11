import 'dart:typed_data';
import 'dart:ui' as ui;
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

  /// Foto hochladen (Full-Res + Thumbnail) und foto_storage_path setzen.
  /// Full-Res: {userId}/{materialId}.jpg
  /// Thumbnail: {userId}/{materialId}_thumb.png (300px, client-seitig erzeugt)
  static Future<void> uploadFoto(String materialId, Uint8List bytes) async {
    final userId = SupabaseService.currentUser!.id;
    final fullPath = '$userId/$materialId.jpg';
    final thumbPath = '$userId/${materialId}_thumb.png';

    // 1. Full-Res JPEG hochladen
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

    // 2. Thumbnail client-seitig erstellen und hochladen
    try {
      final thumbBytes = await _createThumbnail(bytes, maxSize: 300);
      await SupabaseService.client.storage
          .from('material-fotos')
          .uploadBinary(
            thumbPath,
            thumbBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
      debugPrint('Thumbnail erstellt: ${thumbBytes.length} bytes');
    } catch (e) {
      debugPrint('Thumbnail-Erstellung fehlgeschlagen: $e');
      // Kein Problem — Fallback auf Full-Res
    }

    await SupabaseService.client
        .from('material')
        .update({'foto_storage_path': fullPath})
        .eq('id', materialId);
  }

  /// Foto löschen (Full-Res + Thumbnail)
  static Future<void> deleteFoto(
      String materialId, String storagePath) async {
    final thumbPath = storagePath.replaceAll('.jpg', '_thumb.png');
    // Beide Dateien löschen (Thumbnail-Fehler ignorieren)
    await SupabaseService.client.storage
        .from('material-fotos')
        .remove([storagePath, thumbPath]);

    await SupabaseService.client
        .from('material')
        .update({'foto_storage_path': null})
        .eq('id', materialId);
  }

  /// Signed URL für volle Auflösung generieren (1h gültig)
  static Future<String> getSignedUrl(String storagePath) async {
    return await SupabaseService.client.storage
        .from('material-fotos')
        .createSignedUrl(storagePath, 3600);
  }

  /// Signed URL für Thumbnail (client-seitig erstelltes _thumb.png).
  /// Gibt null zurück wenn kein Thumbnail vorhanden ist.
  static Future<String?> getSignedUrlThumb(String storagePath) async {
    try {
      final thumbPath = storagePath.replaceAll('.jpg', '_thumb.png');
      return await SupabaseService.client.storage
          .from('material-fotos')
          .createSignedUrl(thumbPath, 3600);
    } catch (e) {
      debugPrint('Thumbnail nicht vorhanden: $e');
      return null;
    }
  }

  // ── Thumbnail-Erzeugung ──────────────────────────────────────────

  /// Erstellt ein PNG-Thumbnail aus JPEG-Bytes via dart:ui.
  /// Pixel 9 optimiert: 300px reicht für 200px-Vorschaukarte.
  static Future<Uint8List> _createThumbnail(
    Uint8List originalBytes, {
    int maxSize = 300,
  }) async {
    // Bild dekodieren (mit Zielbreite für automatische Skalierung)
    final codec = await ui.instantiateImageCodec(
      originalBytes,
      targetWidth: maxSize,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // Als PNG kodieren
    final pngData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();

    if (pngData == null) {
      throw Exception('PNG-Kodierung fehlgeschlagen');
    }
    return Uint8List.view(pngData.buffer);
  }
}
