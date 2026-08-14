/// Web-Stub für EventLeitungLocal (kein Isar auf Web).
class EventLeitungLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String eventId = '';
  String nummer = '';
  String quelleId = '';
  String? kuehlerId;
  String? standId;
  String? standAnlageId;
  bool inBetrieb = false;
  DateTime? inBetriebAm;
  int sortierung = 0;
  String? notiz;
  DateTime? createdAt;
  DateTime? updatedAt;
}
