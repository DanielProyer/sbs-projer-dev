import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Rechnungen (kein Isar).
class RechnungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Holt ALLE Zeilen seitenweise (PostgREST deckelt sonst bei 1000).
  static Future<List<Map<String, dynamic>>> _pagedByUser({String? col, String? val}) async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      var q = SupabaseService.client.from('rechnungen').select().eq('user_id', _userId);
      if (col != null) q = q.eq(col, val!);
      final rows = await q.order('created_at', ascending: false).range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all;
  }

  static Future<List<Rechnung>> getAll() async {
    final rows = await _pagedByUser();
    return rows.map((r) => Rechnung.fromJson(r)).toList();
  }

  static Stream<List<Rechnung>> watchAll() {
    return Stream.fromFuture(getAll());
  }

  static Future<Rechnung?> getById(String id) async {
    final rows = await SupabaseService.client
        .from('rechnungen')
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return Rechnung.fromJson(rows.first);
  }

  static Future<List<Rechnung>> getByBetrieb(String betriebId) async {
    final rows = await _pagedByUser(col: 'betrieb_id', val: betriebId);
    return rows.map((r) => Rechnung.fromJson(r)).toList();
  }

  static Stream<List<Rechnung>> watchByBetrieb(String betriebId) {
    return Stream.fromFuture(getByBetrieb(betriebId));
  }

  static Future<int> count() async {
    int total = 0;
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('rechnungen').select('id').eq('user_id', _userId)
          .range(from, from + pageSize - 1);
      total += rows.length;
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return total;
  }

  static Future<int> countOffene() async {
    int total = 0;
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('rechnungen').select('id').eq('user_id', _userId)
          .not('zahlungsstatus', 'in', '("bezahlt","abgeschrieben")')
          .range(from, from + pageSize - 1);
      total += rows.length;
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return total;
  }

  /// Erstellt eine Rechnung und gibt das DB-Ergebnis zurück (inkl. generierter ID).
  static Future<Rechnung> create(Map<String, dynamic> json) async {
    json['user_id'] = _userId;
    json.remove('id');
    final rows = await SupabaseService.client
        .from('rechnungen')
        .insert(json)
        .select();
    return Rechnung.fromJson(rows.first);
  }

  /// Aktualisiert einzelne Felder einer Rechnung.
  static Future<void> update(String id, Map<String, dynamic> fields) async {
    await SupabaseService.client
        .from('rechnungen')
        .update(fields)
        .eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> getMahnwesenDashboard() async {
    final rows = await SupabaseService.client
        .from('view_mahnwesen_dashboard')
        .select()
        .eq('user_id', _userId);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> delete(String id) async {
    await SupabaseService.client
        .from('rechnungen')
        .delete()
        .eq('id', id);
  }
}
