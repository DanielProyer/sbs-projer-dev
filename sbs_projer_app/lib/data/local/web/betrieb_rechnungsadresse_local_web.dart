class BetriebRechnungsadresseLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String betriebId = '';
  String? firma;
  String? vorname;
  String nachname = '';
  String strasse = '';
  String? nr;
  String plz = '';
  String ort = '';
  String? email;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
