import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/data/models/anlage_foto.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class AnlageFotoRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Alle Fotos einer Anlage laden (sortiert nach foto_nummer)
  static Future<List<AnlageFoto>> getByAnlage(String anlageId) async {
    final rows = await SupabaseService.client
        .from('anlagen_fotos')
        .select()
        .eq('anlage_id', anlageId)
        .order('foto_nummer');
    return rows.map((r) => AnlageFoto.fromJson(r)).toList();
  }

  /// Foto hochladen: Storage + DB-Record
  static Future<void> upload(
    String anlageId,
    int fotoNummer,
    Uint8List bytes,
    String? beschreibung,
  ) async {
    final path = '$_userId/$anlageId/$fotoNummer.jpg';

    // 1. Upload zu Supabase Storage (überschreibt falls vorhanden)
    await SupabaseService.client.storage
        .from('anlagen-fotos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    // 2. DB-Record upserten (UNIQUE auf anlage_id + foto_nummer)
    await SupabaseService.client.from('anlagen_fotos').upsert(
      {
        'user_id': _userId,
        'anlage_id': anlageId,
        'foto_nummer': fotoNummer,
        'foto_url': path, // Speichere Pfad, nicht signed URL
        'beschreibung': beschreibung,
      },
      onConflict: 'anlage_id,foto_nummer',
    );
  }

  /// Foto löschen: DB-Record + Storage
  static Future<void> delete(String anlageId, int fotoNummer) async {
    final path = '$_userId/$anlageId/$fotoNummer.jpg';

    // 1. DB-Record löschen
    await SupabaseService.client
        .from('anlagen_fotos')
        .delete()
        .eq('anlage_id', anlageId)
        .eq('foto_nummer', fotoNummer);

    // 2. Datei aus Storage löschen
    await SupabaseService.client.storage
        .from('anlagen-fotos')
        .remove([path]);
  }

  /// Signed URL für ein Foto generieren (1h gültig)
  static Future<String> getSignedUrl(String storagePath) async {
    return await SupabaseService.client.storage
        .from('anlagen-fotos')
        .createSignedUrl(storagePath, 3600);
  }

  /// Signed URLs für mehrere Fotos auf einmal
  static Future<Map<int, String>> getSignedUrls(
      List<AnlageFoto> fotos) async {
    final urls = <int, String>{};
    for (final foto in fotos) {
      try {
        urls[foto.fotoNummer] = await getSignedUrl(foto.fotoUrl);
      } catch (_) {
        // Foto evtl. gelöscht aus Storage — ignorieren
      }
    }
    return urls;
  }
}
