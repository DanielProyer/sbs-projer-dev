import 'package:sbs_projer_app/data/models/mahnfall.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Web-only wie `MahnschreibenRepository` — Mahnfälle gibt es nur online.
class MahnfallRepository {
  static const _tabelle = 'mahnfaelle';

  static String dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Mahnfall> insert(Map<String, dynamic> json) async {
    final row = await SupabaseService.client.from(_tabelle).insert(json).select().single();
    return Mahnfall.fromJson(row);
  }

  static Future<Mahnfall?> getById(String id) async {
    final row = await SupabaseService.client.from(_tabelle).select().eq('id', id).maybeSingle();
    return row == null ? null : Mahnfall.fromJson(row);
  }

  /// Offene Fälle (status != erledigt). Wenige Zeilen — Filter in Dart,
  /// nicht per .neq() (NULL-Falle, CLAUDE.md), eindeutig sortiert.
  static Future<List<Mahnfall>> getOffene() async {
    final rows = await SupabaseService.client
        .from(_tabelle)
        .select()
        .order('eroeffnet_am', ascending: false)
        .order('id');
    return rows.map((r) => Mahnfall.fromJson(r)).where((f) => f.offen).toList();
  }

  static Future<List<Mahnfall>> getByRechnung(String rechnungId) async {
    final rows = await SupabaseService.client
        .from(_tabelle)
        .select()
        .contains('rechnung_ids', [rechnungId])
        .order('eroeffnet_am', ascending: false)
        .order('id');
    return rows.map((r) => Mahnfall.fromJson(r)).toList();
  }

  static Future<Mahnfall> update(String id, Map<String, dynamic> felder) async {
    final row = await SupabaseService.client
        .from(_tabelle)
        .update({...felder, 'aktualisiert_am': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Mahnfall.fromJson(row);
  }

  /// Nur für den Testmodus: einen frisch eröffneten Fall ohne Ergebnis
  /// wieder entfernen (siehe MahnfallService.zuruecknehmen).
  static Future<void> delete(String id) async {
    await SupabaseService.client.from(_tabelle).delete().eq('id', id);
  }
}
