import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Lager/Fahrzeugbestand (kein Isar).
class LagerRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<Lager>> getAll() async {
    final rows = await SupabaseService.client
        .from('lager')
        .select()
        .eq('user_id', _userId)
        .order('name');
    return rows.map((r) => Lager.fromJson(r)).toList();
  }

  static Stream<List<Lager>> watchAll() {
    return Stream.fromFuture(getAll());
  }

  static Future<Lager?> getById(String id) async {
    final rows = await SupabaseService.client
        .from('lager')
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return Lager.fromJson(rows.first);
  }

  static Future<int> count() async {
    final rows = await SupabaseService.client
        .from('lager')
        .select('id')
        .eq('user_id', _userId);
    return rows.length;
  }

  static Future<int> countNiedrig() async {
    final rows = await SupabaseService.client
        .from('lager')
        .select('id')
        .eq('user_id', _userId)
        .eq('bestand_niedrig', true);
    return rows.length;
  }

  static Future<List<Lager>> getBestellliste() async {
    final rows = await SupabaseService.client
        .from('lager')
        .select()
        .eq('user_id', _userId)
        .eq('bestand_niedrig', true)
        .order('name');
    return rows.map((r) => Lager.fromJson(r)).toList();
  }

  static Future<Lager> create(Map<String, dynamic> json) async {
    json['user_id'] = SupabaseService.currentUser!.id;
    json.remove('id');
    final rows = await SupabaseService.client
        .from('lager')
        .insert(json)
        .select();
    return Lager.fromJson(rows.first);
  }

  static Future<void> update(String id, Map<String, dynamic> fields) async {
    await SupabaseService.client
        .from('lager')
        .update(fields)
        .eq('id', id);
  }

  static Future<void> delete(String id) async {
    await SupabaseService.client
        .from('lager')
        .delete()
        .eq('id', id);
  }
}
