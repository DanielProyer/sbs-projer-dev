import '../supabase/supabase_service.dart';

class MwstSatz {
  final DateTime gueltigAb;
  final double satz;
  final double satzReduziert;
  const MwstSatz(this.gueltigAb, this.satz, this.satzReduziert);
}

class MwstSatzService {
  /// Jüngster Normalsatz mit gueltigAb <= datum; sonst 0.0.
  static double satzFuer(DateTime datum, List<MwstSatz> saetze) {
    final sorted = [...saetze]..sort((a, b) => a.gueltigAb.compareTo(b.gueltigAb));
    double result = 0.0;
    for (final s in sorted) {
      if (!datum.isBefore(s.gueltigAb)) result = s.satz;
    }
    return result;
  }

  /// Jüngster reduzierter Satz mit gueltigAb <= datum; sonst 0.0.
  static double reduzierterSatzFuer(DateTime datum, List<MwstSatz> saetze) {
    final sorted = [...saetze]..sort((a, b) => a.gueltigAb.compareTo(b.gueltigAb));
    double result = 0.0;
    for (final s in sorted) {
      if (!datum.isBefore(s.gueltigAb)) result = s.satzReduziert;
    }
    return result;
  }

  static List<MwstSatz>? _cache;
  static void cacheLeeren() => _cache = null;

  static Future<List<MwstSatz>> laden() async {
    if (_cache != null) return _cache!;
    final rows = await SupabaseService.client
        .from('mwst_satz')
        .select('gueltig_ab, satz, satz_reduziert')
        .eq('user_id', SupabaseService.dataUserId);
    _cache = (rows as List)
        .map((r) => MwstSatz(
              DateTime.parse(r['gueltig_ab']),
              double.parse(r['satz'].toString()),
              r['satz_reduziert'] != null ? double.parse(r['satz_reduziert'].toString()) : 0.0,
            ))
        .toList();
    return _cache!;
  }

  /// Normalsatz für ein Buchungsdatum (lädt + cached).
  static Future<double> satzFuerDatum(DateTime datum) async {
    return satzFuer(datum, await laden());
  }

  /// Reduzierter Satz für ein Datum (lädt + cached).
  static Future<double> reduzierterSatzFuerDatum(DateTime datum) async {
    return reduzierterSatzFuer(datum, await laden());
  }

  /// Legt einen neuen Satz ab Datum an und leert den Cache.
  static Future<void> hinzufuegen({
    required DateTime gueltigAb,
    required double satz,
    required double satzReduziert,
  }) async {
    await SupabaseService.client.from('mwst_satz').insert({
      'user_id': SupabaseService.dataUserId,
      'gueltig_ab': gueltigAb.toIso8601String().split('T').first,
      'satz': satz,
      'satz_reduziert': satzReduziert,
    });
    cacheLeeren();
  }
}
