import 'package:isar/isar.dart';
import 'package:sbs_projer_app/data/local/region_local.dart';
import 'package:sbs_projer_app/services/storage/isar_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class RegionRepository {
  static Isar get _isar => IsarService.instance;

  static Future<List<RegionLocal>> getAll() async {
    return _isar.regionLocals.where().findAll();
  }

  static Stream<List<RegionLocal>> watchAll() {
    return _isar.regionLocals.where().watch(fireImmediately: true);
  }

  static Future<RegionLocal?> getById(int id) async {
    return _isar.regionLocals.get(id);
  }

  static Future<RegionLocal?> getByServerId(String serverId) async {
    return _isar.regionLocals
        .filter()
        .serverIdEqualTo(serverId)
        .findFirst();
  }

  static Future<int> count() async {
    return _isar.regionLocals.count();
  }

  static Future<void> save(RegionLocal region) async {
    region.userId = SupabaseService.currentUser!.id;
    region.isSynced = false;
    region.lastModifiedAt = DateTime.now().toUtc();
    await _isar.writeTxn(() => _isar.regionLocals.put(region));
  }

  static Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.regionLocals.delete(id));
  }
}
