import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/region_local_export.dart';
import 'package:sbs_projer_app/data/models/region.dart';
import 'package:sbs_projer_app/data/mappers/region_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class RegionRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<RegionLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('regionen').select().eq('user_id', _userId);
      return rows.map((r) => RegionMapper.fromDto(Region.fromJson(r))).toList();
    }
    return IsarService.regionFindAll();
  }

  static Stream<List<RegionLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.regionWatchAll();
  }

  static Future<RegionLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('regionen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return RegionMapper.fromDto(Region.fromJson(rows.first));
    }
    return IsarService.regionGet(int.parse(id));
  }

  static Future<RegionLocal?> getByServerId(String serverId) async {
    if (kIsWeb) return getById(serverId);
    return IsarService.regionFindByServerId(serverId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('regionen').select('id').eq('user_id', _userId);
      return rows.length;
    }
    return IsarService.regionCount();
  }

  static Future<void> save(RegionLocal region) async {
    region.userId = _userId;
    if (kIsWeb) {
      final json = RegionMapper.toJson(region);
      await SupabaseService.client.from('regionen').upsert(json);
      return;
    }
    region.isSynced = false;
    region.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.regionPut(region);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('regionen').delete().eq('id', id);
      return;
    }
    await IsarService.regionDelete(int.parse(id));
  }
}
