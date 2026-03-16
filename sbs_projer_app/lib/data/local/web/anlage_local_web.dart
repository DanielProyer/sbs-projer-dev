class AnlageLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String betriebId = '';
  String? bezeichnung;
  String? seriennummer;
  String typAnlage = '';
  String? typSaeule;
  int anzahlHaehne = 1;
  bool backpython = false;
  bool booster = false;
  String vorkuehler = 'keiner';
  String? durchlaufkuehler;
  DateTime? letzterWasserwechsel;
  String? gasTyp1;
  String? gasTyp2;
  double? hauptdruckBar;
  bool hatNiederdruck = false;
  String? servicezeitMorgenAb;
  String? servicezeitMorgenBis;
  String? servicezeitNachmittagAb;
  String? servicezeitNachmittagBis;
  String reinigungRhythmus = '4-Wochen';
  DateTime? letzteReinigung;
  DateTime? naechsteReinigung;
  String status = 'aktiv';
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
