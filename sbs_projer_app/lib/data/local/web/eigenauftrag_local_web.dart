class EigenauftragLocal {
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
  String? uhrzeit;
  String? entdecktBeiServiceId;
  String problemBeschreibung = '';
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
