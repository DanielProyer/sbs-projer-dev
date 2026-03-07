import 'package:isar/isar.dart';

part 'stoerung_local.g.dart';

@collection
class StoerungLocal {
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
  String? uhrzeitStart;
  String? uhrzeitEnde;
  String? anlageTyp;
  late String problemBeschreibung;
  String? loesungBeschreibung;
  bool istPikettEinsatz = false;
  String status = 'offen';
  int? stoerungBereich;

  // Preis
  String? preislisteId;
  bool istBergkunde = false;
  int anfahrtKm = 0;
  bool istWochenende = false;
  double? komplexitaetZuschlag;
  double? preisBasis;
  double? preisAnfahrt;
  double? preisWochenende;
  double? preisNetto;
  double? mwstSatz;
  double? preisMwst;
  double? preisBrutto;

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

  DateTime? abrechnungsMonat;
  bool abgerechnet = false;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
