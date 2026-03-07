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
        BierleitungLocalSchema,
        LagerLocalSchema,
        PreisLocalSchema,
        SyncMetaLocalSchema,
      ],
      directory: dir.path,
    );
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
