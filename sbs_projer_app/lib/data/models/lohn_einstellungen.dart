class LohnEinstellungen {
  final String id;
  final String userId;
  final int jahr;
  final double bruttolohnMonatlich;
  final int geburtsjahr;
  // AHV/IV/EO
  final double ahvIvEoAnSatz;
  final double ahvIvEoAgSatz;
  // ALV
  final double alvAnSatz;
  final double alvAgSatz;
  // NBU (100% AN)
  final double nbuAnSatz;
  // BU (100% AG)
  final double buAgSatz;
  // BVG (Fixbeträge)
  final double bvgAnBetrag;
  final double bvgAgBetrag;
  // FAK (100% AG)
  final double fakAgSatz;
  // KTG
  final double ktgAnSatz;
  final double ktgAgSatz;
  // Lohnausweis-Daten
  final String? arbeitnehmerName;
  final String? arbeitnehmerVorname;
  final String? arbeitnehmerAdresse;
  final String? arbeitnehmerPlzOrt;
  final String? arbeitnehmerAhvNr;
  final DateTime? arbeitnehmerGeburtsdatum;
  final String? arbeitgeberName;
  final String? arbeitgeberAdresse;
  final String? arbeitgeberPlzOrt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LohnEinstellungen({
    required this.id,
    required this.userId,
    required this.jahr,
    this.bruttolohnMonatlich = 0,
    this.geburtsjahr = 1990,
    this.ahvIvEoAnSatz = 5.30,
    this.ahvIvEoAgSatz = 5.30,
    this.alvAnSatz = 1.10,
    this.alvAgSatz = 1.10,
    this.nbuAnSatz = 1.40,
    this.buAgSatz = 0.70,
    this.bvgAnBetrag = 0,
    this.bvgAgBetrag = 0,
    this.fakAgSatz = 1.35,
    this.ktgAnSatz = 0,
    this.ktgAgSatz = 0,
    this.arbeitnehmerName,
    this.arbeitnehmerVorname,
    this.arbeitnehmerAdresse,
    this.arbeitnehmerPlzOrt,
    this.arbeitnehmerAhvNr,
    this.arbeitnehmerGeburtsdatum,
    this.arbeitgeberName,
    this.arbeitgeberAdresse,
    this.arbeitgeberPlzOrt,
    this.createdAt,
    this.updatedAt,
  });

  factory LohnEinstellungen.fromJson(Map<String, dynamic> json) {
    return LohnEinstellungen(
      id: json['id'],
      userId: json['user_id'],
      jahr: json['jahr'],
      bruttolohnMonatlich: _d(json['bruttolohn_monatlich']),
      geburtsjahr: json['geburtsjahr'] ?? 1990,
      ahvIvEoAnSatz: _d(json['ahv_iv_eo_an_satz']),
      ahvIvEoAgSatz: _d(json['ahv_iv_eo_ag_satz']),
      alvAnSatz: _d(json['alv_an_satz']),
      alvAgSatz: _d(json['alv_ag_satz']),
      nbuAnSatz: _d(json['nbu_an_satz']),
      buAgSatz: _d(json['bu_ag_satz']),
      bvgAnBetrag: _d(json['bvg_an_betrag']),
      bvgAgBetrag: _d(json['bvg_ag_betrag']),
      fakAgSatz: _d(json['fak_ag_satz']),
      ktgAnSatz: _d(json['ktg_an_satz']),
      ktgAgSatz: _d(json['ktg_ag_satz']),
      arbeitnehmerName: json['arbeitnehmer_name'],
      arbeitnehmerVorname: json['arbeitnehmer_vorname'],
      arbeitnehmerAdresse: json['arbeitnehmer_adresse'],
      arbeitnehmerPlzOrt: json['arbeitnehmer_plz_ort'],
      arbeitnehmerAhvNr: json['arbeitnehmer_ahv_nr'],
      arbeitnehmerGeburtsdatum: json['arbeitnehmer_geburtsdatum'] != null
          ? DateTime.parse(json['arbeitnehmer_geburtsdatum'])
          : null,
      arbeitgeberName: json['arbeitgeber_name'],
      arbeitgeberAdresse: json['arbeitgeber_adresse'],
      arbeitgeberPlzOrt: json['arbeitgeber_plz_ort'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'jahr': jahr,
      'bruttolohn_monatlich': bruttolohnMonatlich,
      'geburtsjahr': geburtsjahr,
      'ahv_iv_eo_an_satz': ahvIvEoAnSatz,
      'ahv_iv_eo_ag_satz': ahvIvEoAgSatz,
      'alv_an_satz': alvAnSatz,
      'alv_ag_satz': alvAgSatz,
      'nbu_an_satz': nbuAnSatz,
      'bu_ag_satz': buAgSatz,
      'bvg_an_betrag': bvgAnBetrag,
      'bvg_ag_betrag': bvgAgBetrag,
      'fak_ag_satz': fakAgSatz,
      'ktg_an_satz': ktgAnSatz,
      'ktg_ag_satz': ktgAgSatz,
      'arbeitnehmer_name': arbeitnehmerName,
      'arbeitnehmer_vorname': arbeitnehmerVorname,
      'arbeitnehmer_adresse': arbeitnehmerAdresse,
      'arbeitnehmer_plz_ort': arbeitnehmerPlzOrt,
      'arbeitnehmer_ahv_nr': arbeitnehmerAhvNr,
      'arbeitnehmer_geburtsdatum': arbeitnehmerGeburtsdatum
          ?.toIso8601String()
          .split('T')
          .first,
      'arbeitgeber_name': arbeitgeberName,
      'arbeitgeber_adresse': arbeitgeberAdresse,
      'arbeitgeber_plz_ort': arbeitgeberPlzOrt,
    };
  }

  static double _d(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }
}
