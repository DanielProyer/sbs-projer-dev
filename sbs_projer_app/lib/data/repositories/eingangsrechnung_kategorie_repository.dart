import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für die Kategorie-Config (global).
class EingangsrechnungKategorieRepository {
  static Future<List<EingangsrechnungKategorie>> getAll() async {
    final rows = await SupabaseService.client
        .from('eingangsrechnung_kategorie')
        .select()
        .eq('ist_aktiv', true)
        .order('reihenfolge');
    return rows.map((r) => EingangsrechnungKategorie.fromJson(r)).toList();
  }
}
