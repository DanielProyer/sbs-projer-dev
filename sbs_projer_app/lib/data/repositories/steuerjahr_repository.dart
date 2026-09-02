import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class SteuerjahrRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<Steuerjahr>> getAll() async {
    final rows = await SupabaseService.client
        .from('steuerjahre')
        .select()
        .eq('user_id', _userId)
        .order('jahr', ascending: false)
        .order('id');
    return rows.map((r) => Steuerjahr.fromJson(r)).toList();
  }

  /// Anlegen oder aktualisieren (eindeutig über user_id + jahr).
  static Future<Steuerjahr> upsert(Steuerjahr s) async {
    final rows = await SupabaseService.client
        .from('steuerjahre')
        .upsert({
          ...s.toJson(),
          'user_id': _userId,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,jahr')
        .select();
    return Steuerjahr.fromJson(rows.first);
  }
}
