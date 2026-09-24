import 'package:sbs_projer_app/core/util/mahnfall_regeln.dart';
import 'package:sbs_projer_app/data/models/mahnfall.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Web-only wie `MahnschreibenRepository` — Mahnfälle gibt es nur online.
class MahnfallRepository {
  static const _tabelle = 'mahnfaelle';

  static String dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Mahnfall> insert(Map<String, dynamic> json) async {
    final row = await SupabaseService.client.from(_tabelle).insert(json).select().single();
    return Mahnfall.fromJson(row);
  }

  static Future<Mahnfall?> getById(String id) async {
    final row = await SupabaseService.client.from(_tabelle).select().eq('id', id).maybeSingle();
    return row == null ? null : Mahnfall.fromJson(row);
  }

  /// Offene Fälle (status != erledigt). Wenige Zeilen — Filter in Dart,
  /// nicht per .neq() (NULL-Falle, CLAUDE.md), eindeutig sortiert.
  static Future<List<Mahnfall>> getOffene() async {
    final rows = await SupabaseService.client
        .from(_tabelle)
        .select()
        .order('eroeffnet_am', ascending: false)
        .order('id');
    return rows.map((r) => Mahnfall.fromJson(r)).where((f) => f.offen).toList();
  }

  /// Fälle, die ihre Rechnungen sperren (`sperrtRechnungen`: offen, oder
  /// erledigt nach Heineken-Übernahme bzw. zurückgezogener Betreibung —
  /// Review Teil 2, I-3). Filter in Dart (NULL-Falle bei `erledigung`).
  static Future<List<Mahnfall>> getSperrendeFaelle() async {
    final rows = await SupabaseService.client
        .from(_tabelle)
        .select()
        .order('eroeffnet_am', ascending: false)
        .order('id');
    return rows.map((r) => Mahnfall.fromJson(r)).where(sperrtRechnungen).toList();
  }

  /// Update nur, wenn der Fall in der DB noch [alterStatus] hat
  /// (Review Teil 2, M-2: optimistische Sperre gegen zwei Tabs / veraltete
  /// Seite). `null`, wenn keine Zeile getroffen wurde.
  static Future<Mahnfall?> updateWennStatus(
    String id,
    String alterStatus,
    Map<String, dynamic> felder,
  ) async {
    final row = await SupabaseService.client
        .from(_tabelle)
        .update({...felder, 'aktualisiert_am': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('status', alterStatus)
        .select()
        .maybeSingle();
    return row == null ? null : Mahnfall.fromJson(row);
  }

  /// Erledigte Fälle mit noch offener Heineken-Übernahme (Notiz trägt die
  /// Markierung `MahnfallService.kUebernahmeOffen`) — für die Glocke
  /// (Task 7). Alle Zeilen laden und in Dart filtern (kleine Tabelle,
  /// Notiz-Filter geht nicht per Spaltenvergleich), eindeutig sortiert.
  static Future<List<Mahnfall>> getMitOffenerUebernahme() async {
    final rows = await SupabaseService.client
        .from(_tabelle)
        .select()
        .order('eroeffnet_am', ascending: false)
        .order('id');
    return rows
        .map((r) => Mahnfall.fromJson(r))
        .where((f) =>
            !f.offen && (f.notiz ?? '').contains('[UEBERNAHME OFFEN]'))
        .toList();
  }

  static Future<List<Mahnfall>> getByRechnung(String rechnungId) async {
    final rows = await SupabaseService.client
        .from(_tabelle)
        .select()
        .contains('rechnung_ids', [rechnungId])
        .order('eroeffnet_am', ascending: false)
        .order('id');
    return rows.map((r) => Mahnfall.fromJson(r)).toList();
  }

  static Future<Mahnfall> update(String id, Map<String, dynamic> felder) async {
    final row = await SupabaseService.client
        .from(_tabelle)
        .update({...felder, 'aktualisiert_am': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Mahnfall.fromJson(row);
  }

  /// Protokoll-Pfade (Bucket `reinigung-fotos`) ALLER Reinigungspositionen
  /// einer Rechnung — Weg wie `_findProtokollPfad` im Rechnungsdetail
  /// (`rechnungs_positionen.service_id` → `reinigungen.protokoll_foto_pfad`),
  /// aber nicht nur die erste Position: Eine Jahres-/Sammelrechnung trägt
  /// mehrere Reinigungen, und bei einem Rechtsvorschlag zählt jedes Protokoll.
  static Future<List<String>> protokollPfadeZuRechnung(String rechnungId) async {
    final pos = await SupabaseService.client
        .from('rechnungs_positionen')
        .select('service_id')
        .eq('rechnung_id', rechnungId)
        .eq('service_typ', 'reinigung')
        .order('id');
    final ids = <String>{
      for (final p in pos)
        if ((p['service_id']?.toString() ?? '').isNotEmpty) p['service_id'].toString(),
    };
    if (ids.isEmpty) return const [];
    final rein = await SupabaseService.client
        .from('reinigungen')
        .select('id, datum, protokoll_foto_pfad')
        .inFilter('id', ids.toList())
        .order('datum')
        .order('id');
    return [
      for (final r in rein)
        if ((r['protokoll_foto_pfad']?.toString() ?? '').isNotEmpty)
          r['protokoll_foto_pfad'].toString(),
    ];
  }

  /// Nur für den Testmodus: einen frisch eröffneten Fall ohne Ergebnis
  /// wieder entfernen (siehe MahnfallService.zuruecknehmen).
  static Future<void> delete(String id) async {
    await SupabaseService.client.from(_tabelle).delete().eq('id', id);
  }
}
