class BetriebFerienLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String betriebId = '';
  DateTime von = DateTime.now();
  DateTime bis = DateTime.now();
  String quelle = 'kunde';
  DateTime? bestaetigtAm;
  String? notiz;
  DateTime? createdAt;
  DateTime? updatedAt;
}
