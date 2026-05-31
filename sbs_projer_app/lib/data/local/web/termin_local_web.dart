class TerminLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String betriebId = '';
  DateTime datum = DateTime.now();
  String? uhrzeitVon;
  String? uhrzeitBis;
  String typ = 'sonstiges';
  String anlass = 'manuell';
  String titel = '';
  String? notizen;
  String status = 'geplant';
  int erinnerungTage = 3;
  bool erinnerungAktiv = false;
  int erinnerungVorlaufMinuten = 1440;
  DateTime? createdAt;
  DateTime? updatedAt;
}
