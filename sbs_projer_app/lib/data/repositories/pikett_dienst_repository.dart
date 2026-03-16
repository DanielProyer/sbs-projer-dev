import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/data/models/pikett_dienst.dart';
import 'package:sbs_projer_app/data/mappers/pikett_dienst_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class PikettDienstRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<PikettDienstLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('pikett_dienste').select().eq('user_id', _userId)
          .order('datum_start', ascending: false);
      return rows.map((r) => PikettDienstMapper.fromDto(PikettDienst.fromJson(r))).toList();
    }
    return IsarService.pikettDienstFindAll();
  }

  static Future<PikettDienstLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('pikett_dienste').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return PikettDienstMapper.fromDto(PikettDienst.fromJson(rows.first));
    }
    return IsarService.pikettDienstGet(int.parse(id));
  }

  static Stream<List<PikettDienstLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.pikettDienstWatchAll();
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('pikett_dienste').select('id').eq('user_id', _userId);
      return rows.length;
    }
    return IsarService.pikettDienstCount();
  }

  static Future<void> save(PikettDienstLocal pikett) async {
    pikett.userId = SupabaseService.currentUser!.id;
    if (kIsWeb) {
      final json = PikettDienstMapper.toJson(pikett);
      await SupabaseService.client.from('pikett_dienste').upsert(json);
      return;
    }
    pikett.isSynced = false;
    pikett.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.pikettDienstPut(pikett);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('pikett_dienste').delete().eq('id', id);
      return;
    }
    final local = await IsarService.pikettDienstGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('pikett_dienste').delete().eq('id', local!.serverId!);
    }
    await IsarService.pikettDienstDelete(int.parse(id));
  }
}
