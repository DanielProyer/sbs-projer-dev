class BergkundenpauschaleLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String betriebId = '';
  String? reinigungId;
  DateTime datum = DateTime.now();
  double betrag = 180.0;
  String? notizen;
  bool abgerechnet = false;
  DateTime? abrechnungsMonat;
  DateTime? createdAt;
  DateTime? updatedAt;
}
