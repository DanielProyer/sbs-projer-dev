class KontaktLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String? betriebId;
  String vorname = '';
  String? nachname;
  String? funktion;
  String kategorie = 'betrieb';
  String? rolle;
  String? telefon;
  String? email;
  String? telefonNormalized;
  String kontaktMethode = 'telefon';
  bool istHauptkontakt = false;
  bool istDuAnrede = false;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
