import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/stoerung.dart';
import 'package:sbs_projer_app/data/mappers/stoerung_mapper.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class StoerungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Holt ALLE Zeilen seitenweise (PostgREST deckelt sonst bei 1000).
  /// Erste Seite + Folgeseiten parallel; `.order('id')` = stabile Seitengrenzen.
  static Future<List<Map<String, dynamic>>> _pagedByUser({
    String? col,
    String? val,
  }) async {
    const pageSize = 1000;

    Future<List<Map<String, dynamic>>> fetchPage(int page) {
      var q = SupabaseService.client
          .from('stoerungen')
          .select()
          .eq('user_id', _userId);
      if (col != null) q = q.eq(col, val!);
      return q
          .order('datum', ascending: false)
          .order('id')
          .range(page * pageSize, (page + 1) * pageSize - 1)
          .then((rows) => List<Map<String, dynamic>>.from(rows));
    }

    final all = <Map<String, dynamic>>[];
    final first = await fetchPage(0);
    all.addAll(first);
    if (first.length < pageSize) return all;

    const batch = 4;
    int nextPage = 1;
    while (true) {
      final pages = await Future.wait([
        for (int i = 0; i < batch; i++) fetchPage(nextPage + i),
      ]);
      for (final rows in pages) {
        all.addAll(rows);
      }
      if (pages.last.length < pageSize) break;
      nextPage += batch;
    }
    return all;
  }

  static Future<List<StoerungLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await _pagedByUser();
      return rows
          .map((r) => StoerungMapper.fromDto(Stoerung.fromJson(r)))
          .toList();
    }
    return IsarService.stoerungFindAll();
  }

  static Future<StoerungLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('stoerungen')
          .select()
          .eq('id', id)
          .limit(1);
      if (rows.isEmpty) return null;
      return StoerungMapper.fromDto(Stoerung.fromJson(rows.first));
    }
    return IsarService.stoerungGet(int.parse(id));
  }

  static Stream<List<StoerungLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.stoerungWatchAll();
  }

  static Future<List<StoerungLocal>> getByAnlage(String anlageId) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(col: 'anlage_id', val: anlageId);
      return rows
          .map((r) => StoerungMapper.fromDto(Stoerung.fromJson(r)))
          .toList();
    }
    return IsarService.stoerungFilterByAnlage(anlageId);
  }

  static Future<List<StoerungLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(col: 'betrieb_id', val: betriebId);
      return rows
          .map((r) => StoerungMapper.fromDto(Stoerung.fromJson(r)))
          .toList();
    }
    return IsarService.stoerungFilterByBetrieb(betriebId);
  }

  static Stream<List<StoerungLocal>> watchByAnlage(String anlageId) {
    if (kIsWeb) return Stream.fromFuture(getByAnlage(anlageId));
    return IsarService.stoerungWatchByAnlage(anlageId);
  }

  static Stream<List<StoerungLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.stoerungWatchByBetrieb(betriebId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      return (await _pagedByUser()).length;
    }
    return IsarService.stoerungCount();
  }

  static Future<void> save(StoerungLocal stoerung) async {
    stoerung.userId = _userId;
    if (kIsWeb) {
      final json = StoerungMapper.toJson(stoerung);
      await SupabaseService.client.from('stoerungen').upsert(json);
      return;
    }
    stoerung.isSynced = false;
    stoerung.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.stoerungPut(stoerung);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('stoerungen').delete().eq('id', id);
      return;
    }
    // Native: Supabase löschen, dann Isar aufräumen
    final local = await IsarService.stoerungGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('stoerungen')
          .delete()
          .eq('id', local!.serverId!);
    }
    await IsarService.stoerungDelete(int.parse(id));
  }

  /// Plant den Einsatz auf einen Tag. [zeit] null = ganztaegig (Entscheid
  /// Daniel 31.07.2026: entweder fixer Termin oder ganztaegig).
  static Future<void> einplanen({
    required String id,
    required DateTime tag,
    String? zeit,
    int? dauerMin,
  }) async {
    final geplantAm = tag.toIso8601String().split('T').first;
    if (kIsWeb) {
      await SupabaseService.client
          .from('stoerungen')
          .update({
            'geplant_am': geplantAm,
            'geplant_zeit': zeit,
            'geplant_dauer_min': dauerMin,
          })
          .eq('id', id);
      // Google-Kalender-Push: Die App plant, Google erinnert (Web-App —
      // ohne offenen Tab kommt sonst nichts an). Fire-and-forget, `push`
      // faengt Fehler bereits intern ab (GoogleCalendarSyncService.push).
      await GoogleCalendarSyncService.push(
        'einsatz',
        GoogleCalendarSyncService.einsatzEntityId(istStoerung: true, id: id),
      );
      return;
    }
    final local = await IsarService.stoerungGet(int.parse(id));
    if (local == null) return;
    local.geplantAm = tag;
    local.geplantZeit = zeit;
    local.geplantDauerMin = dauerMin;
    await save(local);
  }

  /// Setzt die tatsaechliche Arbeitszeit.
  ///
  /// ACHTUNG: Beide Werte werden geschrieben, auch `null`. Wer nur das Ende
  /// setzen will, muss den bereits erfassten Beginn mitgeben — sonst wird er
  /// geloescht. Beim "Beginn"-Knopf ist `bis: null` richtig (es gibt noch
  /// kein Ende), beim Abschliessen gehoeren beide Werte hinein.
  static Future<void> arbeitszeitSetzen({
    required String id,
    String? von,
    String? bis,
  }) async {
    if (kIsWeb) {
      await SupabaseService.client
          .from('stoerungen')
          .update({'arbeit_von': von, 'arbeit_bis': bis})
          .eq('id', id);
      return;
    }
    final local = await IsarService.stoerungGet(int.parse(id));
    if (local == null) return;
    local.arbeitVon = von;
    local.arbeitBis = bis;
    await save(local);
  }

  /// Setzt nur den Status (z.B. "in_bearbeitung" beim "Beginn"-Knopf).
  ///
  /// Gezielter Teil-Update statt vollem [save] — schreibt nichts von den
  /// restlichen Formularfeldern, die zu diesem Zeitpunkt evtl. noch
  /// unvollstaendig/ungeprueft im UI stehen (Daniel 31.07.2026).
  static Future<void> statusSetzen({
    required String id,
    required String status,
  }) async {
    if (kIsWeb) {
      await SupabaseService.client
          .from('stoerungen')
          .update({'status': status})
          .eq('id', id);
      return;
    }
    final local = await IsarService.stoerungGet(int.parse(id));
    if (local == null) return;
    local.status = status;
    await save(local);
  }
}
