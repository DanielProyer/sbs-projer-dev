import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/betrieb_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_kontakt.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_kontakt_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BetriebKontaktRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<BetriebKontaktLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betrieb_kontakte').select()
          .eq('user_id', _userId).eq('betrieb_id', betriebId);
      return rows.map((r) => BetriebKontaktMapper.fromDto(BetriebKontakt.fromJson(r))).toList();
    }
    return IsarService.betriebKontaktFilterByBetrieb(betriebId);
  }

  static Stream<List<BetriebKontaktLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.betriebKontaktWatchByBetrieb(betriebId);
  }

  static Future<BetriebKontaktLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('betrieb_kontakte').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return BetriebKontaktMapper.fromDto(BetriebKontakt.fromJson(rows.first));
    }
    return IsarService.betriebKontaktGet(int.parse(id));
  }

  static Future<void> save(BetriebKontaktLocal kontakt) async {
    kontakt.userId = _userId;
    if (kIsWeb) {
      final json = BetriebKontaktMapper.toJson(kontakt);
      await SupabaseService.client.from('betrieb_kontakte').upsert(json);
      return;
    }
    kontakt.isSynced = false;
    kontakt.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.betriebKontaktPut(kontakt);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('betrieb_kontakte').delete().eq('id', id);
      return;
    }
    await IsarService.betriebKontaktDelete(int.parse(id));
  }
}
