import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Steuerzahlungen = Buchungen mit 8900/2208 im Soll oder Haben sowie
/// ESTV-Zahlungen über 2202 gegen Bank/Kasse.
class SteuerzahlungRepository {
  static String get _userId => SupabaseService.dataUserId;
  static const steuerKonten = [8900, 2208, 2202];

  static Future<List<Buchung>> _lade({int? steuerjahr, bool nurOhneJahr = false}) async {
    var q = SupabaseService.client
        .from('buchungen')
        .select()
        .eq('user_id', _userId)
        .eq('ist_storniert', false)
        .or('soll_konto.in.(8900,2208,2202),haben_konto.in.(8900,2208,2202)');
    if (steuerjahr != null) q = q.eq('steuerjahr', steuerjahr);
    if (nurOhneJahr) q = q.isFilter('steuerjahr', null);
    final rows = await q.order('datum', ascending: false).order('id').range(0, 999);
    // 2202-Umsatzsteuer-Saldierungen (2200 an 2202 usw.) sind keine Zahlungen:
    // nur Zeilen gegen Bank/Kasse behalten, ausser sie sind schon zugeordnet.
    return rows.map((r) => Buchung.fromJson(r)).where((b) {
      if (b.steuerjahr != null) return true;
      final geld = {1000, 1020};
      return geld.contains(b.sollKonto) || geld.contains(b.habenKonto);
    }).toList();
  }

  static Future<List<Buchung>> getByJahr(int jahr) => _lade(steuerjahr: jahr);
  static Future<List<Buchung>> getNichtZugeordnet() => _lade(nurOhneJahr: true);

  static Future<void> zuordnen(String buchungId,
      {required int steuerjahr, required String steuerart}) async {
    await SupabaseService.client
        .from('buchungen')
        .update({'steuerjahr': steuerjahr, 'steuerart': steuerart})
        .eq('id', buchungId);
  }

  /// Bezahlt je (jahr, steuerart) aus der View.
  static Future<Map<(int, String), double>> bezahltJeJahr() async {
    final rows = await SupabaseService.client
        .from('view_steuerjahr_zahlungen')
        .select()
        .eq('user_id', _userId);
    return {
      for (final r in rows)
        (r['steuerjahr'] as int, (r['steuerart'] ?? 'kanton') as String):
            double.tryParse(r['bezahlt'].toString()) ?? 0,
    };
  }
}
