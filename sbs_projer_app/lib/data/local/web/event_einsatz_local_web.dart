/// Web-Stub für EventEinsatzLocal (kein Isar auf Web).
class EventEinsatzLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String eventId = '';
  String? standId;
  DateTime zeitpunkt = DateTime(2000);
  String beschreibung = '';
  String? material;
  DateTime? createdAt;
  DateTime? updatedAt;
}
