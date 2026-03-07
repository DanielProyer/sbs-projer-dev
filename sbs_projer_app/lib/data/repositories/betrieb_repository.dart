import 'package:isar/isar.dart';
import 'package:sbs_projer_app/data/local/betrieb_local.dart';
import 'package:sbs_projer_app/services/storage/isar_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BetriebRepository {
  static Isar get _isar => IsarService.instance;

  static Future<List<BetriebLocal>> getAll() async {
    return _isar.betriebLocals.where().findAll();
  }

  static Stream<List<BetriebLocal>> watchAll() {
    return _isar.betriebLocals.where().watch(fireImmediately: true);
  }

  static Future<List<BetriebLocal>> getAktive() async {
    return _isar.betriebLocals
        .filter()
        .statusEqualTo('aktiv')
        .findAll();
  }

  static Future<BetriebLocal?> getById(int id) async {
    return _isar.betriebLocals.get(id);
  }

  static Future<BetriebLocal?> getByServerId(String serverId) async {
    return _isar.betriebLocals
        .filter()
        .serverIdEqualTo(serverId)
        .findFirst();
  }

  static Future<List<BetriebLocal>> getByRegion(String regionId) async {
    return _isar.betriebLocals
        .filter()
        .regionIdEqualTo(regionId)
        .findAll();
  }

  static Future<int> count() async {
    return _isar.betriebLocals.count();
  }

  static Future<void> save(BetriebLocal betrieb) async {
    betrieb.userId = SupabaseService.currentUser!.id;
    betrieb.isSynced = false;
    betrieb.lastModifiedAt = DateTime.now().toUtc();
    await _isar.writeTxn(() => _isar.betriebLocals.put(betrieb));
  }

  static Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.betriebLocals.delete(id));
  }
}
