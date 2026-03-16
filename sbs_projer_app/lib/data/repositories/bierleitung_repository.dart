import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/bierleitung_local_export.dart';
import 'package:sbs_projer_app/data/models/bierleitung.dart';
import 'package:sbs_projer_app/data/mappers/bierleitung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BierleitungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<BierleitungLocal>> getByAnlage(String anlageId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('bierleitungen').select()
          .eq('anlage_id', anlageId).order('leitungs_nummer');
      return rows.map((r) => BierleitungMapper.fromDto(Bierleitung.fromJson(r))).toList();
    }
    return IsarService.bierleitungFilterByAnlage(anlageId);
  }

  static Stream<List<BierleitungLocal>> watchByAnlage(String anlageId) {
    if (kIsWeb) return Stream.fromFuture(getByAnlage(anlageId));
    return IsarService.bierleitungWatchByAnlage(anlageId);
  }

  static Future<BierleitungLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('bierleitungen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return BierleitungMapper.fromDto(Bierleitung.fromJson(rows.first));
    }
    return IsarService.bierleitungGet(int.parse(id));
  }

  static Future<void> save(BierleitungLocal leitung) async {
    leitung.userId = _userId;
    if (kIsWeb) {
      final json = BierleitungMapper.toJson(leitung);
      await SupabaseService.client.from('bierleitungen').upsert(json);
      return;
    }
    leitung.isSynced = false;
    leitung.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.bierleitungPut(leitung);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('bierleitungen').delete().eq('id', id);
      return;
    }
    await IsarService.bierleitungDelete(int.parse(id));
  }
}
