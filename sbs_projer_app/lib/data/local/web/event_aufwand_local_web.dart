/// Web-Stub für EventAufwandLocal (kein Isar auf Web).
class EventAufwandLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String eventId = '';
  DateTime datum = DateTime(2000);
  String kategorie = 'pikett';
  String? notiz;
  double stunden = 0;
  DateTime? createdAt;
  DateTime? updatedAt;
}
