import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/reinigung.dart';
import 'package:sbs_projer_app/data/mappers/reinigung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class ReinigungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Holt ALLE Zeilen seitenweise (PostgREST deckelt sonst bei 1000).
  static Future<List<Map<String, dynamic>>> _pagedByUser({String? col, String? val}) async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      var q = SupabaseService.client.from('reinigungen').select().eq('user_id', _userId);
      if (col != null) q = q.eq(col, val!);
      final rows = await q.order('datum', ascending: false).range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all;
  }

  static Future<List<ReinigungLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await _pagedByUser();
      return rows.map((r) => ReinigungMapper.fromDto(Reinigung.fromJson(r))).toList();
    }
    return IsarService.reinigungFindAll();
  }

  static Stream<List<ReinigungLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.reinigungWatchAll();
  }

  static Future<ReinigungLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('reinigungen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return ReinigungMapper.fromDto(Reinigung.fromJson(rows.first));
    }
    return IsarService.reinigungGet(int.parse(id));
  }

  static Future<ReinigungLocal?> getByServerId(String serverId) async {
    if (kIsWeb) return getById(serverId);
    return IsarService.reinigungFindByServerId(serverId);
  }

  static Future<List<ReinigungLocal>> getByAnlage(String anlageId) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(col: 'anlage_id', val: anlageId);
      return rows.map((r) => ReinigungMapper.fromDto(Reinigung.fromJson(r))).toList();
    }
    return IsarService.reinigungFilterByAnlage(anlageId);
  }

  static Future<List<ReinigungLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(col: 'betrieb_id', val: betriebId);
      return rows.map((r) => ReinigungMapper.fromDto(Reinigung.fromJson(r))).toList();
    }
    return IsarService.reinigungFilterByBetrieb(betriebId);
  }

  static Stream<List<ReinigungLocal>> watchByAnlage(String anlageId) {
    if (kIsWeb) return Stream.fromFuture(getByAnlage(anlageId));
    return IsarService.reinigungWatchByAnlage(anlageId);
  }

  static Stream<List<ReinigungLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.reinigungWatchByBetrieb(betriebId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      int total = 0;
      const pageSize = 1000;
      int from = 0;
      while (true) {
        final rows = await SupabaseService.client
            .from('reinigungen').select('id').eq('user_id', _userId)
            .range(from, from + pageSize - 1);
        total += rows.length;
        if (rows.length < pageSize) break;
        from += pageSize;
      }
      return total;
    }
    return IsarService.reinigungCount();
  }

  static Future<void> save(ReinigungLocal reinigung) async {
    reinigung.userId = _userId;
    if (kIsWeb) {
      final json = ReinigungMapper.toJson(reinigung);
      await SupabaseService.client.from('reinigungen').upsert(json);
      return;
    }
    reinigung.isSynced = false;
    reinigung.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.reinigungPut(reinigung);
  }

  static Future<ReinigungLocal?> getLastByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('reinigungen')
          .select()
          .eq('user_id', _userId)
          .eq('betrieb_id', betriebId)
          .order('datum', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return ReinigungMapper.fromDto(Reinigung.fromJson(rows.first));
    }
    final all = await IsarService.reinigungFilterByBetrieb(betriebId);
    if (all.isEmpty) return null;
    all.sort((a, b) => b.datum.compareTo(a.datum));
    return all.first;
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('reinigungen').delete().eq('id', id);
      return;
    }
    // Native: Supabase löschen, dann Isar aufräumen
    final local = await IsarService.reinigungGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('reinigungen').delete().eq('id', local!.serverId!);
    }
    await IsarService.reinigungDelete(int.parse(id));
  }
}
