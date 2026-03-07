import 'package:isar/isar.dart';

part 'preis_local.g.dart';

@collection
class PreisLocal {
  Id id = Isar.autoIncrement;

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  late DateTime gueltigAb;
  DateTime? gueltigBis;
  double mwstSatz = 8.10;
  double bergkundenZuschlag = 180.00;

  // Reinigung Grundtarife
  double grundtarifReinigungBier = 0;
  double grundtarifReinigungOrion = 0;
  double grundtarifHeigenie = 0;
  double grundtarifReinigungFremd = 0;
  double grundtarifWein = 0;

  // Zusatz pro Hahn
  double zusatzHahnEigen = 0;
  double zusatzHahnOrion = 0;
  double zusatzHahnFremd = 0;
  double zusatzHahnWein = 0;
  double zusatzHahnAndererStandort = 0;

  // Pauschalen
  double eigenauftragPauschale = 30.00;
  double montageStundensatz = 0;
  double pikettPauschale = 160.00;
  double pikettFeiertagZuschlag = 80.00;
  double eroeffnungPreisNormal = 60.00;
  double eroeffnungPreisBergkunde = 135.00;

  // Störung Preise (Bereich 1-5, Normal/Bergkunde)
  double stoerung1Normal = 55.00;
  double stoerung1Bergkunde = 130.00;
  double stoerung2Normal = 55.00;
  double stoerung2Bergkunde = 130.00;
  double stoerung3Normal = 90.00;
  double stoerung3Bergkunde = 165.00;
  double stoerung4Normal = 45.00;
  double stoerung4Bergkunde = 120.00;
  double stoerung5Normal = 45.00;
  double stoerung5Bergkunde = 120.00;

  // Störung Anfahrt
  double stoerungAnfahrtPauschale = 60.00;
  int stoerungAnfahrtKmGrenze = 80;
  double stoerungAnfahrtKmSatz = 0.720;
  double stoerungWochenendeZuschlag = 100.00;

  DateTime? createdAt;
  DateTime? updatedAt;
}
