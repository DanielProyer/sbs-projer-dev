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
  String? schliessungsgrund;
  DateTime? schliessungsdatum;
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

  /// Wann zuletzt jemand die Ferienfrage beim Reinigungs-Abschluss
  /// beantwortet hat (`betriebe.ferien_bestaetigt_am`). Steuert zusammen mit
  /// [ferienFrageRuhtBis], ob `ferienFrageZeigen()` erneut fragt.
  DateTime? ferienBestaetigtAm;

  /// Antwort "weiss nicht" im Abschluss-Dialog: bis dahin ruht die Frage
  /// (`betriebe.ferien_frage_ruht_bis`), unabhaengig von [ferienBestaetigtAm].
  DateTime? ferienFrageRuhtBis;

  /// Trennt "kein Ruhetag bekannt" (null) von "geprueft, hat keinen
  /// Ruhetag" (`betriebe.ruhetage_bestaetigt_am`) — ein leeres
  /// `ruhetage`-Array allein ist mehrdeutig.
  DateTime? ruhetageBestaetigtAm;

  /// Ferien-Perioden aus der Tabelle `betrieb_ferien` (nicht gespeichert,
  /// wird vom Provider nach dem Laden gesetzt). Ersetzt schrittweise die
  /// obigen fuenf festen Spaltenpaare — siehe core/util/betrieb_ferien.dart.
  /// `null` = noch nicht geladen (dann greifen die alten Spalten),
  /// leere Liste = geladen und dieser Betrieb hat keine Ferien.
  List<({DateTime von, DateTime bis})>? ferienPerioden;
  String? oeffnungszeitenJson;
  String? servicezeitMorgenAb;
  String? servicezeitMorgenBis;
  String? servicezeitNachmittagAb;
  String? servicezeitNachmittagBis;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
