import 'package:sbs_projer_app/data/models/material_verbrauch.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Materialverbrauch (read-only).
class MaterialVerbrauchRepository {
  static Future<List<MaterialVerbrauch>> getByLager(String lagerId) async {
    final rows = await SupabaseService.client
        .from('material_verbrauch')
        .select()
        .eq('lager_id', lagerId)
        .order('verbraucht_am', ascending: false);
    return rows.map((r) => MaterialVerbrauch.fromJson(r)).toList();
  }
}
