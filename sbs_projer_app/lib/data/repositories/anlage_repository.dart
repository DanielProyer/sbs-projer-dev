import 'package:isar/isar.dart';
import 'package:sbs_projer_app/data/local/anlage_local.dart';
import 'package:sbs_projer_app/services/storage/isar_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class AnlageRepository {
  static Isar get _isar => IsarService.instance;

  static Future<List<AnlageLocal>> getAll() async {
    return _isar.anlageLocals.where().findAll();
  }

  static Stream<List<AnlageLocal>> watchAll() {
    return _isar.anlageLocals.where().watch(fireImmediately: true);
  }

  static Future<AnlageLocal?> getById(int id) async {
    return _isar.anlageLocals.get(id);
  }

  static Future<AnlageLocal?> getByServerId(String serverId) async {
    return _isar.anlageLocals
        .filter()
        .serverIdEqualTo(serverId)
        .findFirst();
  }

  static Future<List<AnlageLocal>> getByBetrieb(String betriebId) async {
    return _isar.anlageLocals
        .filter()
        .betriebIdEqualTo(betriebId)
        .findAll();
  }

  static Stream<List<AnlageLocal>> watchByBetrieb(String betriebId) {
    return _isar.anlageLocals
        .filter()
        .betriebIdEqualTo(betriebId)
        .watch(fireImmediately: true);
  }

  static Future<int> count() async {
    return _isar.anlageLocals.count();
  }

  static Future<void> save(AnlageLocal anlage) async {
    anlage.userId = SupabaseService.currentUser!.id;
    anlage.isSynced = false;
    anlage.lastModifiedAt = DateTime.now().toUtc();
    await _isar.writeTxn(() => _isar.anlageLocals.put(anlage));
  }

  static Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.anlageLocals.delete(id));
  }
}
