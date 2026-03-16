import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/models/eigenauftrag.dart';
import 'package:sbs_projer_app/data/mappers/eigenauftrag_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EigenauftragRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<EigenauftragLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('eigenauftraege').select().eq('user_id', _userId);
      return rows.map((r) => EigenauftragMapper.fromDto(Eigenauftrag.fromJson(r))).toList();
    }
    return IsarService.eigenauftragFindAll();
  }

  static Future<EigenauftragLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('eigenauftraege').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return EigenauftragMapper.fromDto(Eigenauftrag.fromJson(rows.first));
    }
    return IsarService.eigenauftragGet(int.parse(id));
  }

  static Stream<List<EigenauftragLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.eigenauftragWatchAll();
  }

  static Future<List<EigenauftragLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('eigenauftraege').select().eq('user_id', _userId).eq('betrieb_id', betriebId);
      return rows.map((r) => EigenauftragMapper.fromDto(Eigenauftrag.fromJson(r))).toList();
    }
    return IsarService.eigenauftragFilterByBetrieb(betriebId);
  }

  static Stream<List<EigenauftragLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.eigenauftragWatchByBetrieb(betriebId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('eigenauftraege').select('id').eq('user_id', _userId);
      return rows.length;
    }
    return IsarService.eigenauftragCount();
  }

  static Future<void> save(EigenauftragLocal eigenauftrag) async {
    eigenauftrag.userId = _userId;
    if (kIsWeb) {
      final json = EigenauftragMapper.toJson(eigenauftrag);
      await SupabaseService.client.from('eigenauftraege').upsert(json);
      return;
    }
    eigenauftrag.isSynced = false;
    eigenauftrag.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eigenauftragPut(eigenauftrag);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('eigenauftraege').delete().eq('id', id);
      return;
    }
    final local = await IsarService.eigenauftragGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('eigenauftraege').delete().eq('id', local!.serverId!);
    }
    await IsarService.eigenauftragDelete(int.parse(id));
  }
}
