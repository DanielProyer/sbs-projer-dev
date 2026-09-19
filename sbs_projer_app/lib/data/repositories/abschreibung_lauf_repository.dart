import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Abschreibungsläufe (Migration 194). Nur Web/Supabase — der Schritt gehört
/// zum Jahresabschluss und läuft nie offline.
class AbschreibungLaufRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<AbschreibungLauf>> getAll() async {
    final rows = await SupabaseService.client
        .from('abschreibung_laeufe')
        .select()
        .eq('user_id', _userId)
        .order('geschaeftsjahr', ascending: false)
        .order('created_at', ascending: false);
    return [for (final r in rows) AbschreibungLauf.fromJson(r)];
  }

  static Future<List<AbschreibungPosition>> getPositionen(String laufId) async {
    final rows = await SupabaseService.client
        .from('abschreibung_positionen')
        .select()
        .eq('lauf_id', laufId)
        .order('jahrgang')
        .order('rechnungsnummer')
        .order('id');
    return [for (final r in rows) AbschreibungPosition.fromJson(r)];
  }

  /// Bucht alle [rechnungIds] per 31.12.[geschaeftsjahr] in EINER
  /// Transaktion (SQL-Funktion prüft jede Rechnung nochmals). Liefert die
  /// Lauf-ID.
  static Future<String> buchen({
    required int geschaeftsjahr,
    required List<String> rechnungIds,
  }) async {
    final res = await SupabaseService.client.rpc(
      'abschreibung_jahrgang_buchen',
      params: {
        'p_geschaeftsjahr': geschaeftsjahr,
        'p_rechnung_ids': rechnungIds,
      },
    );
    return res as String;
  }

  /// Nimmt einen Lauf zurück (Buchungen weg, Status vorher). Liefert die
  /// Zahl der zurückgesetzten Rechnungen.
  static Future<int> zuruecknehmen(String laufId) async {
    final res = await SupabaseService.client.rpc(
      'abschreibung_lauf_zuruecknehmen',
      params: {'p_lauf': laufId},
    );
    return (res as num).toInt();
  }
}
