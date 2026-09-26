import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/core/util/guthaben_verrechnung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Kundenguthaben (Konto 2030) je Betrieb — Supabase-only.
class GuthabenRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<Map<String, double>> _jeBetrieb(List<Buchung> buchungen) async {
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

  /// Für eine NEUE Rechnung verfügbares Guthaben eines Betriebs (0, wenn
  /// keines): Saldo 2030 minus das, was offene Rechnungen schon verrechnet,
  /// aber noch nicht gebucht haben ([verfuegbaresGuthaben], Review C1).
  static Future<double> offenesGuthaben(String betriebId) async {
    final buchungen = await BuchungRepository.getByKonto(kKontoKundenguthaben);
    final alle = await _jeBetrieb(buchungen);
    final saldo = alle[betriebId] ?? 0;
    if (saldo <= 0) return 0;
    final verrechnet = <String>{
      for (final b in buchungen)
        if (istGuthabenVerrechnung(b) && b.belegId != null) b.belegId!,
    };
    final rechnungen = await RechnungRepository.getByBetrieb(betriebId);
    return verfuegbaresGuthaben(saldo, rechnungen, verrechnet);
  }
}
