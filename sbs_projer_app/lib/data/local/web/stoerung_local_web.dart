class StoerungLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String? anlageId;
  String? betriebId;
  String stoerungsnummer = '';
  String? referenzNr;
  DateTime datum = DateTime.now();
  String? uhrzeitStart;
  String? uhrzeitEnde;
  String? anlageTyp;
  String problemBeschreibung = '';
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

  // Material
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
