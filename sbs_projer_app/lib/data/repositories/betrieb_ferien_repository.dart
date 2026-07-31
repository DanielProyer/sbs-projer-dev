import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/betrieb_ferien_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_ferien_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Zugriff auf Betriebsferien-Perioden (Tabelle `betrieb_ferien`).
///
/// Ersetzt die früheren fünf festen Spaltenpaare auf `betriebe`
/// (ferien_start/ferien_ende … ferien5_start/ferien5_ende) durch beliebig
/// viele Zeilen, damit neue Ferien die Historie nicht mehr verdrängen.
class BetriebFerienRepository {
  static String get _userId => SupabaseService.currentUser!.id;
  static const _table = 'betrieb_ferien';

  /// Quellen, bei denen ein Mensch die Angabe bestätigt hat und die
  /// deshalb `bestaetigt_am` setzen. Fremdquellen (website/google) und
  /// Altbestand (import) bestätigen nichts.
  static const _bestaetigteQuellen = {'kunde', 'vor_ort'};

  static Future<List<BetriebFerienLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from(_table)
          .select()
          .eq('user_id', _userId)
          .order('von');
      return rows
          .map((r) => BetriebFerienMapper.fromDto(BetriebFerienDto.fromJson(r)))
          .toList();
    }
    return IsarService.betriebFerienFindAll();
  }

  static Future<List<BetriebFerienLocal>> getFuerBetrieb(
    String betriebId,
  ) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from(_table)
          .select()
          .eq('user_id', _userId)
          .eq('betrieb_id', betriebId)
          .order('von');
      return rows
          .map((r) => BetriebFerienMapper.fromDto(BetriebFerienDto.fromJson(r)))
          .toList();
    }
    return IsarService.betriebFerienFilterByBetrieb(betriebId);
  }

  /// Legt eine neue Ferien-Periode an. Bei `quelle` 'kunde' oder 'vor_ort'
  /// wird `bestaetigt_am` automatisch gesetzt, weil ein Mensch die Angabe
  /// bestätigt hat — bei Fremdquellen (website/google) und Altbestand
  /// (import) bleibt es leer.
  static Future<BetriebFerienLocal> periodeErfassen({
    required String betriebId,
    required DateTime von,
    required DateTime bis,
    required String quelle,
    String? notiz,
  }) async {
    final local = BetriebFerienLocal()
      ..serverId = const Uuid().v4()
      ..userId = _userId
      ..betriebId = betriebId
      ..von = von
      ..bis = bis
      ..quelle = quelle
      ..notiz = notiz
      ..bestaetigtAm = _bestaetigteQuellen.contains(quelle)
          ? DateTime.now().toUtc()
          : null;

    if (kIsWeb) {
      final json = BetriebFerienMapper.toJson(local);
      await SupabaseService.client.from(_table).upsert(json);
      return local;
    }
    local.isSynced = false;
    local.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.betriebFerienPut(local);
    return local;
  }

  /// Löscht eine Periode. [id] ist im Web die Supabase-UUID, nativ die
  /// Isar-Id als String — dasselbe Muster wie bei Reinigungen und Störungen.
  static Future<void> loeschen(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from(_table).delete().eq('id', id);
      return;
    }
    // Native: erst auf dem Server löschen, dann lokal. Ohne den Server-Schritt
    // holt der nächste Pull die Periode zurück.
    final local = await IsarService.betriebFerienGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client
          .from(_table)
          .delete()
          .eq('id', local!.serverId!);
    }
    await IsarService.betriebFerienDelete(int.parse(id));
  }
}
