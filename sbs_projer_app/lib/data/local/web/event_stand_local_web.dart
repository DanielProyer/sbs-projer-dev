/// Web-Stub für EventStandLocal (kein Isar auf Web).
class EventStandLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String eventId = '';
  String name = '';
  String? standnummer;
  int sortierung = 0;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
