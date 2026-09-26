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

  /// Ein Schreiben per Id — für «Zurücknehmen» direkt nach einem
  /// abgebrochenen Mahnlauf (`MahnlaufFehler.mahnschreibenId`).
  static Future<Mahnschreiben?> getById(String id) async {
    final row =
        await SupabaseService.client.from(_tabelle).select().eq('id', id).maybeSingle();
    return row == null ? null : Mahnschreiben.fromJson(row);
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
