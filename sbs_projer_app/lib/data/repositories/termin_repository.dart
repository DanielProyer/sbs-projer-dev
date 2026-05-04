import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/termin_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/data/mappers/termin_mapper.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
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
      final json = TerminMapper.toJson(termin);
      await SupabaseService.client.from('termine').upsert(json);
      return;
    }
    termin.isSynced = false;
    termin.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.terminPut(termin);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('termine').delete().eq('id', id);
      return;
    }
    final local = await IsarService.terminGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('termine').delete().eq('id', local!.serverId!);
    }
    await IsarService.terminDelete(int.parse(id));
  }

  /// Generiert Termin-Vorschläge aus Betrieb Saison-/Ferien-Daten.
  /// Erstellt nur Vorschläge für Termine, die noch nicht existieren (Duplikat-Check).
  static Future<List<TerminLocal>> generiereVorschlaege() async {
    final betriebe = await BetriebRepository.getAll();
    final existingTermine = await getAll();
    final neuVorschlaege = <TerminLocal>[];

    for (final betrieb in betriebe) {
      if (betrieb.status != 'aktiv') continue;

      final betriebServerId = kIsWeb ? betrieb.serverId! : (betrieb.serverId ?? betrieb.id.toString());
      final betriebName = betrieb.name;

      // Winter-Saison
      if (betrieb.winterSaisonAktiv) {
        if (betrieb.winterStartDatum != null) {
          _addVorschlag(
            neuVorschlaege, existingTermine,
            betriebId: betriebServerId,
            betriebName: betriebName,
            datum: betrieb.winterStartDatum!,
            typ: 'eroeffnungsreinigung',
            anlass: 'saisonstart',
          );
        }
        if (betrieb.winterEndeDatum != null) {
          _addVorschlag(
            neuVorschlaege, existingTermine,
            betriebId: betriebServerId,
            betriebName: betriebName,
            datum: betrieb.winterEndeDatum!,
            typ: 'endreinigung',
            anlass: 'saisonende',
          );
        }
      }

      // Sommer-Saison
      if (betrieb.sommerSaisonAktiv) {
        if (betrieb.sommerStartDatum != null) {
          _addVorschlag(
            neuVorschlaege, existingTermine,
            betriebId: betriebServerId,
            betriebName: betriebName,
            datum: betrieb.sommerStartDatum!,
            typ: 'eroeffnungsreinigung',
            anlass: 'saisonstart',
          );
        }
        if (betrieb.sommerEndeDatum != null) {
          _addVorschlag(
            neuVorschlaege, existingTermine,
            betriebId: betriebServerId,
            betriebName: betriebName,
            datum: betrieb.sommerEndeDatum!,
            typ: 'endreinigung',
            anlass: 'saisonende',
          );
        }
      }

      // Ferien (3 Perioden)
      if (!betrieb.keineBetriebsferien) {
        _addFerienVorschlaege(neuVorschlaege, existingTermine,
            betriebServerId, betriebName,
            betrieb.ferienStart, betrieb.ferienEnde);
        _addFerienVorschlaege(neuVorschlaege, existingTermine,
            betriebServerId, betriebName,
            betrieb.ferien2Start, betrieb.ferien2Ende);
        _addFerienVorschlaege(neuVorschlaege, existingTermine,
            betriebServerId, betriebName,
            betrieb.ferien3Start, betrieb.ferien3Ende);
      }
    }

    // Alle Vorschläge speichern
    for (final vorschlag in neuVorschlaege) {
      await save(vorschlag);
    }

    return neuVorschlaege;
  }

  static void _addFerienVorschlaege(
    List<TerminLocal> vorschlaege,
    List<TerminLocal> existing,
    String betriebId,
    String betriebName,
    DateTime? ferienStart,
    DateTime? ferienEnde,
  ) {
    if (ferienStart != null) {
      // Endreinigung 1 Tag vor Ferien-Start
      final endDatum = ferienStart.subtract(const Duration(days: 1));
      _addVorschlag(
        vorschlaege, existing,
        betriebId: betriebId,
        betriebName: betriebName,
        datum: endDatum,
        typ: 'endreinigung',
        anlass: 'ferien',
      );
    }
    if (ferienEnde != null) {
      // Eröffnungsreinigung am Tag des Ferien-Endes
      _addVorschlag(
        vorschlaege, existing,
        betriebId: betriebId,
        betriebName: betriebName,
        datum: ferienEnde,
        typ: 'eroeffnungsreinigung',
        anlass: 'ferien',
      );
    }
  }

  static void _addVorschlag(
    List<TerminLocal> vorschlaege,
    List<TerminLocal> existing, {
    required String betriebId,
    required String betriebName,
    required DateTime datum,
    required String typ,
    required String anlass,
  }) {
    final datumNorm = DateTime(datum.year, datum.month, datum.day);

    // Duplikat-Check: gleicher Betrieb + Datum + Typ
    final exists = existing.any((t) =>
        t.betriebId == betriebId &&
        DateTime(t.datum.year, t.datum.month, t.datum.day) == datumNorm &&
        t.typ == typ);
    if (exists) return;

    // Auch in bereits generierten Vorschlägen prüfen
    final alreadyAdded = vorschlaege.any((t) =>
        t.betriebId == betriebId &&
        DateTime(t.datum.year, t.datum.month, t.datum.day) == datumNorm &&
        t.typ == typ);
    if (alreadyAdded) return;

    final typLabel = typ == 'eroeffnungsreinigung' ? 'Eröffnungsreinigung' : 'Endreinigung';

    final termin = TerminLocal()
      ..betriebId = betriebId
      ..datum = datumNorm
      ..typ = typ
      ..anlass = anlass
      ..titel = '$typLabel — $betriebName'
      ..status = 'vorgeschlagen'
      ..erinnerungTage = 3;

    vorschlaege.add(termin);
  }
}
