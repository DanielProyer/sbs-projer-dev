import 'package:sbs_projer_app/data/models/konto.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Kontenplan (kein Isar).
class KontoRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<Konto>> getAll() async {
    final rows = await SupabaseService.client
        .from('konten')
        .select()
        .eq('user_id', _userId)
        .order('kontonummer');
    return rows.map((r) => Konto.fromJson(r)).toList();
  }

  static Stream<List<Konto>> watchAll() {
    return Stream.fromFuture(getAll());
  }

  static Future<int> count() async {
    final rows = await SupabaseService.client
        .from('konten')
        .select('id')
        .eq('user_id', _userId);
    return rows.length;
  }
}
