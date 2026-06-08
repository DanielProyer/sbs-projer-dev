import 'package:sbs_projer_app/data/models/camt_regel.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class CamtRegelRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<CamtRegel>> getAktive() async {
    final rows = await SupabaseService.client
        .from('camt_regel')
        .select()
        .eq('ist_aktiv', true)
        .order('prioritaet', ascending: false);
    return rows.map((r) => CamtRegel.fromJson(r)).toList();
  }

  static Future<List<CamtRegel>> getAll() async {
    final rows = await SupabaseService.client
        .from('camt_regel')
        .select()
        .order('bezeichnung');
    return rows.map((r) => CamtRegel.fromJson(r)).toList();
  }

  static Future<void> insert(CamtRegel r) async {
    await SupabaseService.client
        .from('camt_regel')
        .insert(r.toInsert(_userId));
  }

  static Future<void> setAktiv(String id, bool aktiv) async {
    await SupabaseService.client
        .from('camt_regel')
        .update({'ist_aktiv': aktiv, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  static Future<void> delete(String id) async {
    await SupabaseService.client.from('camt_regel').delete().eq('id', id);
  }
}
