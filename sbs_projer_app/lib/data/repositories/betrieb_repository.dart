import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';

/// Ergebnis eines Alias-Lernversuchs.
enum AliasLernResultat { gelernt, schonVorhanden, konflikt }

class BetriebRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<BetriebLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betriebe').select().eq('user_id', _userId);
      return rows.map((r) => BetriebMapper.fromDto(Betrieb.fromJson(r))).toList();
    }
    return IsarService.betriebFindAll();
  }

  static Stream<List<BetriebLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.betriebWatchAll();
  }

  static Future<List<BetriebLocal>> getAktive() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betriebe').select().eq('user_id', _userId).eq('status', 'aktiv');
      return rows.map((r) => BetriebMapper.fromDto(Betrieb.fromJson(r))).toList();
    }
    return IsarService.betriebFilterByStatus('aktiv');
  }

  static Future<BetriebLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betriebe').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return BetriebMapper.fromDto(Betrieb.fromJson(rows.first));
    }
    return IsarService.betriebGet(int.parse(id));
  }

  static Future<BetriebLocal?> getByServerId(String serverId) async {
    if (kIsWeb) return getById(serverId);
    return IsarService.betriebFindByServerId(serverId);
  }

  static Future<List<BetriebLocal>> getByRegion(String regionId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betriebe').select().eq('user_id', _userId).eq('region_id', regionId);
      return rows.map((r) => BetriebMapper.fromDto(Betrieb.fromJson(r))).toList();
    }
    return IsarService.betriebFilterByRegion(regionId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betriebe').select('id').eq('user_id', _userId);
      return rows.length;
    }
    return IsarService.betriebCount();
  }

  static Future<void> save(BetriebLocal betrieb) async {
    betrieb.userId = _userId;
    if (kIsWeb) {
      final json = BetriebMapper.toJson(betrieb);
      await SupabaseService.client.from('betriebe').upsert(json);
      return;
    }
    betrieb.isSynced = false;
    betrieb.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.betriebPut(betrieb);
  }

  /// Verknüpfte Datensätze, die einem Löschen im Weg stehen (Kategorie → Anzahl).
  /// Leere Map = Betrieb ist löschbar. [betriebServerId] ist die Supabase-UUID.
  static Future<Map<String, int>> loeschHindernisse(
      String betriebServerId) async {
    final res = await SupabaseService.client.rpc(
      'betrieb_loesch_hindernisse',
      params: {'p_betrieb_id': betriebServerId},
    );
    final map = <String, int>{};
    if (res is Map) {
      res.forEach((k, v) {
        final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
        if (n > 0) map['$k'] = n;
      });
    }
    return map;
  }

  /// Wirft [BetriebLoeschException], falls der Betrieb noch verknüpfte Daten hat.
  static Future<void> _pruefeLoeschbar(String betriebServerId) async {
    final hindernisse = await loeschHindernisse(betriebServerId);
    if (hindernisse.isNotEmpty) {
      throw BetriebLoeschException(hindernisse);
    }
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      // id ist auf Web die Server-UUID (routeId == serverId).
      await _pruefeLoeschbar(id);
      await SupabaseService.client.from('betriebe').delete().eq('id', id);
      return;
    }
    // Native: erst Server-seitig prüfen + löschen, dann Isar aufräumen.
    final local = await IsarService.betriebGet(int.parse(id));
    final serverId = local?.serverId;
    if (serverId != null) {
      await _pruefeLoeschbar(serverId);
      await SupabaseService.client.from('betriebe').delete().eq('id', serverId);
    }
    await IsarService.betriebDeleteCascade(int.parse(id));
  }

  /// Reine Entscheidung, ob ein Zahlername als Alias für [betriebServerId]
  /// gelernt werden soll. Konflikt = Name bereits bei einem ANDEREN Betrieb.
  static AliasLernResultat entscheideAlias({
    required String betriebServerId,
    required String zahlername,
    required List<BetriebLocal> alleBetriebe,
  }) {
    final norm = zahlernameNorm(zahlername);
    if (norm.isEmpty) return AliasLernResultat.schonVorhanden;
    for (final b in alleBetriebe) {
      final hat = b.zahlerAliase.any((a) => zahlernameNorm(a) == norm);
      if (hat) {
        return b.serverId == betriebServerId
            ? AliasLernResultat.schonVorhanden
            : AliasLernResultat.konflikt;
      }
    }
    return AliasLernResultat.gelernt;
  }

  /// Lernt [zahlername] als Alias für den Betrieb [betriebServerId] (idempotent,
  /// mit Konflikt-Check gegen andere Betriebe). Speichert nur bei `gelernt`.
  static Future<AliasLernResultat> addZahlerAlias(
    String betriebServerId,
    String zahlername,
  ) async {
    final alle = await getAll();
    final res = entscheideAlias(
      betriebServerId: betriebServerId,
      zahlername: zahlername,
      alleBetriebe: alle,
    );
    if (res != AliasLernResultat.gelernt) return res;
    BetriebLocal? ziel;
    for (final b in alle) {
      if (b.serverId == betriebServerId) {
        ziel = b;
        break;
      }
    }
    if (ziel == null) return AliasLernResultat.schonVorhanden;
    ziel.zahlerAliase = [...ziel.zahlerAliase, zahlernameNorm(zahlername)];
    await save(ziel);
    return AliasLernResultat.gelernt;
  }
}

/// Wird geworfen, wenn ein Betrieb wegen verknüpfter Daten nicht löschbar ist.
class BetriebLoeschException implements Exception {
  /// Kategorie → Anzahl der verknüpften Datensätze.
  final Map<String, int> hindernisse;

  BetriebLoeschException(this.hindernisse);

  /// Benutzerfreundliche Meldung, welche Daten dem Löschen im Weg stehen.
  String get message {
    final teile =
        hindernisse.entries.map((e) => '${e.value} ${e.key}').join(', ');
    return 'Betrieb kann nicht gelöscht werden — es existieren noch: $teile. '
        'Bitte diese Daten zuerst entfernen.';
  }

  @override
  String toString() => message;
}
