import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/reinigung.dart';
import 'package:sbs_projer_app/data/mappers/reinigung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class ReinigungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Holt ALLE Zeilen seitenweise (PostgREST deckelt sonst bei 1000).
  ///
  /// Performance: Bei grossen Ergebnissen (volle Historie, ~8600 Reinigungen)
  /// werden die Folgeseiten NICHT mehr sequenziell geladen, sondern in
  /// parallelen Wellen (`Future.wait`) — das spart die aufsummierten
  /// Round-Trips (statt 9 nacheinander nur noch 2 Wellen). Kleine Ergebnisse
  /// (z.B. je Anlage/Betrieb) brauchen weiterhin nur 1 Request.
  ///
  /// Der zusätzliche `.order('id')`-Tiebreaker macht die Seitengrenzen
  /// deterministisch (kein Doppeln/Verlieren von Zeilen mit gleichem `datum`).
  static Future<List<Map<String, dynamic>>> _pagedByUser({String? col, String? val}) async {
    const pageSize = 1000;

    Future<List<Map<String, dynamic>>> fetchPage(int page) {
      var q = SupabaseService.client
          .from('reinigungen')
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
    // Erste Seite separat — kleine Ergebnisse sind damit nach 1 Request fertig.
    final first = await fetchPage(0);
    all.addAll(first);
    if (first.length < pageSize) return all;

    // Grosse Ergebnisse: restliche Seiten in parallelen Wellen laden.
    const batch = 8;
    int nextPage = 1;
    while (true) {
      final pages = await Future.wait(
        [for (int i = 0; i < batch; i++) fetchPage(nextPage + i)],
      );
      for (final rows in pages) {
        all.addAll(rows);
      }
      // Die Seite mit dem höchsten Offset entscheidet: kürzer als pageSize ->
      // es folgen keine weiteren Zeilen mehr.
      if (pages.last.length < pageSize) break;
      nextPage += batch;
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
