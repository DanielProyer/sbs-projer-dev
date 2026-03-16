class BetriebKontaktLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String betriebId = '';
  String vorname = '';
  String? nachname;
  String? funktion;
  String? telefon;
  String? email;
  String? telefonNormalized;
  String? phoneContactId;
  String kontaktMethode = 'telefon';
  bool istHauptkontakt = false;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
