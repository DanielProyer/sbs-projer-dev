import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Rechnungen (kein Isar).
class RechnungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<Rechnung>> getAll() async {
    final rows = await SupabaseService.client
        .from('rechnungen')
        .select()
        .eq('user_id', _userId)
        .order('rechnungsdatum', ascending: false);
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
    final rows = await SupabaseService.client
        .from('rechnungen')
        .select()
        .eq('user_id', _userId)
        .eq('betrieb_id', betriebId)
        .order('rechnungsdatum', ascending: false);
    return rows.map((r) => Rechnung.fromJson(r)).toList();
  }

  static Stream<List<Rechnung>> watchByBetrieb(String betriebId) {
    return Stream.fromFuture(getByBetrieb(betriebId));
  }

  static Future<int> count() async {
    final rows = await SupabaseService.client
        .from('rechnungen')
        .select('id')
        .eq('user_id', _userId);
    return rows.length;
  }

  static Future<int> countOffene() async {
    final rows = await SupabaseService.client
        .from('rechnungen')
        .select('id')
        .eq('user_id', _userId)
        .inFilter('zahlungsstatus', ['offen', 'ueberfaellig']);
    return rows.length;
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

  static Future<void> delete(String id) async {
    await SupabaseService.client
        .from('rechnungen')
        .delete()
        .eq('id', id);
  }
}
