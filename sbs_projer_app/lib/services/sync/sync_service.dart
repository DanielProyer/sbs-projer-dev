import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sbs_projer_app/services/storage/isar_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/connectivity/connectivity_service.dart';

// Local Models
import 'package:sbs_projer_app/data/local/sync_meta_local.dart';
import 'package:sbs_projer_app/data/local/region_local.dart';
import 'package:sbs_projer_app/data/local/preis_local.dart';
import 'package:sbs_projer_app/data/local/lager_local.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local.dart';
import 'package:sbs_projer_app/data/local/betrieb_local.dart';
import 'package:sbs_projer_app/data/local/betrieb_kontakt_local.dart';
import 'package:sbs_projer_app/data/local/betrieb_rechnungsadresse_local.dart';
import 'package:sbs_projer_app/data/local/anlage_local.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local.dart';
import 'package:sbs_projer_app/data/local/reinigung_local.dart';
import 'package:sbs_projer_app/data/local/stoerung_local.dart';
import 'package:sbs_projer_app/data/local/montage_local.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local.dart';

// DTOs
import 'package:sbs_projer_app/data/models/region.dart';
import 'package:sbs_projer_app/data/models/preis.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/pikett_dienst.dart';
import 'package:sbs_projer_app/data/models/betrieb.dart';
import 'package:sbs_projer_app/data/models/betrieb_kontakt.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/anlage.dart';
import 'package:sbs_projer_app/data/models/bierleitung.dart';
import 'package:sbs_projer_app/data/models/reinigung.dart';
import 'package:sbs_projer_app/data/models/stoerung.dart';
import 'package:sbs_projer_app/data/models/montage.dart';
import 'package:sbs_projer_app/data/models/eigenauftrag.dart';
import 'package:sbs_projer_app/data/models/eroeffnungsreinigung.dart';

// Mappers
import 'package:sbs_projer_app/data/mappers/region_mapper.dart';
import 'package:sbs_projer_app/data/mappers/preis_mapper.dart';
import 'package:sbs_projer_app/data/mappers/lager_mapper.dart';
import 'package:sbs_projer_app/data/mappers/pikett_dienst_mapper.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_mapper.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_kontakt_mapper.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_rechnungsadresse_mapper.dart';
import 'package:sbs_projer_app/data/mappers/anlage_mapper.dart';
import 'package:sbs_projer_app/data/mappers/bierleitung_mapper.dart';
import 'package:sbs_projer_app/data/mappers/reinigung_mapper.dart';
import 'package:sbs_projer_app/data/mappers/stoerung_mapper.dart';
import 'package:sbs_projer_app/data/mappers/montage_mapper.dart';
import 'package:sbs_projer_app/data/mappers/eigenauftrag_mapper.dart';
import 'package:sbs_projer_app/data/mappers/eroeffnungsreinigung_mapper.dart';

enum SyncState { idle, syncing, error }

class SyncResult {
  final int pushed;
  final int pulled;
  final List<String> errors;

  SyncResult({this.pushed = 0, this.pulled = 0, List<String>? errors})
      : errors = errors ?? [];

  bool get hasErrors => errors.isNotEmpty;
}

class SyncService {
  static Isar get _isar => IsarService.instance;
  static SupabaseClient get _client => SupabaseService.client;

  // === State ===
  static final _stateController = StreamController<SyncState>.broadcast();
  static Stream<SyncState> get stateStream => _stateController.stream;
  static SyncState _state = SyncState.idle;
  static SyncState get state => _state;
  static bool _isSyncing = false;

  static void _setState(SyncState s) {
    _state = s;
    _stateController.add(s);
  }

  // === Connectivity Listener ===
  static StreamSubscription<bool>? _subscription;

  static void startListening() {
    _subscription?.cancel();
    _subscription = ConnectivityService.onConnectivityChanged.listen((online) {
      if (online) syncAll();
    });
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  // === Sync Orchestrator ===
  static Future<SyncResult> syncAll() async {
    if (_isSyncing || !ConnectivityService.isOnline) return SyncResult();

    _isSyncing = true;
    _setState(SyncState.syncing);

    int totalPushed = 0;
    int totalPulled = 0;
    final errors = <String>[];

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return SyncResult(errors: ['Nicht eingeloggt']);

      // Sync in Tier-Reihenfolge (FK-Abhängigkeiten)
      final tiers = <List<Future<({int pushed, int pulled})> Function()>>[
        // Tier 0: Unabhängig
        [
          () => _syncRegionen(userId),
          () => _syncPreise(userId),
          () => _syncLager(userId),
          () => _syncPikettDienste(userId),
        ],
        // Tier 1: → Region
        [() => _syncBetriebe(userId)],
        // Tier 2: → Betrieb
        [
          () => _syncBetriebKontakte(userId),
          () => _syncBetriebRechnungsadressen(userId),
          () => _syncAnlagen(userId),
        ],
        // Tier 3: → Anlage
        [
          () => _syncBierleitungen(userId),
          () => _syncReinigungen(userId),
          () => _syncStoerungen(userId),
          () => _syncMontagen(userId),
        ],
        // Tier 4: → Betrieb/Anlage
        [
          () => _syncEigenauftraege(userId),
          () => _syncEroeffnungsreinigungen(userId),
        ],
      ];

      for (final tier in tiers) {
        final results = await Future.wait(
          tier.map((fn) async {
            try {
              return await fn();
            } catch (e) {
              errors.add(e.toString());
              debugPrint('Sync error: $e');
              return (pushed: 0, pulled: 0);
            }
          }),
        );
        for (final r in results) {
          totalPushed += r.pushed;
          totalPulled += r.pulled;
        }
      }

      _setState(errors.isEmpty ? SyncState.idle : SyncState.error);
    } catch (e) {
      errors.add(e.toString());
      _setState(SyncState.error);
    } finally {
      _isSyncing = false;
    }

    debugPrint('Sync: $totalPushed pushed, $totalPulled pulled, ${errors.length} errors');
    return SyncResult(pushed: totalPushed, pulled: totalPulled, errors: errors);
  }

  // === SyncMeta Helpers ===
  static Future<SyncMetaLocal> _getMeta(String entity) async {
    return await _isar.syncMetaLocals
            .filter()
            .entityNameEqualTo(entity)
            .findFirst() ??
        (SyncMetaLocal()..entityName = entity);
  }

  static Future<void> _updateMeta(String entity) async {
    final meta = await _getMeta(entity);
    meta.lastPullAt = DateTime.now().toUtc();
    await _isar.writeTxn(() => _isar.syncMetaLocals.put(meta));
  }

  // === Generic Push Helper ===
  static Future<List<T>> _pushToSupabase<T>(
    String table,
    List<T> unsynced,
    Map<String, dynamic> Function(T) toJson,
    void Function(T, String) onSuccess,
  ) async {
    final pushed = <T>[];
    for (final local in unsynced) {
      try {
        final json = toJson(local);
        final res =
            await _client.from(table).upsert(json).select('id').single();
        onSuccess(local, res['id'] as String);
        pushed.add(local);
      } catch (e) {
        debugPrint('Push $table error: $e');
      }
    }
    return pushed;
  }

  // === Generic Pull Helper ===
  static Future<List<Map<String, dynamic>>> _pullRows(
    String table,
    String entity,
    String userId, {
    bool hasUpdatedAt = true,
  }) async {
    final meta = await _getMeta(entity);
    var query = _client.from(table).select().eq('user_id', userId);
    if (hasUpdatedAt && meta.lastPullAt != null) {
      query =
          query.gt('updated_at', meta.lastPullAt!.toUtc().toIso8601String());
    }
    return await query;
  }

  // ============================================================
  // TIER 0: Unabhängige Entitäten
  // ============================================================

  static Future<({int pushed, int pulled})> _syncRegionen(String uid) async {
    final unsynced =
        await _isar.regionLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<RegionLocal>(
      'regionen', unsynced, RegionMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.regionLocals.putAll(pushed));
    }

    final rows = await _pullRows('regionen', 'regionen', uid);
    final toSave = <RegionLocal>[];
    for (final row in rows) {
      final dto = Region.fromJson(row);
      final ex = await _isar.regionLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(RegionMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.regionLocals.putAll(toSave));
    }
    await _updateMeta('regionen');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  static Future<({int pushed, int pulled})> _syncPreise(String uid) async {
    final unsynced =
        await _isar.preisLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<PreisLocal>(
      'preise', unsynced, PreisMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.preisLocals.putAll(pushed));
    }

    final rows = await _pullRows('preise', 'preise', uid);
    final toSave = <PreisLocal>[];
    for (final row in rows) {
      final dto = Preis.fromJson(row);
      final ex = await _isar.preisLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(PreisMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.preisLocals.putAll(toSave));
    }
    await _updateMeta('preise');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  static Future<({int pushed, int pulled})> _syncLager(String uid) async {
    final unsynced =
        await _isar.lagerLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<LagerLocal>(
      'lager', unsynced, LagerMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.lagerLocals.putAll(pushed));
    }

    final rows = await _pullRows('lager', 'lager', uid);
    final toSave = <LagerLocal>[];
    for (final row in rows) {
      final dto = Lager.fromJson(row);
      final ex = await _isar.lagerLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(LagerMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.lagerLocals.putAll(toSave));
    }
    await _updateMeta('lager');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  static Future<({int pushed, int pulled})> _syncPikettDienste(String uid) async {
    final unsynced =
        await _isar.pikettDienstLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<PikettDienstLocal>(
      'pikett_dienste', unsynced, PikettDienstMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.pikettDienstLocals.putAll(pushed));
    }

    final rows = await _pullRows('pikett_dienste', 'pikett_dienste', uid);
    final toSave = <PikettDienstLocal>[];
    for (final row in rows) {
      final dto = PikettDienst.fromJson(row);
      final ex = await _isar.pikettDienstLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(PikettDienstMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.pikettDienstLocals.putAll(toSave));
    }
    await _updateMeta('pikett_dienste');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  // ============================================================
  // TIER 1: Betrieb (→ Region)
  // ============================================================

  static Future<({int pushed, int pulled})> _syncBetriebe(String uid) async {
    final unsynced =
        await _isar.betriebLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<BetriebLocal>(
      'betriebe', unsynced, BetriebMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.betriebLocals.putAll(pushed));
    }

    final rows = await _pullRows('betriebe', 'betriebe', uid);
    final toSave = <BetriebLocal>[];
    for (final row in rows) {
      final dto = Betrieb.fromJson(row);
      final ex = await _isar.betriebLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(BetriebMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.betriebLocals.putAll(toSave));
    }
    await _updateMeta('betriebe');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  // ============================================================
  // TIER 2: BetriebKontakt, Anlage (→ Betrieb)
  // ============================================================

  static Future<({int pushed, int pulled})> _syncBetriebKontakte(String uid) async {
    final unsynced =
        await _isar.betriebKontaktLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<BetriebKontaktLocal>(
      'betrieb_kontakte', unsynced, BetriebKontaktMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.betriebKontaktLocals.putAll(pushed));
    }

    final rows = await _pullRows('betrieb_kontakte', 'betrieb_kontakte', uid);
    final toSave = <BetriebKontaktLocal>[];
    for (final row in rows) {
      final dto = BetriebKontakt.fromJson(row);
      final ex = await _isar.betriebKontaktLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(BetriebKontaktMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.betriebKontaktLocals.putAll(toSave));
    }
    await _updateMeta('betrieb_kontakte');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  static Future<({int pushed, int pulled})> _syncBetriebRechnungsadressen(String uid) async {
    final unsynced =
        await _isar.betriebRechnungsadresseLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<BetriebRechnungsadresseLocal>(
      'betrieb_rechnungsadressen', unsynced, BetriebRechnungsadresseMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.betriebRechnungsadresseLocals.putAll(pushed));
    }

    final rows = await _pullRows('betrieb_rechnungsadressen', 'betrieb_rechnungsadressen', uid);
    final toSave = <BetriebRechnungsadresseLocal>[];
    for (final row in rows) {
      final dto = BetriebRechnungsadresse.fromJson(row);
      final ex = await _isar.betriebRechnungsadresseLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(BetriebRechnungsadresseMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.betriebRechnungsadresseLocals.putAll(toSave));
    }
    await _updateMeta('betrieb_rechnungsadressen');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  static Future<({int pushed, int pulled})> _syncAnlagen(String uid) async {
    final unsynced =
        await _isar.anlageLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<AnlageLocal>(
      'anlagen', unsynced, AnlageMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.anlageLocals.putAll(pushed));
    }

    final rows = await _pullRows('anlagen', 'anlagen', uid);
    final toSave = <AnlageLocal>[];
    for (final row in rows) {
      final dto = Anlage.fromJson(row);
      final ex = await _isar.anlageLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(AnlageMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.anlageLocals.putAll(toSave));
    }
    await _updateMeta('anlagen');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  // ============================================================
  // TIER 3: Bierleitung, Reinigung, Störung, Montage (→ Anlage)
  // ============================================================

  // Bierleitung: Sonderfall – kein updated_at → Full-Pull
  static Future<({int pushed, int pulled})> _syncBierleitungen(String uid) async {
    final unsynced =
        await _isar.bierleitungLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<BierleitungLocal>(
      'bierleitungen', unsynced, BierleitungMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.bierleitungLocals.putAll(pushed));
    }

    // Full-Pull (kein updated_at in DB)
    final rows = await _pullRows('bierleitungen', 'bierleitungen', uid, hasUpdatedAt: false);
    final toSave = <BierleitungLocal>[];
    for (final row in rows) {
      final dto = Bierleitung.fromJson(row);
      final ex = await _isar.bierleitungLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced) {
        continue; // Lokal geändert → nicht überschreiben
      }
      toSave.add(BierleitungMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.bierleitungLocals.putAll(toSave));
    }
    await _updateMeta('bierleitungen');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  static Future<({int pushed, int pulled})> _syncReinigungen(String uid) async {
    final unsynced =
        await _isar.reinigungLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<ReinigungLocal>(
      'reinigungen', unsynced, ReinigungMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.reinigungLocals.putAll(pushed));
    }

    final rows = await _pullRows('reinigungen', 'reinigungen', uid);
    final toSave = <ReinigungLocal>[];
    for (final row in rows) {
      final dto = Reinigung.fromJson(row);
      final ex = await _isar.reinigungLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(ReinigungMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.reinigungLocals.putAll(toSave));
    }
    await _updateMeta('reinigungen');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  static Future<({int pushed, int pulled})> _syncStoerungen(String uid) async {
    final unsynced =
        await _isar.stoerungLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<StoerungLocal>(
      'stoerungen', unsynced, StoerungMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.stoerungLocals.putAll(pushed));
    }

    final rows = await _pullRows('stoerungen', 'stoerungen', uid);
    final toSave = <StoerungLocal>[];
    for (final row in rows) {
      final dto = Stoerung.fromJson(row);
      final ex = await _isar.stoerungLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(StoerungMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.stoerungLocals.putAll(toSave));
    }
    await _updateMeta('stoerungen');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  static Future<({int pushed, int pulled})> _syncMontagen(String uid) async {
    final unsynced =
        await _isar.montageLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<MontageLocal>(
      'montagen', unsynced, MontageMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.montageLocals.putAll(pushed));
    }

    final rows = await _pullRows('montagen', 'montagen', uid);
    final toSave = <MontageLocal>[];
    for (final row in rows) {
      final dto = Montage.fromJson(row);
      final ex = await _isar.montageLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(MontageMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.montageLocals.putAll(toSave));
    }
    await _updateMeta('montagen');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  // ============================================================
  // TIER 4: Eigenauftrag (→ Anlage, optional → Reinigung)
  // ============================================================

  static Future<({int pushed, int pulled})> _syncEigenauftraege(String uid) async {
    final unsynced =
        await _isar.eigenauftragLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<EigenauftragLocal>(
      'eigenauftraege', unsynced, EigenauftragMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.eigenauftragLocals.putAll(pushed));
    }

    final rows = await _pullRows('eigenauftraege', 'eigenauftraege', uid);
    final toSave = <EigenauftragLocal>[];
    for (final row in rows) {
      final dto = Eigenauftrag.fromJson(row);
      final ex = await _isar.eigenauftragLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(EigenauftragMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.eigenauftragLocals.putAll(toSave));
    }
    await _updateMeta('eigenauftraege');
    return (pushed: pushed.length, pulled: toSave.length);
  }

  static Future<({int pushed, int pulled})> _syncEroeffnungsreinigungen(String uid) async {
    final unsynced =
        await _isar.eroeffnungsreinigungLocals.filter().isSyncedEqualTo(false).findAll();
    final pushed = await _pushToSupabase<EroeffnungsreinigungLocal>(
      'eroeffnungsreinigungen', unsynced, EroeffnungsreinigungMapper.toJson,
      (l, id) { l.serverId ??= id; l.isSynced = true; },
    );
    if (pushed.isNotEmpty) {
      await _isar.writeTxn(() => _isar.eroeffnungsreinigungLocals.putAll(pushed));
    }

    final rows = await _pullRows('eroeffnungsreinigungen', 'eroeffnungsreinigungen', uid);
    final toSave = <EroeffnungsreinigungLocal>[];
    for (final row in rows) {
      final dto = Eroeffnungsreinigung.fromJson(row);
      final ex = await _isar.eroeffnungsreinigungLocals.filter().serverIdEqualTo(dto.id).findFirst();
      if (ex != null && !ex.isSynced &&
          (ex.lastModifiedAt?.isAfter(dto.updatedAt ?? DateTime(2000)) ?? false)) {
        continue;
      }
      toSave.add(EroeffnungsreinigungMapper.fromDto(dto, existing: ex));
    }
    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() => _isar.eroeffnungsreinigungLocals.putAll(toSave));
    }
    await _updateMeta('eroeffnungsreinigungen');
    return (pushed: pushed.length, pulled: toSave.length);
  }
}
