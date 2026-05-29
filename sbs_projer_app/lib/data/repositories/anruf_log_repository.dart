import 'package:sbs_projer_app/data/models/anruf_log.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Anruf-Logs (kein Isar/Offline nötig).
class AnrufLogRepository {
  static String get _userId => SupabaseService.dataUserId;

  /// Schreibt einen Anruf-Log-Eintrag.
  static Future<void> log(String kontaktId, {String? notiz}) async {
    await SupabaseService.client.from('anruf_logs').insert({
      'user_id': _userId,
      'kontakt_id': kontaktId,
      'anruf_zeitpunkt': DateTime.now().toUtc().toIso8601String(),
      'notiz': ?notiz,
    });
  }

  /// Letzte Anrufe (neueste zuerst), optional limitiert.
  static Future<List<AnrufLog>> getLetzteAnrufe({int limit = 20}) async {
    final rows = await SupabaseService.client
        .from('anruf_logs')
        .select()
        .eq('user_id', _userId)
        .order('anruf_zeitpunkt', ascending: false)
        .limit(limit);
    return rows.map((r) => AnrufLog.fromJson(r)).toList();
  }

  /// Anrufe für einen bestimmten Kontakt.
  static Future<List<AnrufLog>> getByKontakt(String kontaktId) async {
    final rows = await SupabaseService.client
        .from('anruf_logs')
        .select()
        .eq('user_id', _userId)
        .eq('kontakt_id', kontaktId)
        .order('anruf_zeitpunkt', ascending: false);
    return rows.map((r) => AnrufLog.fromJson(r)).toList();
  }
}
