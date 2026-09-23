import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sbs_projer_app/core/util/beleg_korrektur.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Buchungen (kein Isar).
class BuchungRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<Buchung>> getAll() async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('buchungen')
          .select()
          .eq('user_id', _userId)
          .order('datum', ascending: false)
          // Eindeutiger Zweitschlüssel: ohne ihn ist die Reihenfolge zwischen
          // den Seiten nicht stabil (tausende Buchungen teilen sich ein
          // Datum) und es fallen Zeilen durch → falsche Bilanz/Saldi.
          .order('id')
          .range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all.map((r) => Buchung.fromJson(r)).toList();
  }

  /// Zahlungseingänge auf Debitoren (Haben 1100) mit Beleg ab [ab] — für den
  /// Mahnlauf («Zahlung gebucht, Status hinkt nach»). Bewusst gezielt statt
  /// [getAll]: Die Glocke rechnet den Mahnlauf bei jedem Start, und das ganze
  /// Journal wären zehntausende Zeilen.
  static Future<List<Buchung>> getZahlungseingaengeAb(DateTime ab) async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    var from = 0;
    final abStr = ab.toIso8601String().split('T').first;
    while (true) {
      final rows = await SupabaseService.client
          .from('buchungen')
          .select()
          .eq('user_id', _userId)
          .eq('haben_konto', 1100)
          .gte('datum', abStr)
          .not('beleg_id', 'is', null)
          .order('id') // stabile Pagination
          .range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all.map((r) => Buchung.fromJson(r)).toList();
  }

  static Stream<List<Buchung>> watchAll() {
    return Stream.fromFuture(getAll());
  }

  /// Spesenkonten für die Dashboard-Zahl — Aufwandseite ohne Vorsteuer (1171).
  static const spesenKonten = [4004, 5820, 5850, 6200, 6270, 6460];

  /// Anzahl Spesenbelege eines Jahres (nach Belegdatum) für die Dashboard-
  /// Kachel. Erfasst **beide Quellen**: gescannte Belege und die direkt
  /// importierten (Excel-Übernahme, ohne Scanner-Notiz) — abgegrenzt über die
  /// Spesenkonten statt über die Herkunft.
  ///
  /// Gezählt werden Belege, nicht Buchungszeilen: ein Beleg mit drei
  /// MwSt-Gruppen ergibt drei Buchungen, ist aber ein Einkauf.
  static Future<int> spesenBelegeImJahr(int jahr) async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select('datum, beschreibung')
        .eq('user_id', _userId)
        .inFilter('soll_konto', spesenKonten)
        .gte('datum', '$jahr-01-01')
        .lte('datum', '$jahr-12-31');
    return zaehleBelege([
      for (final r in rows)
        (
          datum: r['datum']?.toString() ?? '',
          beschreibung: (r['beschreibung'] as String?) ?? '',
        )
    ]);
  }

  /// Bereits gebuchte Spesen-Positionen eines Belegdatums — Grundlage für die
  /// Dubletten-Warnung im Scanner. Vorsteuer-Gegenbuchungen (1171) bleiben
  /// aussen vor, sonst würde die Summe doppelt zählen.
  static Future<List<DublettenKandidat>> spesenAmDatum(DateTime datum) async {
    final tag = datum.toIso8601String().split('T').first;
    final rows = await SupabaseService.client
        .from('buchungen')
        .select('beschreibung, betrag_brutto')
        .eq('user_id', _userId)
        .eq('datum', tag)
        .neq('soll_konto', 1171)
        .like('notizen', 'Spesen-Scanner Import%');
    return rows
        .map((r) => DublettenKandidat(
              beschreibung: (r['beschreibung'] as String?) ?? '',
              brutto:
                  double.tryParse(r['betrag_brutto']?.toString() ?? '') ?? 0,
            ))
        .toList();
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
    // Seitenweise — Konten wie 1100/Bank können >1000 Buchungen haben (PostgREST-Cap).
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('buchungen')
          .select()
          .eq('user_id', _userId)
          .or('soll_konto.eq.$kontonummer,haben_konto.eq.$kontonummer')
          .order('datum', ascending: false)
          .order('id') // stabile Pagination
          .range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all.map((r) => Buchung.fromJson(r)).toList();
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

  /// Alle Beleg-Ids, zu denen im Zeitraum eine nicht stornierte
  /// Ertragsbuchung existiert (`beleg_typ = 'rechnung'`, siehe
  /// `reinigung_buchung_service.dart`).
  ///
  /// WARUM eine Sammelabfrage: Der Einsätze-Screen (B2) leitet «verrechnet»
  /// bei Reinigungen aus der Ertragsbuchung ab. `getByBeleg` je Zeile wären
  /// rund tausend Anfragen pro Jahr; hier ist es eine. Seitenweise geladen,
  /// weil PostgREST bei 1000 Zeilen deckelt (CLAUDE.md), mit `id` als
  /// eindeutigem Sortierschlüssel.
  static Future<Set<String>> belegIdsMitBuchung({
    required DateTime ab,
    required DateTime bis,
  }) async {
    final abStr = ab.toIso8601String().split('T').first;
    final bisStr = bis.toIso8601String().split('T').first;
    final ids = <String>{};
    const seite = 1000;
    var von = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('buchungen')
          .select('beleg_id')
          .eq('user_id', _userId)
          .eq('beleg_typ', 'rechnung')
          .eq('ist_storniert', false)
          .gte('datum', abStr)
          .lte('datum', bisStr)
          .not('beleg_id', 'is', null)
          .order('id')
          .range(von, von + seite - 1);
      for (final r in rows) {
        ids.add(r['beleg_id'] as String);
      }
      if (rows.length < seite) break;
      von += seite;
    }
    return ids;
  }

  static Future<int> count() async {
    final res = await SupabaseService.client
        .from('buchungen')
        .select('id')
        .eq('user_id', _userId)
        .count(CountOption.exact);
    return res.count;
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

  static Future<void> delete(String id) async {
    await SupabaseService.client
        .from('buchungen')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// Stempelt den camt-Dedup-Schlüssel auf eine Buchung (Idempotenz-Marker).
  static Future<void> setCamtTxKey(String id, String txKey) async {
    await SupabaseService.client
        .from('buchungen')
        .update({'camt_tx_key': txKey})
        .eq('id', id);
  }

  /// Liefert alle bereits per camt verbuchten tx_keys (für Dedup).
  static Future<Set<String>> getAlleCamtTxKeys() async {
    // Nur AKTIVE (nicht stornierte) Buchungen sperren den Re-Import — eine
    // stornierte Buchung gibt ihren camt-Schlüssel frei (Reversibilität).
    final rows = await SupabaseService.client
        .from('buchungen')
        .select('camt_tx_key')
        .eq('ist_storniert', false)
        .not('camt_tx_key', 'is', null);
    return (rows as List).map((r) => r['camt_tx_key'] as String).toSet();
  }

  /// Aktive Zahlungs-Buchungen eines Belegs, die aus dem camt-Abgleich
  /// stammen (tragen `camt_tx_key`). Grundlage für «Zahlung rückgängig» bei
  /// Kundenrechnungen: genau diese Buchungen werden gelöscht, damit die
  /// Bank-Gutschrift wieder importierbar wird.
  static Future<List<String>> getAktiveCamtZahlungsIds(String belegId) async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select('id, camt_tx_key, ist_storniert, storno_von_id')
        .eq('user_id', _userId)
        .eq('beleg_id', belegId)
        .eq('beleg_typ', 'zahlung');
    return [
      for (final r in rows)
        if (r['camt_tx_key'] != null &&
            r['ist_storniert'] != true &&
            r['storno_von_id'] == null)
          r['id'] as String
    ];
  }

  /// Ist diese camt-Transaktion bereits aktiv verbucht? Schützt vor einer
  /// zweiten Buchung derselben Zahlung (z.B. beim Buchen aus der Prüfliste).
  static Future<bool> existiertCamtTxKey(String txKey) async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select('id')
        .eq('camt_tx_key', txKey)
        .eq('ist_storniert', false)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// Löscht alle Buchungen die zu einem Beleg gehören.
  static Future<void> deleteByBeleg(String belegId) async {
    await SupabaseService.client
        .from('buchungen')
        .delete()
        .eq('user_id', _userId)
        .eq('beleg_id', belegId);
  }

  /// Storniert eine Buchung: Setzt ist_storniert und erstellt die Gegenbuchung
  /// (Datum/Geschäftsjahr des Originals, ohne mwst_konto — siehe
  /// `storno_logik.dart`). Zugehörige MwSt-Trennbuchungen desselben Belegs
  /// werden mitstorniert (B6.3), Zahlungen nie.
  static Future<Buchung> stornieren(String id) async {
    final original = await getById(id);
    if (original == null) throw Exception('Buchung nicht gefunden');
    if (original.istStorniert) {
      throw Exception('Buchung ist bereits storniert');
    }
    if (original.stornoVonId != null) {
      throw Exception('Eine Storno-Gegenbuchung kann nicht storniert werden');
    }

    // Original als storniert markieren, dann Gegenbuchung
    await update(id, {'ist_storniert': true});
    final gegenbuchung = await create(gegenbuchungFuer(original));

    // Zugehörige MwSt-Trennbuchungen mitnehmen (solange es sie noch gibt)
    if (original.belegId != null) {
      final geschwister = await getByBeleg(original.belegId!);
      for (final g in geschwister) {
        if (!istZugehoerigeTrennbuchung(original: original, kandidat: g)) {
          continue;
        }
        await update(g.id, {'ist_storniert': true});
        await create(gegenbuchungFuer(g));
      }
    }

    return gegenbuchung;
  }
}
