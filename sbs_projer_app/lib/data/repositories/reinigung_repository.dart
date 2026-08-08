import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/reinigung.dart';
import 'package:sbs_projer_app/data/mappers/reinigung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class ReinigungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Spalten für Massen-Loads (Liste, Auswertung, Touren, Tagesübersicht).
  /// Bewusst OHNE das grosse `hahn_temperaturen`-jsonb (~65% der Zeilengrösse,
  /// im Web-DTO gar nicht abgebildet → nirgends genutzt). Der Detail-Load
  /// [getById] holt weiterhin alle Spalten.
  /// ⚠️ Bei NEUEN `reinigungen`-Spalten, die die App im Web braucht, hier
  /// ergänzen — sonst fehlen sie in Listen-/Auswertungs-Objekten.
  static const _listCols =
      'id, user_id, anlage_id, betrieb_id, datum, uhrzeit_start, uhrzeit_ende, '
      'dauer_minuten, hat_durchlaufkuehler, hat_buffetanstich, hat_kuehlkeller, '
      'hat_fasskuehler, begleitkuehlung_kontrolliert, '
      'installation_allgemein_kontrolliert, aligal_anschluesse_kontrolliert, '
      'durchlaufkuehler_ausgeblasen, wasserstand_kontrolliert, wasser_gewechselt, '
      'leitung_wasser_vorgespuelt, leitungsreinigung_reinigungsmittel, '
      'foerderdruck_kontrolliert, zapfhahn_zerlegt_gereinigt, '
      'zapfkopf_zerlegt_gereinigt, servicekarte_ausgefuellt, '
      'unterschrift_techniker, unterschrift_kunde, unterschrift_kunde_name, '
      'notizen, preisliste_id, service_typ, anzahl_haehne_eigen, '
      'anzahl_haehne_orion, anzahl_haehne_fremd, anzahl_haehne_wein, '
      'anzahl_haehne_anderer_standort, ist_bergkunde, preis_grundtarif, '
      'preis_zusatz_haehne, bergkunden_zuschlag, preis_netto, mwst_satz, '
      'preis_mwst, preis_brutto, status, ist_synced, created_at, updated_at, '
      'checkliste_notizen, protokoll_foto_pfad, ist_kulanz, '
      'ist_heineken_monteur, service_art, zahlungsart, wasser_kuehler_gewechselt, '
      'anlage_ids, abgerechnet, abrechnungs_monat, quelle, extern_id';

  /// Holt Zeilen seitenweise (PostgREST deckelt sonst bei 1000).
  ///
  /// Performance: Grosse Ergebnisse laden die Folgeseiten in parallelen Wellen
  /// (`Future.wait`) statt sequenziell. Zusätzlich wird nur [_listCols] geladen
  /// (ohne das grosse tote `hahn_temperaturen`). Mit [jahr] wird server-seitig
  /// auf ein Kalenderjahr eingegrenzt — das ist der grosse Hebel für die Liste
  /// (ein Jahr statt aller ~8600 Zeilen).
  ///
  /// Der zusätzliche `.order('id')`-Tiebreaker macht die Seitengrenzen
  /// deterministisch (kein Doppeln/Verlieren von Zeilen mit gleichem `datum`).
  static Future<List<Map<String, dynamic>>> _pagedByUser(
      {String? col, String? val, int? jahr}) async {
    const pageSize = 1000;

    Future<List<Map<String, dynamic>>> fetchPage(int page) {
      var q = SupabaseService.client
          .from('reinigungen')
          .select(_listCols)
          .eq('user_id', _userId);
      if (col != null) q = q.eq(col, val!);
      if (jahr != null) {
        q = q.gte('datum', '$jahr-01-01').lte('datum', '$jahr-12-31');
      }
      return q
          .order('datum', ascending: false)
          .order('id')
          .range(page * pageSize, (page + 1) * pageSize - 1)
          .then((rows) => List<Map<String, dynamic>>.from(rows));
    }

    final all = <Map<String, dynamic>>[];
    // Erste Seite separat — kleine Ergebnisse sind damit nach 1 Request fertig.
    final first = await fetchPage(0);
    all.addAll(first);
    if (first.length < pageSize) return all;

    // Grosse Ergebnisse: restliche Seiten in parallelen Wellen laden.
    const batch = 8;
    int nextPage = 1;
    while (true) {
      final pages = await Future.wait(
        [for (int i = 0; i < batch; i++) fetchPage(nextPage + i)],
      );
      for (final rows in pages) {
        all.addAll(rows);
      }
      // Die Seite mit dem höchsten Offset entscheidet: kürzer als pageSize ->
      // es folgen keine weiteren Zeilen mehr.
      if (pages.last.length < pageSize) break;
      nextPage += batch;
    }
    return all;
  }

  static String _datumStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Besuche eines Monats — nur `datum` + `betrieb_id`, server-seitig auf
  /// abgeschlossene Reinigungen des Monats eingegrenzt.
  ///
  /// Bewusst NICHT über [getAll]: Die Arbeitstag-Auswertung braucht rund 130
  /// Zeilen eines Monats, nicht die ~8'500 der ganzen Historie (~4,8 MB in 9
  /// Anfragen). Der grosse Load war der Grund, warum die Auswertung ihre
  /// Besuche zeitweise gar nicht hatte (Befund 06.08.2026).
  ///
  /// Ein Monat bleibt weit unter dem PostgREST-Deckel von 1000 Zeilen —
  /// Seitenlogik ist hier deshalb nicht nötig.
  static Future<List<({DateTime datum, String betriebId})>> getBesucheImMonat(
    int jahr,
    int monat,
  ) async {
    final von = DateTime(jahr, monat, 1);
    final bis = DateTime(jahr, monat + 1, 1); // Monat 13 → Januar Folgejahr
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('reinigungen')
          .select('datum, betrieb_id')
          .eq('user_id', _userId)
          .eq('status', 'abgeschlossen')
          .gte('datum', _datumStr(von))
          .lt('datum', _datumStr(bis));
      return [
        for (final r in rows)
          if (r['betrieb_id'] != null)
            (
              datum: DateTime.parse(r['datum'] as String),
              betriebId: r['betrieb_id'] as String,
            ),
      ];
    }
    final all = await IsarService.reinigungFindAll();
    return [
      for (final r in all)
        if (r.status == 'abgeschlossen' &&
            r.betriebId.isNotEmpty &&
            !r.datum.isBefore(von) &&
            r.datum.isBefore(bis))
          (datum: r.datum, betriebId: r.betriebId),
    ];
  }

  static Future<List<ReinigungLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await _pagedByUser();
      return rows.map((r) => ReinigungMapper.fromDto(Reinigung.fromJson(r))).toList();
    }
    return IsarService.reinigungFindAll();
  }

  /// Nur die Reinigungen eines Kalenderjahres (server-seitig gefiltert) —
  /// der schnelle Pfad für die Reinigungsliste.
  static Future<List<ReinigungLocal>> getByJahr(int jahr) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(jahr: jahr);
      return rows.map((r) => ReinigungMapper.fromDto(Reinigung.fromJson(r))).toList();
    }
    final all = await IsarService.reinigungFindAll();
    return all.where((r) => r.datum.year == jahr).toList();
  }

  /// Verfügbare Jahre (für den Jahr-Filter der Liste). Lädt nur die
  /// `datum`-Spalte — winzig gegenüber den vollen Zeilen.
  static Future<List<int>> getJahre() async {
    final jahre = <int>{};
    if (kIsWeb) {
      const pageSize = 1000;
      int from = 0;
      while (true) {
        final rows = await SupabaseService.client
            .from('reinigungen')
            .select('datum')
            .eq('user_id', _userId)
            .order('id').range(from, from + pageSize - 1);
        for (final r in rows) {
          final d = DateTime.tryParse(r['datum'] as String? ?? '');
          if (d != null) jahre.add(d.year);
        }
        if (rows.length < pageSize) break;
        from += pageSize;
      }
    } else {
      final all = await IsarService.reinigungFindAll();
      for (final r in all) {
        jahre.add(r.datum.year);
      }
    }
    final list = jahre.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  static Stream<List<ReinigungLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.reinigungWatchAll();
  }

  static Future<ReinigungLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('reinigungen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return ReinigungMapper.fromDto(Reinigung.fromJson(rows.first));
    }
    return IsarService.reinigungGet(int.parse(id));
  }

  static Future<ReinigungLocal?> getByServerId(String serverId) async {
    if (kIsWeb) return getById(serverId);
    return IsarService.reinigungFindByServerId(serverId);
  }

  static Future<List<ReinigungLocal>> getByAnlage(String anlageId) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(col: 'anlage_id', val: anlageId);
      return rows.map((r) => ReinigungMapper.fromDto(Reinigung.fromJson(r))).toList();
    }
    return IsarService.reinigungFilterByAnlage(anlageId);
  }

  static Future<List<ReinigungLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(col: 'betrieb_id', val: betriebId);
      return rows.map((r) => ReinigungMapper.fromDto(Reinigung.fromJson(r))).toList();
    }
    return IsarService.reinigungFilterByBetrieb(betriebId);
  }

  static Stream<List<ReinigungLocal>> watchByAnlage(String anlageId) {
    if (kIsWeb) return Stream.fromFuture(getByAnlage(anlageId));
    return IsarService.reinigungWatchByAnlage(anlageId);
  }

  static Stream<List<ReinigungLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.reinigungWatchByBetrieb(betriebId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      int total = 0;
      const pageSize = 1000;
      int from = 0;
      while (true) {
        final rows = await SupabaseService.client
            .from('reinigungen').select('id').eq('user_id', _userId)
            .order('id').range(from, from + pageSize - 1);
        total += rows.length;
        if (rows.length < pageSize) break;
        from += pageSize;
      }
      return total;
    }
    return IsarService.reinigungCount();
  }

  static Future<void> save(ReinigungLocal reinigung) async {
    reinigung.userId = _userId;
    if (kIsWeb) {
      final json = ReinigungMapper.toJson(reinigung);
      await SupabaseService.client.from('reinigungen').upsert(json);
      return;
    }
    reinigung.isSynced = false;
    reinigung.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.reinigungPut(reinigung);
  }

  static Future<ReinigungLocal?> getLastByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('reinigungen')
          .select()
          .eq('user_id', _userId)
          .eq('betrieb_id', betriebId)
          .order('datum', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return ReinigungMapper.fromDto(Reinigung.fromJson(rows.first));
    }
    final all = await IsarService.reinigungFilterByBetrieb(betriebId);
    if (all.isEmpty) return null;
    all.sort((a, b) => b.datum.compareTo(a.datum));
    return all.first;
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('reinigungen').delete().eq('id', id);
      return;
    }
    // Native: Supabase löschen, dann Isar aufräumen
    final local = await IsarService.reinigungGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('reinigungen').delete().eq('id', local!.serverId!);
    }
    await IsarService.reinigungDelete(int.parse(id));
  }
}
