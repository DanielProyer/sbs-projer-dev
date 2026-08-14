/// Web-Stub für EventGeraetLocal (kein Isar auf Web).
class EventGeraetLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String eventId = '';
  String typ = '';
  String bezeichnung = '';
  int? anzahlTanks;
  String? standortNotiz;
  double? latitude;
  double? longitude;
  String? positionQuelle;
  String? positionGenauigkeit;
  bool inBetrieb = false;
  DateTime? inBetriebAm;
  int sortierung = 0;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
