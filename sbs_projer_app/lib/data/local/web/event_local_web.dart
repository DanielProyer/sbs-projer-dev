/// Web-Stub für EventLocal (kein Isar auf Web).
class EventLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String betriebId = '';
  int jahr = 0;
  DateTime? terminVon;
  DateTime? terminBis;
  String? notizen;
  String? lageplanPfad;
  String? lageplanPunkteJson;
  DateTime? createdAt;
  DateTime? updatedAt;
}
