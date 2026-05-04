import 'package:sbs_projer_app/data/models/preis.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Preise (kein Isar nötig, selten geändert).
class PreisRepository {
  static String get _userId => SupabaseService.dataUserId;

  /// Lädt die aktuell gültigen Preise für ein bestimmtes Datum.
  static Future<Preis?> getAktuell({DateTime? datum}) async {
    final d = datum ?? DateTime.now();
    final datumStr = d.toIso8601String().split('T').first;
    final rows = await SupabaseService.client
        .from('preise')
        .select()
        .eq('user_id', _userId)
        .lte('gueltig_ab', datumStr)
        .order('gueltig_ab', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Preis.fromJson(rows.first);
  }

  /// Lädt alle Preisversionen, sortiert nach gueltig_ab absteigend.
  static Future<List<Preis>> getAll() async {
    final rows = await SupabaseService.client
        .from('preise')
        .select()
        .eq('user_id', _userId)
        .order('gueltig_ab', ascending: false);
    return rows.map((r) => Preis.fromJson(r)).toList();
  }

  /// Erstellt eine neue Preisversion oder aktualisiert eine bestehende.
  static Future<void> save(Map<String, dynamic> data) async {
    data['user_id'] = _userId;
    if (data['id'] != null) {
      await SupabaseService.client
          .from('preise')
          .update(data)
          .eq('id', data['id']);
    } else {
      await SupabaseService.client.from('preise').insert(data);
    }
  }

  /// Aktualisiert einzelne Felder der aktuellen Preisversion.
  static Future<void> updateFields(String preisId, Map<String, dynamic> fields) async {
    await SupabaseService.client.from('preise').update(fields).eq('id', preisId);
  }

  /// Löscht eine Preisversion.
  static Future<void> delete(String id) async {
    await SupabaseService.client.from('preise').delete().eq('id', id);
  }
}
