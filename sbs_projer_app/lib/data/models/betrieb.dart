class Betrieb {
  final String id;
  final String userId;
  final String name;
  final String? strasse;
  final String? nr;
  final String? plz;
  final String? ort;
  final String? telefon;
  final String? regionId;
  final String? email;
  final String? website;
  final String? zugangNotizen;
  final String? betriebNr;
  final String status;
  final bool istMeinKunde;
  final bool istBergkunde;
  final bool istSaisonbetrieb;
  final bool winterSaisonAktiv;
  final DateTime? winterStartDatum;
  final DateTime? winterEndeDatum;
  final bool sommerSaisonAktiv;
  final DateTime? sommerStartDatum;
  final DateTime? sommerEndeDatum;
  final List<String> ruhetage;
  final List<String> zapfsysteme;
  final String rechnungsstellung;
  final double? latitude;
  final double? longitude;
  final DateTime? ferienStart;
  final DateTime? ferienEnde;
  final DateTime? ferien2Start;
  final DateTime? ferien2Ende;
  final DateTime? ferien3Start;
  final DateTime? ferien3Ende;
  final bool keineBetriebsferien;
  final String? oeffnungMorgenVon;
  final String? oeffnungMorgenBis;
  final String? oeffnungNachmittagVon;
  final String? oeffnungNachmittagBis;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Betrieb({
    required this.id,
    required this.userId,
    required this.name,
    this.strasse,
    this.nr,
    this.plz,
    this.ort,
    this.telefon,
    this.regionId,
    this.email,
    this.website,
    this.zugangNotizen,
    this.betriebNr,
    this.status = 'aktiv',
    this.istMeinKunde = true,
    this.istBergkunde = false,
    this.istSaisonbetrieb = false,
    this.winterSaisonAktiv = false,
    this.winterStartDatum,
    this.winterEndeDatum,
    this.sommerSaisonAktiv = false,
    this.sommerStartDatum,
    this.sommerEndeDatum,
    this.ruhetage = const [],
    this.zapfsysteme = const [],
    this.rechnungsstellung = 'rechnung_mail',
    this.latitude,
    this.longitude,
    this.ferienStart,
    this.ferienEnde,
    this.ferien2Start,
    this.ferien2Ende,
    this.ferien3Start,
    this.ferien3Ende,
    this.keineBetriebsferien = false,
    this.oeffnungMorgenVon,
    this.oeffnungMorgenBis,
    this.oeffnungNachmittagVon,
    this.oeffnungNachmittagBis,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory Betrieb.fromJson(Map<String, dynamic> json) {
    return Betrieb(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      strasse: json['strasse'],
      nr: json['nr'],
      plz: json['plz'],
      ort: json['ort'],
      telefon: json['telefon'],
      regionId: json['region_id'],
      email: json['email'],
      website: json['website'],
      zugangNotizen: json['zugang_notizen'],
      betriebNr: json['heineken_nr'],
      status: json['status'] ?? 'aktiv',
      istMeinKunde: json['ist_mein_kunde'] ?? true,
      istBergkunde: json['ist_bergkunde'] ?? false,
      istSaisonbetrieb: json['ist_saisonbetrieb'] ?? false,
      winterSaisonAktiv: json['winter_saison_aktiv'] ?? false,
      winterStartDatum: json['winter_start_datum'] != null ? DateTime.parse(json['winter_start_datum']) : null,
      winterEndeDatum: json['winter_ende_datum'] != null ? DateTime.parse(json['winter_ende_datum']) : null,
      sommerSaisonAktiv: json['sommer_saison_aktiv'] ?? false,
      sommerStartDatum: json['sommer_start_datum'] != null ? DateTime.parse(json['sommer_start_datum']) : null,
      sommerEndeDatum: json['sommer_ende_datum'] != null ? DateTime.parse(json['sommer_ende_datum']) : null,
      ruhetage: json['ruhetage'] != null
          ? List<String>.from(json['ruhetage'])
          : [],
      zapfsysteme: json['zapfsysteme'] != null
          ? List<String>.from(json['zapfsysteme'])
          : [],
      rechnungsstellung: json['rechnungsstellung'] ?? 'rechnung_mail',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      ferienStart: json['ferien_start'] != null ? DateTime.parse(json['ferien_start']) : null,
      ferienEnde: json['ferien_ende'] != null ? DateTime.parse(json['ferien_ende']) : null,
      ferien2Start: json['ferien2_start'] != null ? DateTime.parse(json['ferien2_start']) : null,
      ferien2Ende: json['ferien2_ende'] != null ? DateTime.parse(json['ferien2_ende']) : null,
      ferien3Start: json['ferien3_start'] != null ? DateTime.parse(json['ferien3_start']) : null,
      ferien3Ende: json['ferien3_ende'] != null ? DateTime.parse(json['ferien3_ende']) : null,
      keineBetriebsferien: json['keine_betriebsferien'] ?? false,
      oeffnungMorgenVon: json['oeffnung_morgen_von'],
      oeffnungMorgenBis: json['oeffnung_morgen_bis'],
      oeffnungNachmittagVon: json['oeffnung_nachmittag_von'],
      oeffnungNachmittagBis: json['oeffnung_nachmittag_bis'],
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'strasse': strasse,
      'nr': nr,
      'plz': plz,
      'ort': ort,
      'telefon': telefon,
      'region_id': regionId,
      'email': email,
      'website': website,
      'zugang_notizen': zugangNotizen,
      'heineken_nr': betriebNr,
      'status': status,
      'ist_mein_kunde': istMeinKunde,
      'ist_bergkunde': istBergkunde,
      'ist_saisonbetrieb': istSaisonbetrieb,
      'winter_saison_aktiv': winterSaisonAktiv,
      'winter_start_datum': winterStartDatum?.toIso8601String().split('T').first,
      'winter_ende_datum': winterEndeDatum?.toIso8601String().split('T').first,
      'sommer_saison_aktiv': sommerSaisonAktiv,
      'sommer_start_datum': sommerStartDatum?.toIso8601String().split('T').first,
      'sommer_ende_datum': sommerEndeDatum?.toIso8601String().split('T').first,
      'ruhetage': ruhetage,
      'zapfsysteme': zapfsysteme,
      'rechnungsstellung': rechnungsstellung,
      'latitude': latitude,
      'longitude': longitude,
      'ferien_start': ferienStart?.toIso8601String().split('T').first,
      'ferien_ende': ferienEnde?.toIso8601String().split('T').first,
      'ferien2_start': ferien2Start?.toIso8601String().split('T').first,
      'ferien2_ende': ferien2Ende?.toIso8601String().split('T').first,
      'ferien3_start': ferien3Start?.toIso8601String().split('T').first,
      'ferien3_ende': ferien3Ende?.toIso8601String().split('T').first,
      'keine_betriebsferien': keineBetriebsferien,
      'oeffnung_morgen_von': oeffnungMorgenVon,
      'oeffnung_morgen_bis': oeffnungMorgenBis,
      'oeffnung_nachmittag_von': oeffnungNachmittagVon,
      'oeffnung_nachmittag_bis': oeffnungNachmittagBis,
      'notizen': notizen,
    };
  }

  String get vollstaendigeAdresse {
    final parts = [strasse, nr, plz, ort].where((p) => p != null && p.isNotEmpty);
    return parts.join(', ');
  }
}
