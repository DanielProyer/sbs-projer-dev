import 'package:sbs_projer_app/data/models/material_kategorie.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Material-Kategorien (read-only).
class MaterialKategorieRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<MaterialKategorie>> getAll() async {
    final rows = await SupabaseService.client
        .from('material_kategorien')
        .select()
        .eq('user_id', _userId)
        .order('sortierung');
    return rows.map((r) => MaterialKategorie.fromJson(r)).toList();
  }
}
