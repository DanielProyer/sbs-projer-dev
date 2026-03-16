class PikettDienstLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  DateTime datumStart = DateTime.now();
  DateTime datumEnde = DateTime.now();
  String? referenzNr;
  bool istAktiv = false;

  // Preis
  String? preislisteId;
  double? pauschale;
  int anzahlFeiertage = 0;
  double? feiertagZuschlag;
  double? pauschaleGesamt;

  DateTime? abrechnungsMonat;
  bool abgerechnet = false;

  // Google Calendar
  String? googleCalendarEventId;
  String kalenderSyncStatus = 'pending';

  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
