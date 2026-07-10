/// Web-Stub für EventStandAnlageLocal (kein Isar auf Web).
class EventStandAnlageLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String standId = '';
  String typ = '';
  String? bezeichnung;
  int anzahl = 1;
  int sortierung = 0;
  DateTime? createdAt;
  DateTime? updatedAt;
}
