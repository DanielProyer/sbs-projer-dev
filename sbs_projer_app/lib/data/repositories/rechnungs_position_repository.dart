import 'package:sbs_projer_app/data/models/rechnungs_position.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Rechnungspositionen (kein Isar).
class RechnungsPositionRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<RechnungsPosition>> getByRechnung(
      String rechnungId) async {
    final rows = await SupabaseService.client
        .from('rechnungs_positionen')
        .select()
        .eq('rechnung_id', rechnungId)
        .order('position');
    return rows.map((r) => RechnungsPosition.fromJson(r)).toList();
  }

  /// Findet die Rechnung-ID über eine Position mit service_id.
  static Future<String?> getRechnungIdByServiceId(String serviceId) async {
    final rows = await SupabaseService.client
        .from('rechnungs_positionen')
        .select('rechnung_id')
        .eq('service_id', serviceId)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['rechnung_id'] as String;
  }

  /// Erstellt mehrere Positionen auf einmal.
  static Future<List<RechnungsPosition>> createAll(
      List<Map<String, dynamic>> positionen) async {
    for (final p in positionen) {
      p['user_id'] = _userId;
      p.remove('id');
    }
    final rows = await SupabaseService.client
        .from('rechnungs_positionen')
        .insert(positionen)
        .select()
        .order('position');
    return rows.map((r) => RechnungsPosition.fromJson(r)).toList();
  }
}
