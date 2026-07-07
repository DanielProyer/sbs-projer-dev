class BetriebLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String name = '';
  String? strasse;
  String? nr;
  String? plz;
  String? ort;
  String? telefon;
  String? regionId;
  String? email;
  String? website;
  String? zugangNotizen;
  String? betriebNr;
  String? weNummer;
  String? agNummer;
  String status = 'aktiv';
  bool istMeinKunde = true;
  bool istBergkunde = false;
  bool istSaisonbetrieb = false;
  bool winterSaisonAktiv = false;
  DateTime? winterStartDatum;
  DateTime? winterEndeDatum;
  bool sommerSaisonAktiv = false;
  DateTime? sommerStartDatum;
  DateTime? sommerEndeDatum;
  List<String> ruhetage = [];
  List<String> zapfsysteme = [];
  List<String> zahlerAliase = [];
  String rechnungsstellung = 'rechnung_mail';
  double? latitude;
  double? longitude;
  DateTime? ferienStart;
  DateTime? ferienEnde;
  DateTime? ferien2Start;
  DateTime? ferien2Ende;
  DateTime? ferien3Start;
  DateTime? ferien3Ende;
  DateTime? ferien4Start;
  DateTime? ferien4Ende;
  DateTime? ferien5Start;
  DateTime? ferien5Ende;
  bool keineBetriebsferien = false;
  String? oeffnungszeitenJson;
  String? servicezeitMorgenAb;
  String? servicezeitMorgenBis;
  String? servicezeitNachmittagAb;
  String? servicezeitNachmittagBis;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
