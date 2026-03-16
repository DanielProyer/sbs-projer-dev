import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sbs_projer_app/data/local/betrieb_local.dart';
import 'package:sbs_projer_app/data/local/anlage_local.dart';
import 'package:sbs_projer_app/data/local/region_local.dart';
import 'package:sbs_projer_app/data/local/reinigung_local.dart';
import 'package:sbs_projer_app/data/local/stoerung_local.dart';
import 'package:sbs_projer_app/data/local/montage_local.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local.dart';
import 'package:sbs_projer_app/data/local/betrieb_kontakt_local.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local.dart';
import 'package:sbs_projer_app/data/local/lager_local.dart';
import 'package:sbs_projer_app/data/local/preis_local.dart';
import 'package:sbs_projer_app/data/local/betrieb_rechnungsadresse_local.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local.dart';
import 'package:sbs_projer_app/data/local/sync_meta_local.dart';

class IsarService {
  static Isar? _instance;

  static Isar get instance {
    if (_instance == null) {
      throw StateError('Isar not initialized. Call IsarService.initialize() first.');
    }
    return _instance!;
  }

  static Future<void> initialize() async {
    if (_instance != null) return;

    final dir = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      [
        BetriebLocalSchema,
        AnlageLocalSchema,
        RegionLocalSchema,
        ReinigungLocalSchema,
        StoerungLocalSchema,
        MontageLocalSchema,
        EigenauftragLocalSchema,
        PikettDienstLocalSchema,
        BetriebKontaktLocalSchema,
        BetriebRechnungsadresseLocalSchema,
        BierleitungLocalSchema,
        LagerLocalSchema,
        PreisLocalSchema,
        EroeffnungsreinigungLocalSchema,
        SyncMetaLocalSchema,
      ],
      directory: dir.path,
    );
  }

  static Future<T> writeTxn<T>(Future<T> Function() callback) =>
      instance.writeTxn(callback);

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }

  // ═══════════════════════════════════════════════════════════════
  // Typed query methods — resolves Isar extension methods here
  // because extensions don't work through dynamic dispatch.
  // ═══════════════════════════════════════════════════════════════

  // ─── Betrieb ───
  static Future<List<BetriebLocal>> betriebFindAll() =>
      instance.betriebLocals.where().findAll();
  static Stream<List<BetriebLocal>> betriebWatchAll() =>
      instance.betriebLocals.where().watch(fireImmediately: true);
  static Future<int> betriebCount() =>
      instance.betriebLocals.count();
  static Future<BetriebLocal?> betriebGet(int id) =>
      instance.betriebLocals.get(id);
  static Future<void> betriebPut(BetriebLocal b) =>
      instance.writeTxn(() => instance.betriebLocals.put(b));
  static Future<void> betriebDelete(int id) =>
      instance.writeTxn(() => instance.betriebLocals.delete(id));
  static Future<List<BetriebLocal>> betriebFilterByStatus(String status) =>
      instance.betriebLocals.filter().statusEqualTo(status).findAll();
  static Future<BetriebLocal?> betriebFindByServerId(String serverId) =>
      instance.betriebLocals.filter().serverIdEqualTo(serverId).findFirst();
  static Future<List<BetriebLocal>> betriebFilterByRegion(String regionId) =>
      instance.betriebLocals.filter().regionIdEqualTo(regionId).findAll();

  // ─── Anlage ───
  static Future<List<AnlageLocal>> anlageFindAll() =>
      instance.anlageLocals.where().findAll();
  static Stream<List<AnlageLocal>> anlageWatchAll() =>
      instance.anlageLocals.where().watch(fireImmediately: true);
  static Future<int> anlageCount() =>
      instance.anlageLocals.count();
  static Future<AnlageLocal?> anlageGet(int id) =>
      instance.anlageLocals.get(id);
  static Future<void> anlagePut(AnlageLocal a) =>
      instance.writeTxn(() => instance.anlageLocals.put(a));
  static Future<void> anlageDelete(int id) =>
      instance.writeTxn(() => instance.anlageLocals.delete(id));
  static Future<AnlageLocal?> anlageFindByServerId(String serverId) =>
      instance.anlageLocals.filter().serverIdEqualTo(serverId).findFirst();
  static Future<List<AnlageLocal>> anlageFilterByBetrieb(String betriebId) =>
      instance.anlageLocals.filter().betriebIdEqualTo(betriebId).findAll();
  static Stream<List<AnlageLocal>> anlageWatchByBetrieb(String betriebId) =>
      instance.anlageLocals.filter().betriebIdEqualTo(betriebId).watch(fireImmediately: true);

  // ─── Region ───
  static Future<List<RegionLocal>> regionFindAll() =>
      instance.regionLocals.where().findAll();
  static Stream<List<RegionLocal>> regionWatchAll() =>
      instance.regionLocals.where().watch(fireImmediately: true);
  static Future<int> regionCount() =>
      instance.regionLocals.count();
  static Future<RegionLocal?> regionGet(int id) =>
      instance.regionLocals.get(id);
  static Future<void> regionPut(RegionLocal r) =>
      instance.writeTxn(() => instance.regionLocals.put(r));
  static Future<void> regionDelete(int id) =>
      instance.writeTxn(() => instance.regionLocals.delete(id));
  static Future<RegionLocal?> regionFindByServerId(String serverId) =>
      instance.regionLocals.filter().serverIdEqualTo(serverId).findFirst();

  // ─── Reinigung ───
  static Future<List<ReinigungLocal>> reinigungFindAll() =>
      instance.reinigungLocals.where().findAll();
  static Stream<List<ReinigungLocal>> reinigungWatchAll() =>
      instance.reinigungLocals.where().watch(fireImmediately: true);
  static Future<int> reinigungCount() =>
      instance.reinigungLocals.count();
  static Future<ReinigungLocal?> reinigungGet(int id) =>
      instance.reinigungLocals.get(id);
  static Future<void> reinigungPut(ReinigungLocal r) =>
      instance.writeTxn(() => instance.reinigungLocals.put(r));
  static Future<void> reinigungDelete(int id) =>
      instance.writeTxn(() => instance.reinigungLocals.delete(id));
  static Future<ReinigungLocal?> reinigungFindByServerId(String serverId) =>
      instance.reinigungLocals.filter().serverIdEqualTo(serverId).findFirst();
  static Future<List<ReinigungLocal>> reinigungFilterByAnlage(String anlageId) =>
      instance.reinigungLocals.filter().anlageIdEqualTo(anlageId).findAll();
  static Future<List<ReinigungLocal>> reinigungFilterByBetrieb(String betriebId) =>
      instance.reinigungLocals.filter().betriebIdEqualTo(betriebId).findAll();
  static Stream<List<ReinigungLocal>> reinigungWatchByAnlage(String anlageId) =>
      instance.reinigungLocals.filter().anlageIdEqualTo(anlageId).watch(fireImmediately: true);
  static Stream<List<ReinigungLocal>> reinigungWatchByBetrieb(String betriebId) =>
      instance.reinigungLocals.filter().betriebIdEqualTo(betriebId).watch(fireImmediately: true);

  // ─── Stoerung ───
  static Future<List<StoerungLocal>> stoerungFindAll() =>
      instance.stoerungLocals.where().findAll();
  static Stream<List<StoerungLocal>> stoerungWatchAll() =>
      instance.stoerungLocals.where().watch(fireImmediately: true);
  static Future<int> stoerungCount() =>
      instance.stoerungLocals.count();
  static Future<StoerungLocal?> stoerungGet(int id) =>
      instance.stoerungLocals.get(id);
  static Future<void> stoerungPut(StoerungLocal s) =>
      instance.writeTxn(() => instance.stoerungLocals.put(s));
  static Future<void> stoerungDelete(int id) =>
      instance.writeTxn(() => instance.stoerungLocals.delete(id));
  static Future<List<StoerungLocal>> stoerungFilterByAnlage(String anlageId) =>
      instance.stoerungLocals.filter().anlageIdEqualTo(anlageId).findAll();
  static Future<List<StoerungLocal>> stoerungFilterByBetrieb(String betriebId) =>
      instance.stoerungLocals.filter().betriebIdEqualTo(betriebId).findAll();
  static Stream<List<StoerungLocal>> stoerungWatchByAnlage(String anlageId) =>
      instance.stoerungLocals.filter().anlageIdEqualTo(anlageId).watch(fireImmediately: true);
  static Stream<List<StoerungLocal>> stoerungWatchByBetrieb(String betriebId) =>
      instance.stoerungLocals.filter().betriebIdEqualTo(betriebId).watch(fireImmediately: true);
  static Future<List<StoerungLocal>> stoerungFilterByNummer(String prefix) =>
      instance.stoerungLocals.filter().stoerungsnummerStartsWith(prefix).findAll();

  // ─── Montage ───
  static Future<List<MontageLocal>> montageFindAll() =>
      instance.montageLocals.where().findAll();
  static Stream<List<MontageLocal>> montageWatchAll() =>
      instance.montageLocals.where().watch(fireImmediately: true);
  static Future<int> montageCount() =>
      instance.montageLocals.count();
  static Future<MontageLocal?> montageGet(int id) =>
      instance.montageLocals.get(id);
  static Future<void> montagePut(MontageLocal m) =>
      instance.writeTxn(() => instance.montageLocals.put(m));
  static Future<void> montageDelete(int id) =>
      instance.writeTxn(() => instance.montageLocals.delete(id));
  static Future<List<MontageLocal>> montageFilterByAnlage(String anlageId) =>
      instance.montageLocals.filter().anlageIdEqualTo(anlageId).findAll();
  static Future<List<MontageLocal>> montageFilterByBetrieb(String betriebId) =>
      instance.montageLocals.filter().betriebIdEqualTo(betriebId).findAll();
  static Stream<List<MontageLocal>> montageWatchByAnlage(String anlageId) =>
      instance.montageLocals.filter().anlageIdEqualTo(anlageId).watch(fireImmediately: true);
  static Stream<List<MontageLocal>> montageWatchByBetrieb(String betriebId) =>
      instance.montageLocals.filter().betriebIdEqualTo(betriebId).watch(fireImmediately: true);

  // ─── Eigenauftrag ───
  static Future<List<EigenauftragLocal>> eigenauftragFindAll() =>
      instance.eigenauftragLocals.where().findAll();
  static Stream<List<EigenauftragLocal>> eigenauftragWatchAll() =>
      instance.eigenauftragLocals.where().watch(fireImmediately: true);
  static Future<int> eigenauftragCount() =>
      instance.eigenauftragLocals.count();
  static Future<EigenauftragLocal?> eigenauftragGet(int id) =>
      instance.eigenauftragLocals.get(id);
  static Future<void> eigenauftragPut(EigenauftragLocal e) =>
      instance.writeTxn(() => instance.eigenauftragLocals.put(e));
  static Future<void> eigenauftragDelete(int id) =>
      instance.writeTxn(() => instance.eigenauftragLocals.delete(id));
  static Future<List<EigenauftragLocal>> eigenauftragFilterByBetrieb(String betriebId) =>
      instance.eigenauftragLocals.filter().betriebIdEqualTo(betriebId).findAll();
  static Stream<List<EigenauftragLocal>> eigenauftragWatchByBetrieb(String betriebId) =>
      instance.eigenauftragLocals.filter().betriebIdEqualTo(betriebId).watch(fireImmediately: true);

  // ─── BetriebKontakt ───
  static Future<List<BetriebKontaktLocal>> betriebKontaktFilterByBetrieb(String betriebId) =>
      instance.betriebKontaktLocals.filter().betriebIdEqualTo(betriebId).findAll();
  static Stream<List<BetriebKontaktLocal>> betriebKontaktWatchByBetrieb(String betriebId) =>
      instance.betriebKontaktLocals.filter().betriebIdEqualTo(betriebId).watch(fireImmediately: true);
  static Future<BetriebKontaktLocal?> betriebKontaktGet(int id) =>
      instance.betriebKontaktLocals.get(id);
  static Future<void> betriebKontaktPut(BetriebKontaktLocal k) =>
      instance.writeTxn(() => instance.betriebKontaktLocals.put(k));
  static Future<void> betriebKontaktDelete(int id) =>
      instance.writeTxn(() => instance.betriebKontaktLocals.delete(id));
  static Future<BetriebKontaktLocal?> betriebKontaktFindByServerId(String serverId) =>
      instance.betriebKontaktLocals.filter().serverIdEqualTo(serverId).findFirst();

  // ─── BetriebRechnungsadresse ───
  static Future<BetriebRechnungsadresseLocal?> rechnungsadresseFindByBetrieb(String betriebId) =>
      instance.betriebRechnungsadresseLocals.filter().betriebIdEqualTo(betriebId).findFirst();
  static Stream<List<BetriebRechnungsadresseLocal>> rechnungsadresseWatchByBetrieb(String betriebId) =>
      instance.betriebRechnungsadresseLocals.filter().betriebIdEqualTo(betriebId).watch(fireImmediately: true);
  static Future<BetriebRechnungsadresseLocal?> rechnungsadresseGet(int id) =>
      instance.betriebRechnungsadresseLocals.get(id);
  static Future<void> rechnungsadressePut(BetriebRechnungsadresseLocal r) =>
      instance.writeTxn(() => instance.betriebRechnungsadresseLocals.put(r));
  static Future<void> rechnungsadresseDelete(int id) =>
      instance.writeTxn(() => instance.betriebRechnungsadresseLocals.delete(id));
  static Future<BetriebRechnungsadresseLocal?> rechnungsadresseFindByServerId(String serverId) =>
      instance.betriebRechnungsadresseLocals.filter().serverIdEqualTo(serverId).findFirst();

  // ─── Bierleitung ───
  static Future<List<BierleitungLocal>> bierleitungFilterByAnlage(String anlageId) =>
      instance.bierleitungLocals.filter().anlageIdEqualTo(anlageId).sortByLeitungsNummer().findAll();
  static Stream<List<BierleitungLocal>> bierleitungWatchByAnlage(String anlageId) =>
      instance.bierleitungLocals.filter().anlageIdEqualTo(anlageId).sortByLeitungsNummer().watch(fireImmediately: true);
  static Future<BierleitungLocal?> bierleitungGet(int id) =>
      instance.bierleitungLocals.get(id);
  static Future<void> bierleitungPut(BierleitungLocal l) =>
      instance.writeTxn(() => instance.bierleitungLocals.put(l));
  static Future<void> bierleitungDelete(int id) =>
      instance.writeTxn(() => instance.bierleitungLocals.delete(id));

  // ─── PikettDienst ───
  static Future<List<PikettDienstLocal>> pikettDienstFindAll() =>
      instance.pikettDienstLocals.where().findAll();
  static Stream<List<PikettDienstLocal>> pikettDienstWatchAll() =>
      instance.pikettDienstLocals.where().watch(fireImmediately: true);
  static Future<int> pikettDienstCount() =>
      instance.pikettDienstLocals.count();
  static Future<PikettDienstLocal?> pikettDienstGet(int id) =>
      instance.pikettDienstLocals.get(id);
  static Future<void> pikettDienstPut(PikettDienstLocal p) =>
      instance.writeTxn(() => instance.pikettDienstLocals.put(p));
  static Future<void> pikettDienstDelete(int id) =>
      instance.writeTxn(() => instance.pikettDienstLocals.delete(id));
  static Future<PikettDienstLocal?> pikettDienstFindByServerId(String serverId) =>
      instance.pikettDienstLocals.filter().serverIdEqualTo(serverId).findFirst();

  // ─── Eroeffnungsreinigung ───
  static Future<List<EroeffnungsreinigungLocal>> eroeffnungsreinigungFindAll() =>
      instance.eroeffnungsreinigungLocals.where().findAll();
  static Stream<List<EroeffnungsreinigungLocal>> eroeffnungsreinigungWatchAll() =>
      instance.eroeffnungsreinigungLocals.where().watch(fireImmediately: true);
  static Future<int> eroeffnungsreinigungCount() =>
      instance.eroeffnungsreinigungLocals.count();
  static Future<EroeffnungsreinigungLocal?> eroeffnungsreinigungGet(int id) =>
      instance.eroeffnungsreinigungLocals.get(id);
  static Future<void> eroeffnungsreinigungPut(EroeffnungsreinigungLocal e) =>
      instance.writeTxn(() => instance.eroeffnungsreinigungLocals.put(e));
  static Future<void> eroeffnungsreinigungDelete(int id) =>
      instance.writeTxn(() => instance.eroeffnungsreinigungLocals.delete(id));
  static Future<List<EroeffnungsreinigungLocal>> eroeffnungsreinigungFilterByBetrieb(String betriebId) =>
      instance.eroeffnungsreinigungLocals.filter().betriebIdEqualTo(betriebId).findAll();
  static Stream<List<EroeffnungsreinigungLocal>> eroeffnungsreinigungWatchByBetrieb(String betriebId) =>
      instance.eroeffnungsreinigungLocals.filter().betriebIdEqualTo(betriebId).watch(fireImmediately: true);

  // ─── Cascade Deletes ───
  static Future<void> anlageDeleteCascade(int id) async {
    final anlage = await instance.anlageLocals.get(id);
    if (anlage == null) return;
    final serverId = anlage.serverId ?? '';
    await instance.writeTxn(() async {
      // Kinder löschen
      final bierleitungen = await instance.bierleitungLocals.filter().anlageIdEqualTo(serverId).findAll();
      await instance.bierleitungLocals.deleteAll(bierleitungen.map((e) => e.id).toList());
      final reinigungen = await instance.reinigungLocals.filter().anlageIdEqualTo(serverId).findAll();
      await instance.reinigungLocals.deleteAll(reinigungen.map((e) => e.id).toList());
      final stoerungen = await instance.stoerungLocals.filter().anlageIdEqualTo(serverId).findAll();
      await instance.stoerungLocals.deleteAll(stoerungen.map((e) => e.id).toList());
      // Anlage selbst löschen
      await instance.anlageLocals.delete(id);
    });
  }

  static Future<void> betriebDeleteCascade(int id) async {
    final betrieb = await instance.betriebLocals.get(id);
    if (betrieb == null) return;
    final serverId = betrieb.serverId ?? '';
    // Anlagen des Betriebs finden
    final anlagen = await instance.anlageLocals.filter().betriebIdEqualTo(serverId).findAll();
    // Jede Anlage kaskadierend löschen
    for (final anlage in anlagen) {
      await anlageDeleteCascade(anlage.id);
    }
    await instance.writeTxn(() async {
      // Kontakte löschen
      final kontakte = await instance.betriebKontaktLocals.filter().betriebIdEqualTo(serverId).findAll();
      await instance.betriebKontaktLocals.deleteAll(kontakte.map((e) => e.id).toList());
      // Rechnungsadresse löschen
      final adressen = await instance.betriebRechnungsadresseLocals.filter().betriebIdEqualTo(serverId).findAll();
      await instance.betriebRechnungsadresseLocals.deleteAll(adressen.map((e) => e.id).toList());
      // Betrieb selbst löschen
      await instance.betriebLocals.delete(id);
    });
  }
}
