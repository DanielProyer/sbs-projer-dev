import 'package:isar/isar.dart';

part 'eigenauftrag_local.g.dart';

@collection
class EigenauftragLocal {
  Id id = Isar.autoIncrement;

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  late String anlageId;
  late String betriebId;
  late String stoerungsnummer;
  String? referenzNr;
  late DateTime datum;
  String? uhrzeit;
  String? entdecktBeiServiceId;
  late String problemBeschreibung;
  String? loesungBeschreibung;
  String status = 'behoben';

  // Preis
  String? preislisteId;
  double? pauschale;

  DateTime? abrechnungsMonat;
  bool abgerechnet = false;

  // Material (bis 5 Positionen)
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

  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
