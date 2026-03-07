class Betrieb {
  final String id;
  final String userId;
  final String name;
  final String? strasse;
  final String? nr;
  final String? plz;
  final String? ort;
  final String? regionId;
  final String? email;
  final String? website;
  final String? zugangNotizen;
  final String? heinekenNr;
  final String status;
  final bool istMeinKunde;
  final bool istBergkunde;
  final bool istSaisonbetrieb;
  final bool winterSaisonAktiv;
  final int? winterStartMonat;
  final int? winterEndeMonat;
  final bool sommerSaisonAktiv;
  final int? sommerStartMonat;
  final int? sommerEndeMonat;
  final List<String> ruhetage;
  final String rechnungsstellung;
  final double? latitude;
  final double? longitude;
  final DateTime? ferienStart;
  final DateTime? ferienEnde;
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
    this.regionId,
    this.email,
    this.website,
    this.zugangNotizen,
    this.heinekenNr,
    this.status = 'aktiv',
    this.istMeinKunde = true,
    this.istBergkunde = false,
    this.istSaisonbetrieb = false,
    this.winterSaisonAktiv = false,
    this.winterStartMonat,
    this.winterEndeMonat,
    this.sommerSaisonAktiv = false,
    this.sommerStartMonat,
    this.sommerEndeMonat,
    this.ruhetage = const [],
    this.rechnungsstellung = 'rechnung_mail',
    this.latitude,
    this.longitude,
    this.ferienStart,
    this.ferienEnde,
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
      regionId: json['region_id'],
      email: json['email'],
      website: json['website'],
      zugangNotizen: json['zugang_notizen'],
      heinekenNr: json['heineken_nr'],
      status: json['status'] ?? 'aktiv',
      istMeinKunde: json['ist_mein_kunde'] ?? true,
      istBergkunde: json['ist_bergkunde'] ?? false,
      istSaisonbetrieb: json['ist_saisonbetrieb'] ?? false,
      winterSaisonAktiv: json['winter_saison_aktiv'] ?? false,
      winterStartMonat: json['winter_start_monat'],
      winterEndeMonat: json['winter_ende_monat'],
      sommerSaisonAktiv: json['sommer_saison_aktiv'] ?? false,
      sommerStartMonat: json['sommer_start_monat'],
      sommerEndeMonat: json['sommer_ende_monat'],
      ruhetage: json['ruhetage'] != null
          ? List<String>.from(json['ruhetage'])
          : [],
      rechnungsstellung: json['rechnungsstellung'] ?? 'rechnung_mail',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      ferienStart: json['ferien_start'] != null ? DateTime.parse(json['ferien_start']) : null,
      ferienEnde: json['ferien_ende'] != null ? DateTime.parse(json['ferien_ende']) : null,
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
      'region_id': regionId,
      'email': email,
      'website': website,
      'zugang_notizen': zugangNotizen,
      'heineken_nr': heinekenNr,
      'status': status,
      'ist_mein_kunde': istMeinKunde,
      'ist_bergkunde': istBergkunde,
      'ist_saisonbetrieb': istSaisonbetrieb,
      'winter_saison_aktiv': winterSaisonAktiv,
      'winter_start_monat': winterStartMonat,
      'winter_ende_monat': winterEndeMonat,
      'sommer_saison_aktiv': sommerSaisonAktiv,
      'sommer_start_monat': sommerStartMonat,
      'sommer_ende_monat': sommerEndeMonat,
      'ruhetage': ruhetage,
      'rechnungsstellung': rechnungsstellung,
      'latitude': latitude,
      'longitude': longitude,
      'ferien_start': ferienStart?.toIso8601String().split('T').first,
      'ferien_ende': ferienEnde?.toIso8601String().split('T').first,
      'notizen': notizen,
    };
  }

  String get vollstaendigeAdresse {
    final parts = [strasse, nr, plz, ort].where((p) => p != null && p.isNotEmpty);
    return parts.join(', ');
  }
}
