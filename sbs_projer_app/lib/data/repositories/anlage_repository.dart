import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/models/anlage.dart';
import 'package:sbs_projer_app/data/mappers/anlage_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class AnlageRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<AnlageLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('anlagen').select().eq('user_id', _userId);
      return rows.map((r) => AnlageMapper.fromDto(Anlage.fromJson(r))).toList();
    }
    return IsarService.anlageFindAll();
  }

  static Stream<List<AnlageLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.anlageWatchAll();
  }

  static Future<AnlageLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('anlagen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return AnlageMapper.fromDto(Anlage.fromJson(rows.first));
    }
    return IsarService.anlageGet(int.parse(id));
  }

  static Future<AnlageLocal?> getByServerId(String serverId) async {
    if (kIsWeb) return getById(serverId);
    return IsarService.anlageFindByServerId(serverId);
  }

  static Future<List<AnlageLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('anlagen').select().eq('user_id', _userId).eq('betrieb_id', betriebId);
      return rows.map((r) => AnlageMapper.fromDto(Anlage.fromJson(r))).toList();
    }
    return IsarService.anlageFilterByBetrieb(betriebId);
  }

  static Stream<List<AnlageLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.anlageWatchByBetrieb(betriebId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('anlagen').select('id').eq('user_id', _userId);
      return rows.length;
    }
    return IsarService.anlageCount();
  }

  static Future<void> save(AnlageLocal anlage) async {
    anlage.userId = _userId;
    if (kIsWeb) {
      final json = AnlageMapper.toJson(anlage);
      await SupabaseService.client.from('anlagen').upsert(json);
      return;
    }
    anlage.isSynced = false;
    anlage.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.anlagePut(anlage);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('anlagen').delete().eq('id', id);
      return;
    }
    // Native: Supabase löscht mit CASCADE, dann Isar aufräumen
    final local = await IsarService.anlageGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('anlagen').delete().eq('id', local!.serverId!);
    }
    await IsarService.anlageDeleteCascade(int.parse(id));
  }
}
