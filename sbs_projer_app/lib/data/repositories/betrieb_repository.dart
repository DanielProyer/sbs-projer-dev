import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BetriebRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<BetriebLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betriebe').select().eq('user_id', _userId);
      return rows.map((r) => BetriebMapper.fromDto(Betrieb.fromJson(r))).toList();
    }
    return IsarService.betriebFindAll();
  }

  static Stream<List<BetriebLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.betriebWatchAll();
  }

  static Future<List<BetriebLocal>> getAktive() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betriebe').select().eq('user_id', _userId).eq('status', 'aktiv');
      return rows.map((r) => BetriebMapper.fromDto(Betrieb.fromJson(r))).toList();
    }
    return IsarService.betriebFilterByStatus('aktiv');
  }

  static Future<BetriebLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betriebe').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return BetriebMapper.fromDto(Betrieb.fromJson(rows.first));
    }
    return IsarService.betriebGet(int.parse(id));
  }

  static Future<BetriebLocal?> getByServerId(String serverId) async {
    if (kIsWeb) return getById(serverId);
    return IsarService.betriebFindByServerId(serverId);
  }

  static Future<List<BetriebLocal>> getByRegion(String regionId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betriebe').select().eq('user_id', _userId).eq('region_id', regionId);
      return rows.map((r) => BetriebMapper.fromDto(Betrieb.fromJson(r))).toList();
    }
    return IsarService.betriebFilterByRegion(regionId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betriebe').select('id').eq('user_id', _userId);
      return rows.length;
    }
    return IsarService.betriebCount();
  }

  static Future<void> save(BetriebLocal betrieb) async {
    betrieb.userId = _userId;
    if (kIsWeb) {
      final json = BetriebMapper.toJson(betrieb);
      await SupabaseService.client.from('betriebe').upsert(json);
      return;
    }
    betrieb.isSynced = false;
    betrieb.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.betriebPut(betrieb);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('betriebe').delete().eq('id', id);
      return;
    }
    // Native: Supabase löscht mit CASCADE, dann Isar aufräumen
    final local = await IsarService.betriebGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('betriebe').delete().eq('id', local!.serverId!);
    }
    await IsarService.betriebDeleteCascade(int.parse(id));
  }
}
