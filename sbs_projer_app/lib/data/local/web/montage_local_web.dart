class MontageLocal {
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
  String montageTyp = '';
  String beschreibung = '';
  String? referenzNr;
  DateTime datum = DateTime.now();
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
