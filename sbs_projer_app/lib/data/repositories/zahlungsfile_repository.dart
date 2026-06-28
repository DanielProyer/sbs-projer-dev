import 'package:sbs_projer_app/data/models/zahlungsfile.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für erstellte Zahlungsfiles (pain.001, kein Isar).
class ZahlungsfileRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Erstellt ein Zahlungsfile-Eintrag und gibt das DB-Ergebnis zurück (inkl. ID).
  static Future<Zahlungsfile> create(Map<String, dynamic> json) async {
    json['user_id'] = _userId;
    json.remove('id');
    final rows = await SupabaseService.client
        .from('zahlungsfile')
        .insert(json)
        .select();
    return Zahlungsfile.fromJson(rows.first);
  }

  /// Liefert alle Zahlungsfiles des Users, neueste zuerst.
  static Future<List<Zahlungsfile>> getAll() async {
    final rows = await SupabaseService.client
        .from('zahlungsfile')
        .select()
        .eq('user_id', _userId)
        .order('erstellt_am', ascending: false);
    return rows.map((r) => Zahlungsfile.fromJson(r)).toList();
  }
}
