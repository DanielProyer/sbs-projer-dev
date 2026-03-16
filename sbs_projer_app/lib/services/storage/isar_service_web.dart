class IsarService {
  static dynamic get instance =>
      throw UnsupportedError('Isar not available on web');

  static Future<T> writeTxn<T>(Future<T> Function() callback) =>
      throw UnsupportedError('Isar not available on web');

  static Future<void> initialize() async {}

  static Future<void> close() async {}

  // ─── Betrieb ───
  static dynamic betriebFindAll() => throw UnsupportedError('Isar not available on web');
  static dynamic betriebWatchAll() => throw UnsupportedError('Isar not available on web');
  static dynamic betriebCount() => throw UnsupportedError('Isar not available on web');
  static dynamic betriebGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebPut(dynamic b) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebFilterByStatus(String status) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebFindByServerId(String serverId) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebFilterByRegion(String regionId) => throw UnsupportedError('Isar not available on web');

  // ─── Anlage ───
  static dynamic anlageFindAll() => throw UnsupportedError('Isar not available on web');
  static dynamic anlageWatchAll() => throw UnsupportedError('Isar not available on web');
  static dynamic anlageCount() => throw UnsupportedError('Isar not available on web');
  static dynamic anlageGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic anlagePut(dynamic a) => throw UnsupportedError('Isar not available on web');
  static dynamic anlageDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic anlageFindByServerId(String serverId) => throw UnsupportedError('Isar not available on web');
  static dynamic anlageFilterByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic anlageWatchByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');

  // ─── Region ───
  static dynamic regionFindAll() => throw UnsupportedError('Isar not available on web');
  static dynamic regionWatchAll() => throw UnsupportedError('Isar not available on web');
  static dynamic regionCount() => throw UnsupportedError('Isar not available on web');
  static dynamic regionGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic regionPut(dynamic r) => throw UnsupportedError('Isar not available on web');
  static dynamic regionDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic regionFindByServerId(String serverId) => throw UnsupportedError('Isar not available on web');

  // ─── Reinigung ───
  static dynamic reinigungFindAll() => throw UnsupportedError('Isar not available on web');
  static dynamic reinigungWatchAll() => throw UnsupportedError('Isar not available on web');
  static dynamic reinigungCount() => throw UnsupportedError('Isar not available on web');
  static dynamic reinigungGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic reinigungPut(dynamic r) => throw UnsupportedError('Isar not available on web');
  static dynamic reinigungDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic reinigungFindByServerId(String serverId) => throw UnsupportedError('Isar not available on web');
  static dynamic reinigungFilterByAnlage(String anlageId) => throw UnsupportedError('Isar not available on web');
  static dynamic reinigungFilterByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic reinigungWatchByAnlage(String anlageId) => throw UnsupportedError('Isar not available on web');
  static dynamic reinigungWatchByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');

  // ─── Stoerung ───
  static dynamic stoerungFindAll() => throw UnsupportedError('Isar not available on web');
  static dynamic stoerungWatchAll() => throw UnsupportedError('Isar not available on web');
  static dynamic stoerungCount() => throw UnsupportedError('Isar not available on web');
  static dynamic stoerungGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic stoerungPut(dynamic s) => throw UnsupportedError('Isar not available on web');
  static dynamic stoerungDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic stoerungFilterByAnlage(String anlageId) => throw UnsupportedError('Isar not available on web');
  static dynamic stoerungFilterByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic stoerungWatchByAnlage(String anlageId) => throw UnsupportedError('Isar not available on web');
  static dynamic stoerungWatchByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic stoerungFilterByNummer(String prefix) => throw UnsupportedError('Isar not available on web');

  // ─── Montage ───
  static dynamic montageFindAll() => throw UnsupportedError('Isar not available on web');
  static dynamic montageWatchAll() => throw UnsupportedError('Isar not available on web');
  static dynamic montageCount() => throw UnsupportedError('Isar not available on web');
  static dynamic montageGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic montagePut(dynamic m) => throw UnsupportedError('Isar not available on web');
  static dynamic montageDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic montageFilterByAnlage(String anlageId) => throw UnsupportedError('Isar not available on web');
  static dynamic montageFilterByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic montageWatchByAnlage(String anlageId) => throw UnsupportedError('Isar not available on web');
  static dynamic montageWatchByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');

  // ─── Eigenauftrag ───
  static dynamic eigenauftragFindAll() => throw UnsupportedError('Isar not available on web');
  static dynamic eigenauftragWatchAll() => throw UnsupportedError('Isar not available on web');
  static dynamic eigenauftragCount() => throw UnsupportedError('Isar not available on web');
  static dynamic eigenauftragGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic eigenauftragPut(dynamic e) => throw UnsupportedError('Isar not available on web');
  static dynamic eigenauftragDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic eigenauftragFilterByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic eigenauftragWatchByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');

  // ─── BetriebKontakt ───
  static dynamic betriebKontaktFilterByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebKontaktWatchByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebKontaktGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebKontaktPut(dynamic k) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebKontaktDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebKontaktFindByServerId(String serverId) => throw UnsupportedError('Isar not available on web');

  // ─── BetriebRechnungsadresse ───
  static dynamic rechnungsadresseFindByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic rechnungsadresseWatchByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic rechnungsadresseGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic rechnungsadressePut(dynamic r) => throw UnsupportedError('Isar not available on web');
  static dynamic rechnungsadresseDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic rechnungsadresseFindByServerId(String serverId) => throw UnsupportedError('Isar not available on web');

  // ─── Bierleitung ───
  static dynamic bierleitungFilterByAnlage(String anlageId) => throw UnsupportedError('Isar not available on web');
  static dynamic bierleitungWatchByAnlage(String anlageId) => throw UnsupportedError('Isar not available on web');
  static dynamic bierleitungGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic bierleitungPut(dynamic l) => throw UnsupportedError('Isar not available on web');
  static dynamic bierleitungDelete(int id) => throw UnsupportedError('Isar not available on web');

  // ─── PikettDienst ───
  static dynamic pikettDienstFindAll() => throw UnsupportedError('Isar not available on web');
  static dynamic pikettDienstWatchAll() => throw UnsupportedError('Isar not available on web');
  static dynamic pikettDienstCount() => throw UnsupportedError('Isar not available on web');
  static dynamic pikettDienstGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic pikettDienstPut(dynamic p) => throw UnsupportedError('Isar not available on web');
  static dynamic pikettDienstDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic pikettDienstFindByServerId(String serverId) => throw UnsupportedError('Isar not available on web');

  // ─── Eroeffnungsreinigung ───
  static dynamic eroeffnungsreinigungFindAll() => throw UnsupportedError('Isar not available on web');
  static dynamic eroeffnungsreinigungWatchAll() => throw UnsupportedError('Isar not available on web');
  static dynamic eroeffnungsreinigungCount() => throw UnsupportedError('Isar not available on web');
  static dynamic eroeffnungsreinigungGet(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic eroeffnungsreinigungPut(dynamic e) => throw UnsupportedError('Isar not available on web');
  static dynamic eroeffnungsreinigungDelete(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic eroeffnungsreinigungFilterByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');
  static dynamic eroeffnungsreinigungWatchByBetrieb(String betriebId) => throw UnsupportedError('Isar not available on web');

  // ─── Cascade Deletes ───
  static dynamic anlageDeleteCascade(int id) => throw UnsupportedError('Isar not available on web');
  static dynamic betriebDeleteCascade(int id) => throw UnsupportedError('Isar not available on web');
}
