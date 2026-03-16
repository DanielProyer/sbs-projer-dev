import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/betrieb_rechnungsadresse_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_rechnungsadresse_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BetriebRechnungsadresseRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  /// Gibt die eine Rechnungsadresse für einen Betrieb zurück (oder null).
  static Future<BetriebRechnungsadresseLocal?> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betrieb_rechnungsadressen').select()
          .eq('user_id', _userId).eq('betrieb_id', betriebId).limit(1);
      if (rows.isEmpty) return null;
      return BetriebRechnungsadresseMapper.fromDto(
          BetriebRechnungsadresse.fromJson(rows.first));
    }
    return IsarService.rechnungsadresseFindByBetrieb(betriebId);
  }

  static Stream<List<BetriebRechnungsadresseLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) {
      return Stream.fromFuture(
        getByBetrieb(betriebId).then((r) => r != null ? [r] : <BetriebRechnungsadresseLocal>[]),
      );
    }
    return IsarService.rechnungsadresseWatchByBetrieb(betriebId);
  }

  static Future<BetriebRechnungsadresseLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betrieb_rechnungsadressen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return BetriebRechnungsadresseMapper.fromDto(
          BetriebRechnungsadresse.fromJson(rows.first));
    }
    return IsarService.rechnungsadresseGet(int.parse(id));
  }

  static Future<void> save(BetriebRechnungsadresseLocal adresse) async {
    adresse.userId = _userId;
    if (kIsWeb) {
      final json = BetriebRechnungsadresseMapper.toJson(adresse);
      await SupabaseService.client.from('betrieb_rechnungsadressen').upsert(json);
      return;
    }
    adresse.isSynced = false;
    adresse.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.rechnungsadressePut(adresse);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('betrieb_rechnungsadressen').delete().eq('id', id);
      return;
    }
    await IsarService.rechnungsadresseDelete(int.parse(id));
  }
}
