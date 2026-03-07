import 'package:isar/isar.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local.dart';
import 'package:sbs_projer_app/services/storage/isar_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BierleitungRepository {
  static Isar get _isar => IsarService.instance;

  static Future<List<BierleitungLocal>> getByAnlage(String anlageId) async {
    return _isar.bierleitungLocals
        .filter()
        .anlageIdEqualTo(anlageId)
        .sortByLeitungsNummer()
        .findAll();
  }

  static Stream<List<BierleitungLocal>> watchByAnlage(String anlageId) {
    return _isar.bierleitungLocals
        .filter()
        .anlageIdEqualTo(anlageId)
        .sortByLeitungsNummer()
        .watch(fireImmediately: true);
  }

  static Future<BierleitungLocal?> getById(int id) async {
    return _isar.bierleitungLocals.get(id);
  }

  static Future<void> save(BierleitungLocal leitung) async {
    leitung.userId = SupabaseService.currentUser!.id;
    leitung.isSynced = false;
    leitung.lastModifiedAt = DateTime.now().toUtc();
    await _isar.writeTxn(() => _isar.bierleitungLocals.put(leitung));
  }

  static Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.bierleitungLocals.delete(id));
  }
}
