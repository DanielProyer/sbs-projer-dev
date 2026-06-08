import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class CamtPrueflisteRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<CamtPrueflisteEintrag>> getOffen() async {
    final rows = await SupabaseService.client
        .from('camt_pruefliste')
        .select()
        .eq('status', 'offen')
        .order('booking_datum');
    return rows.map((r) => CamtPrueflisteEintrag.fromJson(r)).toList();
  }

  static Future<Set<String>> getAlleTxKeys() async {
    final rows = await SupabaseService.client
        .from('camt_pruefliste')
        .select('tx_key');
    return rows.map((r) => r['tx_key'] as String).toSet();
  }

  static Future<void> insert(CamtPrueflisteEintrag e) async {
    await SupabaseService.client
        .from('camt_pruefliste')
        .upsert(e.toInsert(_userId),
            onConflict: 'user_id,tx_key', ignoreDuplicates: true);
  }

  static Future<void> setStatus(String id, String status) async {
    await SupabaseService.client
        .from('camt_pruefliste')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
