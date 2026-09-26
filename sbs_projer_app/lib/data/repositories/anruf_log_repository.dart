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
      if (notiz != null) 'notiz': notiz,
    });
  }

}
