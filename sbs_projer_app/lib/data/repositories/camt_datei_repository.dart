import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class CamtDateiRepository {
  static const _bucket = 'camt-dateien';
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<CamtDatei>> getAll() async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('camt_dateien')
          .select()
          .eq('user_id', _userId)
          .order('zeitraum_von', ascending: true)
          .range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all.map((r) => CamtDatei.fromJson(r)).toList();
  }

  /// True wenn schon eine Datei mit gleicher IBAN + Zeitraum existiert.
  static Future<bool> existsZeitraum(
      String? iban, DateTime? von, DateTime? bis) async {
    if (von == null || bis == null) return false;
    final rows = await SupabaseService.client
        .from('camt_dateien')
        .select('id')
        .eq('user_id', _userId)
        .eq('zeitraum_von', von.toIso8601String().split('T').first)
        .eq('zeitraum_bis', bis.toIso8601String().split('T').first);
    return (rows as List).isNotEmpty;
  }

  /// Lädt das XML in den Bucket + erstellt den Metadaten-Record.
  static Future<CamtDatei> speichern(CamtDatei meta, Uint8List xmlBytes) async {
    final pfad = '$_userId/${meta.dateiname}';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          pfad,
          xmlBytes,
          fileOptions: const FileOptions(
              contentType: 'application/xml', upsert: true),
        );
    final json = meta.toInsert()
      ..['user_id'] = _userId
      ..['storage_pfad'] = pfad;
    final rows =
        await SupabaseService.client.from('camt_dateien').insert(json).select();
    return CamtDatei.fromJson(rows.first);
  }

  static Future<String> signedUrl(String storagePfad) =>
      SupabaseService.client.storage
          .from(_bucket)
          .createSignedUrl(storagePfad, 3600);
}
