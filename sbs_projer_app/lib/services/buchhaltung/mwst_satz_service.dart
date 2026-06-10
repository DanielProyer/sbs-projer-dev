import '../supabase/supabase_service.dart';

class MwstSatz {
  final DateTime gueltigAb;
  final double satz;
  const MwstSatz(this.gueltigAb, this.satz);
}

class MwstSatzService {
  /// Reiner Lookup: jüngster Satz mit gueltigAb <= datum; sonst 0.0.
  static double satzFuer(DateTime datum, List<MwstSatz> saetze) {
    final sorted = [...saetze]..sort((a, b) => a.gueltigAb.compareTo(b.gueltigAb));
    double result = 0.0;
    for (final s in sorted) {
      if (!datum.isBefore(s.gueltigAb)) {
        result = s.satz;
      }
    }
    return result;
  }

  static List<MwstSatz>? _cache;

  static Future<List<MwstSatz>> laden() async {
    if (_cache != null) return _cache!;
    final rows = await SupabaseService.client
        .from('mwst_satz')
        .select('gueltig_ab, satz')
        .eq('user_id', SupabaseService.dataUserId);
    _cache = (rows as List)
        .map((r) => MwstSatz(
            DateTime.parse(r['gueltig_ab']),
            double.parse(r['satz'].toString())))
        .toList();
    return _cache!;
  }

  /// Satz für ein Buchungsdatum (lädt + cached).
  static Future<double> satzFuerDatum(DateTime datum) async {
    return satzFuer(datum, await laden());
  }
}
