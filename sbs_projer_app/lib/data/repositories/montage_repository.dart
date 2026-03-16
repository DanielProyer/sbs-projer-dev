import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/models/montage.dart';
import 'package:sbs_projer_app/data/mappers/montage_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class MontageRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<MontageLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('montagen').select().eq('user_id', _userId);
      return rows.map((r) => MontageMapper.fromDto(Montage.fromJson(r))).toList();
    }
    return IsarService.montageFindAll();
  }

  static Future<MontageLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('montagen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return MontageMapper.fromDto(Montage.fromJson(rows.first));
    }
    return IsarService.montageGet(int.parse(id));
  }

  static Stream<List<MontageLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.montageWatchAll();
  }

  static Future<List<MontageLocal>> getByAnlage(String anlageId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('montagen').select().eq('user_id', _userId).eq('anlage_id', anlageId);
      return rows.map((r) => MontageMapper.fromDto(Montage.fromJson(r))).toList();
    }
    return IsarService.montageFilterByAnlage(anlageId);
  }

  static Future<List<MontageLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('montagen').select().eq('user_id', _userId).eq('betrieb_id', betriebId);
      return rows.map((r) => MontageMapper.fromDto(Montage.fromJson(r))).toList();
    }
    return IsarService.montageFilterByBetrieb(betriebId);
  }

  static Stream<List<MontageLocal>> watchByAnlage(String anlageId) {
    if (kIsWeb) return Stream.fromFuture(getByAnlage(anlageId));
    return IsarService.montageWatchByAnlage(anlageId);
  }

  static Stream<List<MontageLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.montageWatchByBetrieb(betriebId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('montagen').select('id').eq('user_id', _userId);
      return rows.length;
    }
    return IsarService.montageCount();
  }

  static Future<void> save(MontageLocal montage) async {
    montage.userId = SupabaseService.currentUser!.id;
    if (kIsWeb) {
      final json = MontageMapper.toJson(montage);
      await SupabaseService.client.from('montagen').upsert(json);
      return;
    }
    montage.isSynced = false;
    montage.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.montagePut(montage);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('montagen').delete().eq('id', id);
      return;
    }
    final local = await IsarService.montageGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('montagen').delete().eq('id', local!.serverId!);
    }
    await IsarService.montageDelete(int.parse(id));
  }
}
