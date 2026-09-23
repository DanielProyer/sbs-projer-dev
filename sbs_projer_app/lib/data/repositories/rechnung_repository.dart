import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:sbs_projer_app/core/util/scor_referenz.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Supabase-only Repository für Rechnungen (kein Isar).
class RechnungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Holt ALLE Zeilen seitenweise (PostgREST deckelt sonst bei 1000).
  static Future<List<Map<String, dynamic>>> _pagedByUser({
    String? col,
    String? val,
  }) async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      var q = SupabaseService.client
          .from('rechnungen')
          .select()
          .eq('user_id', _userId);
      if (col != null) q = q.eq(col, val!);
      final rows = await q
          .order('created_at', ascending: false)
          .order('id') // stabile Pagination
          .range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all;
  }

  static Future<List<Rechnung>> getAll() async {
    final rows = await _pagedByUser();
    return rows.map((r) => Rechnung.fromJson(r)).toList();
  }

  static Stream<List<Rechnung>> watchAll() {
    return Stream.fromFuture(getAll());
  }

  static Future<Rechnung?> getById(String id) async {
    final rows = await SupabaseService.client
        .from('rechnungen')
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return Rechnung.fromJson(rows.first);
  }

  /// Fragt den Server, ob der Versandvermerk steht.
  /// `true` = versendet, `false` = kein Vermerk, `null` = die Nachfrage kam
  /// selbst nicht durch.
  ///
  /// WARUM: Die Mail-Function setzt `versendet_am` seit v15 selbst, direkt
  /// nach dem erfolgreichen Gmail-Aufruf. Bricht unterwegs die Verbindung ab,
  /// fängt die App eine Ausnahme — obwohl die Mail beim Kunden liegt. Steht
  /// der Vermerk, ist sie raus; das weiss nur der Server, also wird er
  /// gefragt. Siehe `versand_meldung.dart`.
  ///
  /// Wirft NIE: Diese Nachfrage läuft in einem catch-Block, in dem schon
  /// etwas schiefging. Eine zweite Ausnahme hülfe niemandem.
  static Future<bool?> istVersandVermerkt(String id) async {
    try {
      final rows = await SupabaseService.client
          .from('rechnungen')
          .select('versendet_am')
          .eq('id', id)
          .eq('user_id', _userId)
          .limit(1);
      if (rows.isEmpty) return false;
      return rows.first['versendet_am'] != null;
    } catch (e) {
      debugPrint('[Versandstand] Nachfrage fehlgeschlagen: $e');
      return null;
    }
  }

  static Future<List<Rechnung>> getByBetrieb(String betriebId) async {
    final rows = await _pagedByUser(col: 'betrieb_id', val: betriebId);
    return rows.map((r) => Rechnung.fromJson(r)).toList();
  }

  static Stream<List<Rechnung>> watchByBetrieb(String betriebId) {
    return Stream.fromFuture(getByBetrieb(betriebId));
  }

  static Future<int> count() async {
    int total = 0;
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('rechnungen')
          .select('id')
          .eq('user_id', _userId)
          .order('id')
          .range(from, from + pageSize - 1);
      total += rows.length;
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return total;
  }

  static Future<int> countOffene() async {
    int total = 0;
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('rechnungen')
          .select('id')
          .eq('user_id', _userId)
          .not('zahlungsstatus', 'in', '("bezahlt","abgeschrieben")')
          .order('id')
          .range(from, from + pageSize - 1);
      total += rows.length;
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return total;
  }

  /// Alle offenen Rechnungen (nicht bezahlt/abgeschrieben), älteste zuerst.
  static Future<List<Rechnung>> getOffene() async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('rechnungen')
          .select()
          .eq('user_id', _userId)
          .not('zahlungsstatus', 'in', '("bezahlt","abgeschrieben")')
          .order('rechnungsdatum')
          .order('id') // stabile Pagination
          .range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all.map((r) => Rechnung.fromJson(r)).toList();
  }

  /// Erstellt eine Rechnung und gibt das DB-Ergebnis zurück (inkl. generierter ID).
  /// Vergibt für Kundentypen automatisch eine eindeutige SCOR-Referenz; bei einer
  /// Referenz-Kollision (zwei Rechnungsnummern mit identischen Ziffern) wird mit
  /// einem Suffix neu vergeben und erneut eingefügt, statt eine Exception zu werfen.
  static Future<Rechnung> create(Map<String, dynamic> json) async {
    json['user_id'] = _userId;
    json.remove('id');
    // Eigene Referenz vom Aufrufer wird respektiert und nicht überschrieben.
    final eigeneRef = json['qr_referenz'] != null;
    for (var suffix = 0; ; suffix++) {
      if (!eigeneRef) {
        json['qr_referenz'] = qrReferenzAusNummer(
          json['rechnungstyp'] as String?,
          json['rechnungsnummer'] as String?,
          suffix: suffix,
        ); // null bei Nicht-Kundentyp
      }
      try {
        final rows = await SupabaseService.client
            .from('rechnungen')
            .insert(json)
            .select();
        return Rechnung.fromJson(rows.first);
      } on PostgrestException catch (e) {
        final istDuplikat = e.code == '23505';
        // Referenz-Kollision (eigene Vergabe) → mit anderem Suffix erneut.
        // Gleiche Prüfung wie `MahnlaufService` (`istQrReferenzKonflikt`).
        final refKonflikt = istQrReferenzKonflikt(e);
        // rechnungsnummer wird per DB-Trigger aus einer Sequenz vergeben. Hinkt
        // die Sequenz hinter bereits vergebenen Nummern her, kollidiert der
        // Insert — ein Neuversuch erzeugt die nächste Sequenznummer und heilt
        // die Lücke selbst.
        final nummerKonflikt =
            istDuplikat &&
            (e.message.contains('rechnungsnummer') ||
                (e.details?.toString().contains('rechnungsnummer') ?? false));
        if (((!eigeneRef && refKonflikt) || nummerKonflikt) && suffix < 50) {
          continue;
        }
        rethrow;
      }
    }
  }

  /// Aktualisiert einzelne Felder einer Rechnung.
  static Future<void> update(String id, Map<String, dynamic> fields) async {
    await SupabaseService.client.from('rechnungen').update(fields).eq('id', id);
  }

  static Future<void> delete(String id) async {
    await SupabaseService.client.from('rechnungen').delete().eq('id', id);
  }
}
