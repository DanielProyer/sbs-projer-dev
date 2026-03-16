import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Buchungen (kein Isar).
class BuchungRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<Buchung>> getAll() async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select()
        .eq('user_id', _userId)
        .order('datum', ascending: false);
    return rows.map((r) => Buchung.fromJson(r)).toList();
  }

  static Stream<List<Buchung>> watchAll() {
    return Stream.fromFuture(getAll());
  }

  static Future<Buchung?> getById(String id) async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return Buchung.fromJson(rows.first);
  }

  static Future<List<Buchung>> getByPeriode(int jahr, int monat) async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select()
        .eq('user_id', _userId)
        .eq('geschaeftsjahr', jahr)
        .eq('monat', monat)
        .order('datum', ascending: false);
    return rows.map((r) => Buchung.fromJson(r)).toList();
  }

  static Future<List<Buchung>> getByKonto(int kontonummer) async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select()
        .eq('user_id', _userId)
        .or('soll_konto.eq.$kontonummer,haben_konto.eq.$kontonummer')
        .order('datum', ascending: false);
    return rows.map((r) => Buchung.fromJson(r)).toList();
  }

  static Future<List<Buchung>> getByBeleg(String belegId) async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select()
        .eq('user_id', _userId)
        .eq('beleg_id', belegId)
        .order('datum', ascending: false);
    return rows.map((r) => Buchung.fromJson(r)).toList();
  }

  static Future<int> count() async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select('id')
        .eq('user_id', _userId);
    return rows.length;
  }

  static Future<int> countByPeriode(int jahr, int monat) async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select('id')
        .eq('user_id', _userId)
        .eq('geschaeftsjahr', jahr)
        .eq('monat', monat);
    return rows.length;
  }

  static Future<Buchung> create(Map<String, dynamic> json) async {
    json['user_id'] = _userId;
    json.remove('id');
    final rows = await SupabaseService.client
        .from('buchungen')
        .insert(json)
        .select();
    return Buchung.fromJson(rows.first);
  }

  static Future<void> update(String id, Map<String, dynamic> fields) async {
    await SupabaseService.client
        .from('buchungen')
        .update(fields)
        .eq('id', id);
  }

  /// Storniert eine Buchung: Setzt ist_storniert und erstellt Gegenbuchung.
  static Future<Buchung> stornieren(String id) async {
    final original = await getById(id);
    if (original == null) throw Exception('Buchung nicht gefunden');

    // Original als storniert markieren
    await update(id, {'ist_storniert': true});

    // Gegenbuchung erstellen (Soll/Haben vertauscht)
    return create({
      'datum': DateTime.now().toIso8601String().split('T').first,
      'belegnummer': 'STORNO-${original.belegnummer ?? original.id.substring(0, 8)}',
      'vorlage_id': original.vorlageId,
      'soll_konto': original.habenKonto,
      'haben_konto': original.sollKonto,
      'mwst_konto': original.mwstKonto,
      'betrag_netto': original.betragNetto,
      'mwst_satz': original.mwstSatz,
      'mwst_betrag': original.mwstBetrag,
      'betrag_brutto': original.betragBrutto,
      'beschreibung': 'Storno: ${original.beschreibung}',
      'zahlungsweg': original.zahlungsweg,
      'belegordner': original.belegordner,
      'beleg_typ': original.belegTyp,
      'beleg_id': original.belegId,
      'geschaeftsjahr': DateTime.now().year,
      'storno_von_id': id,
      'notizen': 'Stornierung von Buchung ${original.belegnummer ?? id}',
    });
  }
}
