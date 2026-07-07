import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/termin_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/data/mappers/termin_mapper.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/services/notification/reminder_service_export.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class TerminRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<TerminLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('termine').select().eq('user_id', _userId);
      return rows.map((r) => TerminMapper.fromDto(Termin.fromJson(r))).toList();
    }
    return IsarService.terminFindAll();
  }

  static Stream<List<TerminLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.terminWatchAll();
  }

  static Future<TerminLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('termine').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return TerminMapper.fromDto(Termin.fromJson(rows.first));
    }
    return IsarService.terminGet(int.parse(id));
  }

  static Future<TerminLocal?> getByServerId(String serverId) async {
    if (kIsWeb) return getById(serverId);
    return IsarService.terminFindByServerId(serverId);
  }

  static Future<List<TerminLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('termine').select().eq('user_id', _userId).eq('betrieb_id', betriebId);
      return rows.map((r) => TerminMapper.fromDto(Termin.fromJson(r))).toList();
    }
    return IsarService.terminFilterByBetrieb(betriebId);
  }

  static Stream<List<TerminLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.terminWatchByBetrieb(betriebId);
  }

  static Future<List<TerminLocal>> getByDateRange(DateTime von, DateTime bis) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('termine').select()
          .eq('user_id', _userId)
          .gte('datum', von.toIso8601String().split('T').first)
          .lte('datum', bis.toIso8601String().split('T').first);
      return rows.map((r) => TerminMapper.fromDto(Termin.fromJson(r))).toList();
    }
    return IsarService.terminFilterByDatumRange(von, bis);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('termine').select('id').eq('user_id', _userId);
      return rows.length;
    }
    return IsarService.terminCount();
  }

  static Future<void> save(TerminLocal termin) async {
    termin.userId = _userId;
    if (kIsWeb) {
      // Neue Termine bekommen client-seitig eine stabile UUID, damit der
      // ReminderService eine eindeutige routeId hat.
      if (termin.serverId == null || termin.serverId!.isEmpty) {
        termin.serverId = const Uuid().v4();
      }
      final json = TerminMapper.toJson(termin);
      await SupabaseService.client.from('termine').upsert(json);
    } else {
      termin.isSynced = false;
      termin.lastModifiedAt = DateTime.now().toUtc();
      await IsarService.terminPut(termin);
    }
    // Erinnerung planen/aktualisieren (defensiv: darf das Speichern nie brechen).
    try {
      await ReminderService.schedule(termin);
    } catch (e) {
      debugPrint('[ReminderService] schedule fehlgeschlagen: $e');
    }
  }

  static Future<void> delete(String id) async {
    final toCancel = await getById(id);
    if (kIsWeb) {
      await SupabaseService.client.from('termine').delete().eq('id', id);
    } else {
      final local = await IsarService.terminGet(int.parse(id));
      if (local?.serverId != null) {
        await SupabaseService.client.from('termine').delete().eq('id', local!.serverId!);
      }
      await IsarService.terminDelete(int.parse(id));
    }
    if (toCancel != null) {
      try {
        await ReminderService.cancel(toCancel.routeId);
      } catch (e) {
        debugPrint('[ReminderService] cancel fehlgeschlagen: $e');
      }
    }
  }

  /// Generiert/synchronisiert Termin-Vorschläge aus Betrieb Saison-/Ferien-Daten
  /// für ALLE Betriebe (Button "Termine vorschlagen").
  static Future<List<TerminLocal>> generiereVorschlaege() =>
      synchronisiereVorschlaege();

  /// Auto-Anlässe, die aus Saison-/Ferien-Daten generiert werden.
  static bool _istSaisonFerienAnlass(String anlass) =>
      anlass == 'saisonstart' || anlass == 'saisonende' || anlass == 'ferien';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Synchronisiert die automatisch generierten Saison-/Ferien-Vorschläge mit
  /// den aktuellen Betriebsdaten:
  /// - veraltete Auto-Vorschläge (Status 'vorgeschlagen', Anlass saisonstart/
  ///   saisonende/ferien), die nicht mehr zu den Daten passen → werden entfernt
  /// - fehlende Vorschläge aus den aktuellen Daten → werden erstellt
  /// Bestätigte ('geplant') und manuell erstellte Termine bleiben unberührt.
  /// [nurBetriebId] beschränkt die Synchronisation auf einen Betrieb (serverId).
  static Future<List<TerminLocal>> synchronisiereVorschlaege(
      {String? nurBetriebId}) async {
    var betriebe = await BetriebRepository.getAll();
    if (nurBetriebId != null) {
      betriebe = betriebe
          .where((b) => (b.serverId ?? b.routeId) == nurBetriebId)
          .toList();
    }
    final alleTermine = await getAll();

    // Betriebe, deren letzte abgeschlossene Reinigung eine Endreinigung war:
    // dann sind die Anlagen sauber eingelagert → KEINE Eröffnungsreinigung am
    // nächsten Saisonstart (die reguläre Reinigung wird über die Tourenplanung
    // erst Saisonstart + 4 Wochen fällig).
    final reinigungen = await ReinigungRepository.getAll();
    final letzteProBetrieb = <String, ReinigungLocal>{};
    for (final r in reinigungen) {
      if (r.status != 'abgeschlossen') continue;
      final cur = letzteProBetrieb[r.betriebId];
      if (cur == null || r.datum.isAfter(cur.datum)) {
        letzteProBetrieb[r.betriebId] = r;
      }
    }
    final keineEroeffnung = <String>{
      for (final e in letzteProBetrieb.entries)
        if (e.value.serviceArt == 'endreinigung') e.key,
    };

    // 1. SOLL-Vorschläge aus aktuellen Saison/Ferien-Daten berechnen
    final soll = _berechneSoll(betriebe, keineEroeffnung);

    String keyOf(String bId, DateTime d, String typ, String anlass) =>
        '$bId|${d.year}-${d.month}-${d.day}|$typ|$anlass';
    final sollKeys = {
      for (final t in soll) keyOf(t.betriebId, t.datum, t.typ, t.anlass)
    };

    // 2. Veraltete Auto-Vorschläge entfernen (nur 'vorgeschlagen' + Auto-Anlass)
    final geloescht = <String>{};
    for (final t in alleTermine) {
      if (t.status != 'vorgeschlagen') continue;
      if (!_istSaisonFerienAnlass(t.anlass)) continue;
      if (nurBetriebId != null && t.betriebId != nurBetriebId) continue;
      if (!sollKeys.contains(keyOf(t.betriebId, t.datum, t.typ, t.anlass))) {
        await delete(t.routeId);
        geloescht.add(t.routeId);
      }
    }

    // 3. Fehlende SOLL-Vorschläge erstellen. Duplikat-Check gegen behaltene
    //    Termine (betriebId + Datum + Typ) — so wird kein Vorschlag doppelt
    //    oder über einem bereits bestätigten 'geplant'-Termin angelegt.
    final behaltene =
        alleTermine.where((t) => !geloescht.contains(t.routeId)).toList();
    final erstellt = <TerminLocal>[];
    for (final v in soll) {
      final schonVorhanden = behaltene.any((t) =>
          t.betriebId == v.betriebId &&
          _sameDay(t.datum, v.datum) &&
          t.typ == v.typ);
      if (schonVorhanden) continue;
      final schonErstellt = erstellt.any((e) =>
          e.betriebId == v.betriebId &&
          _sameDay(e.datum, v.datum) &&
          e.typ == v.typ);
      if (schonErstellt) continue;
      await save(v);
      erstellt.add(v);
    }
    return erstellt;
  }

  /// Berechnet die SOLL-Vorschläge (reine Liste, ohne Persistenz/Duplikat-Check).
  /// [keineEroeffnung] enthält Betriebe (bId), für die KEINE Eröffnungsreinigung
  /// erzeugt wird (letzte Reinigung war eine Endreinigung → Anlagen sauber).
  static List<TerminLocal> _berechneSoll(
      List<BetriebLocal> betriebe, Set<String> keineEroeffnung) {
    final soll = <TerminLocal>[];
    for (final betrieb in betriebe) {
      if (betrieb.status != 'aktiv') continue;
      final bId = kIsWeb
          ? betrieb.serverId!
          : (betrieb.serverId ?? betrieb.id.toString());
      final name = betrieb.name;
      final skipEroeffnung = keineEroeffnung.contains(bId);

      if (betrieb.winterSaisonAktiv) {
        if (betrieb.winterStartDatum != null && !skipEroeffnung) {
          _addSoll(soll, bId, name, betrieb.winterStartDatum!,
              'eroeffnungsreinigung', 'saisonstart');
        }
        if (betrieb.winterEndeDatum != null) {
          _addSoll(soll, bId, name, betrieb.winterEndeDatum!, 'endreinigung',
              'saisonende');
        }
      }

      if (betrieb.sommerSaisonAktiv) {
        if (betrieb.sommerStartDatum != null && !skipEroeffnung) {
          _addSoll(soll, bId, name, betrieb.sommerStartDatum!,
              'eroeffnungsreinigung', 'saisonstart');
        }
        if (betrieb.sommerEndeDatum != null) {
          _addSoll(soll, bId, name, betrieb.sommerEndeDatum!, 'endreinigung',
              'saisonende');
        }
      }

      if (!betrieb.keineBetriebsferien) {
        for (final slot in ferienSlots(betrieb)) {
          _addFerienSoll(
              soll, bId, name, slot.start, slot.ende, skipEroeffnung);
        }
      }
    }
    return soll;
  }

  static void _addFerienSoll(List<TerminLocal> soll, String betriebId,
      String betriebName, DateTime? ferienStart, DateTime? ferienEnde,
      bool skipEroeffnung) {
    if (ferienStart != null) {
      // Endreinigung 1 Tag vor Ferien-Start
      _addSoll(soll, betriebId, betriebName,
          ferienStart.subtract(const Duration(days: 1)), 'endreinigung',
          'ferien');
    }
    if (ferienEnde != null && !skipEroeffnung) {
      // Eröffnungsreinigung am Tag des Ferien-Endes (nur wenn nicht endgereinigt)
      _addSoll(soll, betriebId, betriebName, ferienEnde, 'eroeffnungsreinigung',
          'ferien');
    }
  }

  static void _addSoll(List<TerminLocal> soll, String betriebId,
      String betriebName, DateTime datum, String typ, String anlass) {
    final datumNorm = DateTime(datum.year, datum.month, datum.day);
    final typLabel =
        typ == 'eroeffnungsreinigung' ? 'Eröffnungsreinigung' : 'Endreinigung';
    soll.add(TerminLocal()
      ..betriebId = betriebId
      ..datum = datumNorm
      ..typ = typ
      ..anlass = anlass
      ..titel = '$typLabel — $betriebName'
      ..status = 'vorgeschlagen'
      ..erinnerungTage = 3);
  }
}
