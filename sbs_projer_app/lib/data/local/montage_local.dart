import 'package:isar/isar.dart';

part 'montage_local.g.dart';

@collection
class MontageLocal {
  Id id = Isar.autoIncrement;

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  String? anlageId;
  late String betriebId;
  late String montageTyp;
  late String beschreibung;
  String? referenzNr;
  late DateTime datum;
  String? uhrzeitStart;
  String? uhrzeitEnde;
  String status = 'geplant';

  // Preis
  String? preislisteId;
  double? stundensatz;
  double? dauerStunden;
  double? kostenArbeit;

  DateTime? abrechnungsMonat;
  bool abgerechnet = false;

  // Material (bis 7 Positionen)
  String? material1Id;
  double? material1Menge;
  String? material2Id;
  double? material2Menge;
  String? material3Id;
  double? material3Menge;
  String? material4Id;
  double? material4Menge;
  String? material5Id;
  double? material5Menge;
  String? material6Id;
  double? material6Menge;
  String? material7Id;
  double? material7Menge;

  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
