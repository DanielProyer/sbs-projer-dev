import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/eroeffnungsreinigung.dart';
import 'package:sbs_projer_app/data/mappers/eroeffnungsreinigung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EroeffnungsreinigungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Holt ALLE Zeilen seitenweise (PostgREST deckelt sonst bei 1000).
  static Future<List<Map<String, dynamic>>> _pagedByUser(
      {String? col, String? val}) async {
    const pageSize = 1000;

    Future<List<Map<String, dynamic>>> fetchPage(int page) {
      var q = SupabaseService.client
          .from('eroeffnungsreinigungen')
          .select()
          .eq('user_id', _userId);
      if (col != null) q = q.eq(col, val!);
      return q
          .order('datum', ascending: false)
          .order('id')
          .range(page * pageSize, (page + 1) * pageSize - 1)
          .then((rows) => List<Map<String, dynamic>>.from(rows));
    }

    final all = <Map<String, dynamic>>[];
    final first = await fetchPage(0);
    all.addAll(first);
    if (first.length < pageSize) return all;

    const batch = 4;
    int nextPage = 1;
    while (true) {
      final pages = await Future.wait(
        [for (int i = 0; i < batch; i++) fetchPage(nextPage + i)],
      );
      for (final rows in pages) {
        all.addAll(rows);
      }
      if (pages.last.length < pageSize) break;
      nextPage += batch;
    }
    return all;
  }

  static Future<List<EroeffnungsreinigungLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await _pagedByUser();
      return rows.map((r) => EroeffnungsreinigungMapper.fromDto(Eroeffnungsreinigung.fromJson(r))).toList();
    }
    return IsarService.eroeffnungsreinigungFindAll();
  }

  static Future<EroeffnungsreinigungLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('eroeffnungsreinigungen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return EroeffnungsreinigungMapper.fromDto(Eroeffnungsreinigung.fromJson(rows.first));
    }
    return IsarService.eroeffnungsreinigungGet(int.parse(id));
  }

  static Stream<List<EroeffnungsreinigungLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.eroeffnungsreinigungWatchAll();
  }

  static Future<List<EroeffnungsreinigungLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(col: 'betrieb_id', val: betriebId);
      return rows.map((r) => EroeffnungsreinigungMapper.fromDto(Eroeffnungsreinigung.fromJson(r))).toList();
    }
    return IsarService.eroeffnungsreinigungFilterByBetrieb(betriebId);
  }

  static Stream<List<EroeffnungsreinigungLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.eroeffnungsreinigungWatchByBetrieb(betriebId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      return (await _pagedByUser()).length;
    }
    return IsarService.eroeffnungsreinigungCount();
  }

  static Future<void> save(EroeffnungsreinigungLocal er) async {
    er.userId = _userId;
    if (kIsWeb) {
      final json = EroeffnungsreinigungMapper.toJson(er);
      await SupabaseService.client.from('eroeffnungsreinigungen').upsert(json);
      return;
    }
    er.isSynced = false;
    er.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eroeffnungsreinigungPut(er);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('eroeffnungsreinigungen').delete().eq('id', id);
      return;
    }
    final local = await IsarService.eroeffnungsreinigungGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('eroeffnungsreinigungen').delete().eq('id', local!.serverId!);
    }
    await IsarService.eroeffnungsreinigungDelete(int.parse(id));
  }
}
