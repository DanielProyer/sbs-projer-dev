import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Kundenguthaben (Konto 2030) je Betrieb — Supabase-only.
class GuthabenRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Offenes Guthaben aller Betriebe (Schlüssel `''` = Buchungen ohne
  /// zuordenbare Rechnung).
  static Future<Map<String, double>> offenesGuthabenAlle() async {
    // Seitenweise, `.order('id')` — siehe BuchungRepository.getByKonto.
    final buchungen = await BuchungRepository.getByKonto(kKontoKundenguthaben);
    final rechnungIds = buchungen
        .map((b) => b.belegId)
        .whereType<String>()
        .toSet()
        .toList();
    final betriebVonRechnung = <String, String>{};
    for (var i = 0; i < rechnungIds.length; i += kInFilterBlock) {
      final block = rechnungIds.sublist(
        i,
        i + kInFilterBlock > rechnungIds.length
            ? rechnungIds.length
            : i + kInFilterBlock,
      );
      final rows = await SupabaseService.client
          .from('rechnungen')
          .select('id, betrieb_id')
          .eq('user_id', _userId)
          .inFilter('id', block);
      for (final r in rows) {
        final betrieb = r['betrieb_id'] as String?;
        if (betrieb != null) betriebVonRechnung[r['id'] as String] = betrieb;
      }
    }
    return offenesGuthabenJeBetrieb(buchungen, betriebVonRechnung);
  }

  /// Offenes Guthaben eines Betriebs (0, wenn keines).
  static Future<double> offenesGuthaben(String betriebId) async {
    final alle = await offenesGuthabenAlle();
    return alle[betriebId] ?? 0;
  }
}
