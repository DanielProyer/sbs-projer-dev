import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart'
    show EinsatzRoh, montageWarVorOrt;
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/models/montage.dart';
import 'package:sbs_projer_app/data/mappers/montage_mapper.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class MontageRepository {
  static String get _userId => SupabaseService.dataUserId;

  /// Holt ALLE Zeilen seitenweise (PostgREST deckelt sonst bei 1000).
  /// Erste Seite + Folgeseiten parallel; `.order('id')` = stabile Seitengrenzen.
  static Future<List<Map<String, dynamic>>> _pagedByUser({
    String? col,
    String? val,
  }) async {
    const pageSize = 1000;

    Future<List<Map<String, dynamic>>> fetchPage(int page) {
      var q = SupabaseService.client
          .from('montagen')
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

  static Future<List<MontageLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await _pagedByUser();
      return rows
          .map((r) => MontageMapper.fromDto(Montage.fromJson(r)))
          .toList();
    }
    return IsarService.montageFindAll();
  }

  static Future<MontageLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('montagen')
          .select()
          .eq('id', id)
          .limit(1);
      if (rows.isEmpty) return null;
      return MontageMapper.fromDto(Montage.fromJson(rows.first));
    }
    return IsarService.montageGet(int.parse(id));
  }

  static Stream<List<MontageLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.montageWatchAll();
  }

  static Future<List<MontageLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await _pagedByUser(col: 'betrieb_id', val: betriebId);
      return rows
          .map((r) => MontageMapper.fromDto(Montage.fromJson(r)))
          .toList();
    }
    return IsarService.montageFilterByBetrieb(betriebId);
  }

  /// Montagen eines Monats, bei denen jemand vor Ort war — Einsätze für
  /// «Fahrten aus der Kette». Status-/Typ-Filter in Dart
  /// ([montageWarVorOrt]: keine geplanten, keine Spesen/Aufwandsposten)
  /// statt `.neq()` in der Query (NULL-Falle). Ein Monat bleibt weit unter
  /// dem PostgREST-Deckel.
  static Future<List<EinsatzRoh>> getEinsaetzeImMonat(
    int jahr,
    int monat,
  ) async {
    final von = DateTime(jahr, monat, 1);
    final bis = DateTime(jahr, monat + 1, 1); // Monat 13 → Januar Folgejahr
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('montagen')
          .select(
            'id, betrieb_id, datum, arbeit_von, arbeit_bis, status, '
            'montage_typ',
          )
          .eq('user_id', _userId)
          .gte('datum', _datumStr(von))
          .lt('datum', _datumStr(bis))
          .order('datum')
          .order('id');
      return [
        for (final r in rows)
          if (montageWarVorOrt(
            (r['status'] as String?) ?? '',
            r['montage_typ'] as String?,
          ))
            (
              id: r['id'] as String,
              typ: 'montage',
              betriebId: r['betrieb_id'] as String?,
              datum: DateTime.parse(r['datum'] as String),
              von: r['arbeit_von'] as String?,
              bis: r['arbeit_bis'] as String?,
            ),
      ];
    }
    final all = await IsarService.montageFindAll();
    return [
      for (final m in all)
        if (montageWarVorOrt(m.status, m.montageTyp) &&
            !m.datum.isBefore(von) &&
            m.datum.isBefore(bis))
          (
            // Server-Id, weil `wegpunkte.referenz_id` sie trägt.
            id: m.serverId ?? m.routeId,
            typ: 'montage',
            betriebId: m.betriebId,
            datum: m.datum,
            von: m.arbeitVon,
            bis: m.arbeitBis,
          ),
    ];
  }

  static String _datumStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<void> save(MontageLocal montage) async {
    montage.userId = SupabaseService.currentUser!.id;
    if (kIsWeb) {
      final json = MontageMapper.toJson(montage);
      await SupabaseService.client.from('montagen').upsert(json);
      return;
    }
    montage.isSynced = false;
    montage.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.montagePut(montage);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('montagen').delete().eq('id', id);
      return;
    }
    final local = await IsarService.montageGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('montagen')
          .delete()
          .eq('id', local!.serverId!);
    }
    await IsarService.montageDelete(int.parse(id));
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
          .from('montagen')
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
        GoogleCalendarSyncService.einsatzEntityId(istStoerung: false, id: id),
      );
      return;
    }
    final local = await IsarService.montageGet(int.parse(id));
    if (local == null) return;
    local.geplantAm = tag;
    local.geplantZeit = zeit;
    local.geplantDauerMin = dauerMin;
    await save(local);
  }

  /// Setzt NUR das Plandatum (`geplant_am`) um — Zeit und Dauer bleiben, wie
  /// sie in der DB stehen. Für «Auf anderen Tag verschieben» im Tourenplan:
  /// [einplanen] schrieb dort Zeit und Dauer aus dem Plan-Eintrag mit, und
  /// weil das Plan-JSON `geplantDauerMin` nicht speichert, schrumpfte eine
  /// 180-min-Montage auf 60 min — auch im Google-Kalender (Review
  /// 26.09.2026). Kalender-Push wie bei [einplanen].
  static Future<void> umplanenAufTag({
    required String id,
    required DateTime tag,
  }) async {
    final geplantAm = tag.toIso8601String().split('T').first;
    if (kIsWeb) {
      await SupabaseService.client
          .from('montagen')
          .update({'geplant_am': geplantAm})
          .eq('id', id);
      await GoogleCalendarSyncService.push(
        'einsatz',
        GoogleCalendarSyncService.einsatzEntityId(istStoerung: false, id: id),
      );
      return;
    }
    final local = await IsarService.montageGet(int.parse(id));
    if (local == null) return;
    local.geplantAm = tag;
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
          .from('montagen')
          .update({'arbeit_von': von, 'arbeit_bis': bis})
          .eq('id', id);
      return;
    }
    final local = await IsarService.montageGet(int.parse(id));
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
          .from('montagen')
          .update({'status': status})
          .eq('id', id);
      return;
    }
    final local = await IsarService.montageGet(int.parse(id));
    if (local == null) return;
    local.status = status;
    await save(local);
  }
}
