import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/stoerung.dart';
import 'package:sbs_projer_app/data/mappers/stoerung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class StoerungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Holt ALLE Zeilen seitenweise (PostgREST deckelt sonst bei 1000).
  /// Erste Seite + Folgeseiten parallel; `.order('id')` = stabile Seitengrenzen.
  static Future<List<Map<String, dynamic>>> _pagedByUser(
      {String? col, String? val}) async {
    const pageSize = 1000;

    Future<List<Map<String, dynamic>>> fetchPage(int page) {
      var q = SupabaseService.client
          .from('stoerungen')
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

  static Future<List<StoerungLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await _pagedByUser();
      return rows.map((r) => StoerungMapper.fromDto(Stoerung.fromJson(r))).toList();
    }
    return IsarService.stoerungFindAll();
  }

  static Future<StoerungLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('stoerungen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return StoerungMapper.fromDto(Stoerung.fromJson(rows.first));
    }
    return IsarService.stoerungGet(int.parse(id));
  }

  static Stream<List<StoerungLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.stoerungWatchAll();
  }

  static Future<List<StoerungLocal>> getByAnlage(String anlageId) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(col: 'anlage_id', val: anlageId);
      return rows.map((r) => StoerungMapper.fromDto(Stoerung.fromJson(r))).toList();
    }
    return IsarService.stoerungFilterByAnlage(anlageId);
  }

  static Future<List<StoerungLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(col: 'betrieb_id', val: betriebId);
      return rows.map((r) => StoerungMapper.fromDto(Stoerung.fromJson(r))).toList();
    }
    return IsarService.stoerungFilterByBetrieb(betriebId);
  }

  static Stream<List<StoerungLocal>> watchByAnlage(String anlageId) {
    if (kIsWeb) return Stream.fromFuture(getByAnlage(anlageId));
    return IsarService.stoerungWatchByAnlage(anlageId);
  }

  static Stream<List<StoerungLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.stoerungWatchByBetrieb(betriebId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      return (await _pagedByUser()).length;
    }
    return IsarService.stoerungCount();
  }

  static Future<void> save(StoerungLocal stoerung) async {
    stoerung.userId = _userId;
    if (kIsWeb) {
      final json = StoerungMapper.toJson(stoerung);
      await SupabaseService.client.from('stoerungen').upsert(json);
      return;
    }
    stoerung.isSynced = false;
    stoerung.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.stoerungPut(stoerung);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('stoerungen').delete().eq('id', id);
      return;
    }
    // Native: Supabase löschen, dann Isar aufräumen
    final local = await IsarService.stoerungGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('stoerungen').delete().eq('id', local!.serverId!);
    }
    await IsarService.stoerungDelete(int.parse(id));
  }

}
