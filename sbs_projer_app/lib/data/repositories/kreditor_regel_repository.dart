import 'package:sbs_projer_app/data/models/kreditor_regel.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Lieferanten-Lernregeln (Kreditor, kein Isar).
class KreditorRegelRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Liefert alle aktiven Regeln des Users, höchste Priorität zuerst.
  static Future<List<KreditorRegel>> getAllActive() async {
    final rows = await SupabaseService.client
        .from('kreditor_regel')
        .select()
        .eq('user_id', _userId)
        .eq('ist_aktiv', true)
        .order('prioritaet', ascending: false);
    return rows.map((r) => KreditorRegel.fromJson(r)).toList();
  }

  /// Liefert alle Regeln des Users (inkl. inaktive), höchste Priorität zuerst.
  static Future<List<KreditorRegel>> getAll() async {
    final rows = await SupabaseService.client
        .from('kreditor_regel')
        .select()
        .eq('user_id', _userId)
        .order('prioritaet', ascending: false);
    return rows.map((r) => KreditorRegel.fromJson(r)).toList();
  }

  /// Erstellt eine Regel und gibt das DB-Ergebnis zurück (inkl. ID).
  static Future<KreditorRegel> create(Map<String, dynamic> json) async {
    json['user_id'] = _userId;
    json.remove('id');
    final rows = await SupabaseService.client
        .from('kreditor_regel')
        .insert(json)
        .select();
    return KreditorRegel.fromJson(rows.first);
  }

  /// Aktualisiert einzelne Felder einer Regel.
  static Future<void> update(String id, Map<String, dynamic> fields) async {
    await SupabaseService.client
        .from('kreditor_regel')
        .update(fields)
        .eq('id', id);
  }

  /// Löscht eine Regel.
  static Future<void> delete(String id) async {
    await SupabaseService.client.from('kreditor_regel').delete().eq('id', id);
  }
}
