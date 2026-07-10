/// Web-Stub für EventDokumentLocal (kein Isar auf Web).
class EventDokumentLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String eventId = '';
  String bezeichnung = '';
  String dateiPfad = '';
  DateTime? createdAt;
  DateTime? updatedAt;
}
