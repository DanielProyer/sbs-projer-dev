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

  /// txKeys, die einen Re-Import blockieren sollen: nur ERLEDIGTE/IGNORIERTE
  /// Einträge. Offene Einträge werden beim nächsten Import neu bewertet —
  /// mit aktuellem Datenstand kann aus einem offenen Fall ein buchbarer
  /// Vorschlag werden (Fall Heineken-Gutschriften: Monatsrechnungen
  /// existierten beim ersten Import noch nicht). Der Upsert in [insert]
  /// verhindert Duplikate, [deleteByTxKey] räumt nach einer Buchung ab.
  static Future<Set<String>> getBlockierendeTxKeys() async {
    final rows = await SupabaseService.client
        .from('camt_pruefliste')
        .select('tx_key')
        .neq('status', 'offen');
    return rows.map((r) => r['tx_key'] as String).toSet();
  }

  static Future<void> insert(CamtPrueflisteEintrag e) async {
    await SupabaseService.client
        .from('camt_pruefliste')
        .upsert(e.toInsert(_userId),
            onConflict: 'user_id,tx_key', ignoreDuplicates: true);
  }

  /// Entfernt einen Prüflisten-Eintrag anhand des camt-Schlüssels (z.B. nach
  /// einer Reversal, damit die Belastung wieder importierbar wird).
  static Future<void> deleteByTxKey(String txKey) async {
    await SupabaseService.client
        .from('camt_pruefliste')
        .delete()
        .eq('user_id', _userId)
        .eq('tx_key', txKey);
  }

  static Future<void> setStatus(String id, String status) async {
    await SupabaseService.client
        .from('camt_pruefliste')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
