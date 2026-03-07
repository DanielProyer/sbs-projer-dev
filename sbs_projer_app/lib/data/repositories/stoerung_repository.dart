import 'package:isar/isar.dart';
import 'package:sbs_projer_app/data/local/stoerung_local.dart';
import 'package:sbs_projer_app/services/storage/isar_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class StoerungRepository {
  static Isar get _isar => IsarService.instance;

  static Future<List<StoerungLocal>> getAll() async {
    return _isar.stoerungLocals.where().findAll();
  }

  static Future<StoerungLocal?> getById(int id) async {
    return _isar.stoerungLocals.get(id);
  }

  static Stream<List<StoerungLocal>> watchAll() {
    return _isar.stoerungLocals.where().watch(fireImmediately: true);
  }

  static Future<List<StoerungLocal>> getByAnlage(String anlageId) async {
    return _isar.stoerungLocals
        .filter()
        .anlageIdEqualTo(anlageId)
        .findAll();
  }

  static Future<List<StoerungLocal>> getByBetrieb(String betriebId) async {
    return _isar.stoerungLocals
        .filter()
        .betriebIdEqualTo(betriebId)
        .findAll();
  }

  static Stream<List<StoerungLocal>> watchByAnlage(String anlageId) {
    return _isar.stoerungLocals
        .filter()
        .anlageIdEqualTo(anlageId)
        .watch(fireImmediately: true);
  }

  static Stream<List<StoerungLocal>> watchByBetrieb(String betriebId) {
    return _isar.stoerungLocals
        .filter()
        .betriebIdEqualTo(betriebId)
        .watch(fireImmediately: true);
  }

  static Future<int> count() async {
    return _isar.stoerungLocals.count();
  }

  static Future<void> save(StoerungLocal stoerung) async {
    stoerung.userId = SupabaseService.currentUser!.id;
    stoerung.isSynced = false;
    stoerung.lastModifiedAt = DateTime.now().toUtc();
    await _isar.writeTxn(() => _isar.stoerungLocals.put(stoerung));
  }

  static Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.stoerungLocals.delete(id));
  }

  /// Generiert die nächste Störungsnummer (STR-YYYYMM-NNN)
  static Future<String> generateStoerungsnummer() async {
    final now = DateTime.now();
    final prefix =
        'STR-${now.year}${now.month.toString().padLeft(2, '0')}-';
    final all = await _isar.stoerungLocals
        .filter()
        .stoerungsnummerStartsWith(prefix)
        .findAll();
    final nextNum = all.length + 1;
    return '$prefix${nextNum.toString().padLeft(3, '0')}';
  }
}
