import 'package:sbs_projer_app/data/models/biersorte.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Biersorten (kein Isar nötig).
class BiersorteRepository {
  static String get _userId => SupabaseService.dataUserId;

  /// Lädt alle Biersorten des Users.
  static Future<List<Biersorte>> getAll() async {
    final rows = await SupabaseService.client
        .from('biersorten')
        .select()
        .eq('user_id', _userId)
        .order('name');
    return rows.map((r) => Biersorte.fromJson(r)).toList();
  }

  /// Erstellt eine neue Biersorte.
  static Future<void> create(Map<String, dynamic> data) async {
    data['user_id'] = _userId;
    await SupabaseService.client.from('biersorten').insert(data);
  }

  /// Aktualisiert eine Biersorte (z.B. Kategorie ändern).
  static Future<void> update(String id, Map<String, dynamic> fields) async {
    await SupabaseService.client
        .from('biersorten')
        .update(fields)
        .eq('id', id);
  }

  /// Löscht eine Biersorte.
  static Future<void> delete(String id) async {
    await SupabaseService.client.from('biersorten').delete().eq('id', id);
  }

  /// Zählt Bierleitungen pro Biersorte (name → count).
  static Future<Map<String, int>> getLeitungenCounts() async {
    final rows = await SupabaseService.client
        .from('bierleitungen')
        .select('biersorte')
        .eq('user_id', _userId)
        .not('biersorte', 'is', null);
    final counts = <String, int>{};
    for (final r in rows) {
      final sorte = (r['biersorte'] as String?)?.trim() ?? '';
      if (sorte.isEmpty) continue;
      counts[sorte] = (counts[sorte] ?? 0) + 1;
    }
    return counts;
  }
}
