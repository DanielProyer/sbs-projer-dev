import 'package:sbs_projer_app/data/models/mahnschreiben.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Web-only (Supabase-Direktzugriff, kein Isar) — wie `CamtPrueflisteRepository`.
/// Das Mahnprotokoll gibt es nur online; ein Mahnlauf setzt eine Internet-
/// verbindung (Mail, DB) ohnehin voraus.
class MahnschreibenRepository {
  static const _tabelle = 'mahnschreiben';

  static Future<void> insert(Map<String, dynamic> json) async {
    await SupabaseService.client.from(_tabelle).insert(json);
  }

  /// Neueste zuerst — eindeutig sortiert (`id` als zweiter Schlüssel, siehe
  /// CLAUDE.md «Seitenweises Laden»), auch wenn hier noch nicht seitenweise
  /// geladen wird: ein Betrieb hat praktisch nie genug Mahnschreiben, um die
  /// 1000er-Grenze von PostgREST zu erreichen.
  static Future<List<Mahnschreiben>> getByBetrieb(String betriebId) async {
    final rows = await SupabaseService.client
        .from(_tabelle)
        .select()
        .eq('betrieb_id', betriebId)
        .order('erstellt_am', ascending: false)
        .order('id');
    return rows.map((r) => Mahnschreiben.fromJson(r)).toList();
  }

  /// Alle Mahnschreiben, die [rechnungId] enthalten (`rechnung_ids @> {id}`).
  static Future<List<Mahnschreiben>> getByRechnung(String rechnungId) async {
    final rows = await SupabaseService.client
        .from(_tabelle)
        .select()
        .contains('rechnung_ids', [rechnungId])
        .order('erstellt_am', ascending: false)
        .order('id');
    return rows.map((r) => Mahnschreiben.fromJson(r)).toList();
  }

  /// UTC, wie überall sonst in der App bei Zeitstempeln (Datumsdifferenzen
  /// in UTC rechnen — Sommerzeit frisst sonst einen Tag, CLAUDE.md).
  static Future<void> markiereZurueckgenommen(String id) async {
    await SupabaseService.client
        .from(_tabelle)
        .update({'zurueckgenommen_am': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
