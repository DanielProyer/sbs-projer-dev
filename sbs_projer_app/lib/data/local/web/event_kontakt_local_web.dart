/// Web-Stub für EventKontaktLocal (kein Isar auf Web).
class EventKontaktLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String eventId = '';
  String kontaktId = '';
  String rolle = '';
  String? bemerkung;
  DateTime? createdAt;
  DateTime? updatedAt;
}
