/// Web-Stub für EventKuehlerMessungLocal (kein Isar auf Web).
class EventKuehlerMessungLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String geraetId = '';
  DateTime gemessenAm = DateTime.now();
  double temperatur = 0;
  String? notiz;
  DateTime? createdAt;
  DateTime? updatedAt;
}
