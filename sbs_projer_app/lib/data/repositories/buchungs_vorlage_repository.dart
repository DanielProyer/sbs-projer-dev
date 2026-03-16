import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Buchungsvorlagen (kein Isar).
class BuchungsVorlageRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<BuchungsVorlage>> getAll() async {
    final rows = await SupabaseService.client
        .from('buchungs_vorlagen')
        .select()
        .eq('user_id', _userId)
        .order('geschaeftsfall_id');
    return rows.map((r) => BuchungsVorlage.fromJson(r)).toList();
  }

  static Stream<List<BuchungsVorlage>> watchAll() {
    return Stream.fromFuture(getAll());
  }

  static Future<BuchungsVorlage?> getById(String id) async {
    final rows = await SupabaseService.client
        .from('buchungs_vorlagen')
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return BuchungsVorlage.fromJson(rows.first);
  }

  static Future<List<BuchungsVorlage>> getByTrigger(String trigger) async {
    final rows = await SupabaseService.client
        .from('buchungs_vorlagen')
        .select()
        .eq('user_id', _userId)
        .eq('auto_trigger', trigger)
        .eq('ist_aktiv', true);
    return rows.map((r) => BuchungsVorlage.fromJson(r)).toList();
  }

  /// Gibt nur manuelle Vorlagen zurück (ohne auto_trigger).
  static Future<List<BuchungsVorlage>> getManuell() async {
    final rows = await SupabaseService.client
        .from('buchungs_vorlagen')
        .select()
        .eq('user_id', _userId)
        .isFilter('auto_trigger', null)
        .eq('ist_aktiv', true)
        .order('geschaeftsfall_id');
    return rows.map((r) => BuchungsVorlage.fromJson(r)).toList();
  }
}
