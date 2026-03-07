import 'package:isar/isar.dart';
import 'package:sbs_projer_app/data/local/reinigung_local.dart';
import 'package:sbs_projer_app/services/storage/isar_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class ReinigungRepository {
  static Isar get _isar => IsarService.instance;

  static Future<List<ReinigungLocal>> getAll() async {
    return _isar.reinigungLocals.where().findAll();
  }

  static Stream<List<ReinigungLocal>> watchAll() {
    return _isar.reinigungLocals.where().watch(fireImmediately: true);
  }

  static Future<ReinigungLocal?> getById(int id) async {
    return _isar.reinigungLocals.get(id);
  }

  static Future<ReinigungLocal?> getByServerId(String serverId) async {
    return _isar.reinigungLocals
        .filter()
        .serverIdEqualTo(serverId)
        .findFirst();
  }

  static Future<List<ReinigungLocal>> getByAnlage(String anlageId) async {
    return _isar.reinigungLocals
        .filter()
        .anlageIdEqualTo(anlageId)
        .findAll();
  }

  static Future<List<ReinigungLocal>> getByBetrieb(String betriebId) async {
    return _isar.reinigungLocals
        .filter()
        .betriebIdEqualTo(betriebId)
        .findAll();
  }

  static Stream<List<ReinigungLocal>> watchByAnlage(String anlageId) {
    return _isar.reinigungLocals
        .filter()
        .anlageIdEqualTo(anlageId)
        .watch(fireImmediately: true);
  }

  static Stream<List<ReinigungLocal>> watchByBetrieb(String betriebId) {
    return _isar.reinigungLocals
        .filter()
        .betriebIdEqualTo(betriebId)
        .watch(fireImmediately: true);
  }

  static Future<int> count() async {
    return _isar.reinigungLocals.count();
  }

  static Future<void> save(ReinigungLocal reinigung) async {
    reinigung.userId = SupabaseService.currentUser!.id;
    reinigung.isSynced = false;
    reinigung.lastModifiedAt = DateTime.now().toUtc();
    await _isar.writeTxn(() => _isar.reinigungLocals.put(reinigung));
  }

  static Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.reinigungLocals.delete(id));
  }
}
