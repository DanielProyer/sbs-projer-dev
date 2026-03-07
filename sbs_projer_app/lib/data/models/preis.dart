class Preis {
  final String id;
  final String userId;
  final DateTime gueltigAb;
  final DateTime? gueltigBis;
  final double mwstSatz;
  final double bergkundenZuschlag;
  final double grundtarifReinigungBier;
  final double grundtarifReinigungOrion;
  final double grundtarifHeigenie;
  final double grundtarifReinigungFremd;
  final double grundtarifWein;
  final double zusatzHahnEigen;
  final double zusatzHahnOrion;
  final double zusatzHahnFremd;
  final double zusatzHahnWein;
  final double zusatzHahnAndererStandort;
  final double eigenauftragPauschale;
  final double montageStundensatz;
  final double pikettPauschale;
  final double pikettFeiertagZuschlag;
  final double eroeffnungPreisNormal;
  final double eroeffnungPreisBergkunde;
  final double stoerung1Normal;
  final double stoerung1Bergkunde;
  final double stoerung2Normal;
  final double stoerung2Bergkunde;
  final double stoerung3Normal;
  final double stoerung3Bergkunde;
  final double stoerung4Normal;
  final double stoerung4Bergkunde;
  final double stoerung5Normal;
  final double stoerung5Bergkunde;
  final double stoerungAnfahrtPauschale;
  final int stoerungAnfahrtKmGrenze;
  final double stoerungAnfahrtKmSatz;
  final double stoerungWochenendeZuschlag;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Preis({
    required this.id,
    required this.userId,
    required this.gueltigAb,
    this.gueltigBis,
    this.mwstSatz = 8.10,
    this.bergkundenZuschlag = 180.00,
    required this.grundtarifReinigungBier,
    required this.grundtarifReinigungOrion,
    required this.grundtarifHeigenie,
    required this.grundtarifReinigungFremd,
    required this.grundtarifWein,
    required this.zusatzHahnEigen,
    required this.zusatzHahnOrion,
    required this.zusatzHahnFremd,
    required this.zusatzHahnWein,
    required this.zusatzHahnAndererStandort,
    this.eigenauftragPauschale = 30.00,
    required this.montageStundensatz,
    this.pikettPauschale = 160.00,
    this.pikettFeiertagZuschlag = 80.00,
    this.eroeffnungPreisNormal = 60.00,
    this.eroeffnungPreisBergkunde = 135.00,
    this.stoerung1Normal = 55.00,
    this.stoerung1Bergkunde = 130.00,
    this.stoerung2Normal = 55.00,
    this.stoerung2Bergkunde = 130.00,
    this.stoerung3Normal = 90.00,
    this.stoerung3Bergkunde = 165.00,
    this.stoerung4Normal = 45.00,
    this.stoerung4Bergkunde = 120.00,
    this.stoerung5Normal = 45.00,
    this.stoerung5Bergkunde = 120.00,
    this.stoerungAnfahrtPauschale = 60.00,
    this.stoerungAnfahrtKmGrenze = 80,
    this.stoerungAnfahrtKmSatz = 0.720,
    this.stoerungWochenendeZuschlag = 100.00,
    this.createdAt,
    this.updatedAt,
  });

  factory Preis.fromJson(Map<String, dynamic> json) {
    return Preis(
      id: json['id'],
      userId: json['user_id'],
      gueltigAb: DateTime.parse(json['gueltig_ab']),
      gueltigBis: json['gueltig_bis'] != null ? DateTime.parse(json['gueltig_bis']) : null,
      mwstSatz: _d(json['mwst_satz'], 8.10),
      bergkundenZuschlag: _d(json['bergkunden_zuschlag'], 180.00),
      grundtarifReinigungBier: _d(json['grundtarif_reinigung_bier'], 0),
      grundtarifReinigungOrion: _d(json['grundtarif_reinigung_orion'], 0),
      grundtarifHeigenie: _d(json['grundtarif_heigenie'], 0),
      grundtarifReinigungFremd: _d(json['grundtarif_reinigung_fremd'], 0),
      grundtarifWein: _d(json['grundtarif_wein'], 0),
      zusatzHahnEigen: _d(json['zusatz_hahn_eigen'], 0),
      zusatzHahnOrion: _d(json['zusatz_hahn_orion'], 0),
      zusatzHahnFremd: _d(json['zusatz_hahn_fremd'], 0),
      zusatzHahnWein: _d(json['zusatz_hahn_wein'], 0),
      zusatzHahnAndererStandort: _d(json['zusatz_hahn_anderer_standort'], 0),
      eigenauftragPauschale: _d(json['eigenauftrag_pauschale'], 30.00),
      montageStundensatz: _d(json['montage_stundensatz'], 0),
      pikettPauschale: _d(json['pikett_pauschale'], 160.00),
      pikettFeiertagZuschlag: _d(json['pikett_feiertag_zuschlag'], 80.00),
      eroeffnungPreisNormal: _d(json['eroeffnung_preis_normal'], 60.00),
      eroeffnungPreisBergkunde: _d(json['eroeffnung_preis_bergkunde'], 135.00),
      stoerung1Normal: _d(json['stoerung_1_normal'], 55.00),
      stoerung1Bergkunde: _d(json['stoerung_1_bergkunde'], 130.00),
      stoerung2Normal: _d(json['stoerung_2_normal'], 55.00),
      stoerung2Bergkunde: _d(json['stoerung_2_bergkunde'], 130.00),
      stoerung3Normal: _d(json['stoerung_3_normal'], 90.00),
      stoerung3Bergkunde: _d(json['stoerung_3_bergkunde'], 165.00),
      stoerung4Normal: _d(json['stoerung_4_normal'], 45.00),
      stoerung4Bergkunde: _d(json['stoerung_4_bergkunde'], 120.00),
      stoerung5Normal: _d(json['stoerung_5_normal'], 45.00),
      stoerung5Bergkunde: _d(json['stoerung_5_bergkunde'], 120.00),
      stoerungAnfahrtPauschale: _d(json['stoerung_anfahrt_pauschale'], 60.00),
      stoerungAnfahrtKmGrenze: json['stoerung_anfahrt_km_grenze'] ?? 80,
      stoerungAnfahrtKmSatz: _d(json['stoerung_anfahrt_km_satz'], 0.720),
      stoerungWochenendeZuschlag: _d(json['stoerung_wochenende_zuschlag'], 100.00),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'gueltig_ab': gueltigAb.toIso8601String().split('T').first,
      'gueltig_bis': gueltigBis?.toIso8601String().split('T').first,
      'mwst_satz': mwstSatz,
      'bergkunden_zuschlag': bergkundenZuschlag,
      'grundtarif_reinigung_bier': grundtarifReinigungBier,
      'grundtarif_reinigung_orion': grundtarifReinigungOrion,
      'grundtarif_heigenie': grundtarifHeigenie,
      'grundtarif_reinigung_fremd': grundtarifReinigungFremd,
      'grundtarif_wein': grundtarifWein,
      'zusatz_hahn_eigen': zusatzHahnEigen,
      'zusatz_hahn_orion': zusatzHahnOrion,
      'zusatz_hahn_fremd': zusatzHahnFremd,
      'zusatz_hahn_wein': zusatzHahnWein,
      'zusatz_hahn_anderer_standort': zusatzHahnAndererStandort,
      'eigenauftrag_pauschale': eigenauftragPauschale,
      'montage_stundensatz': montageStundensatz,
      'pikett_pauschale': pikettPauschale,
      'pikett_feiertag_zuschlag': pikettFeiertagZuschlag,
      'eroeffnung_preis_normal': eroeffnungPreisNormal,
      'eroeffnung_preis_bergkunde': eroeffnungPreisBergkunde,
      'stoerung_1_normal': stoerung1Normal,
      'stoerung_1_bergkunde': stoerung1Bergkunde,
      'stoerung_2_normal': stoerung2Normal,
      'stoerung_2_bergkunde': stoerung2Bergkunde,
      'stoerung_3_normal': stoerung3Normal,
      'stoerung_3_bergkunde': stoerung3Bergkunde,
      'stoerung_4_normal': stoerung4Normal,
      'stoerung_4_bergkunde': stoerung4Bergkunde,
      'stoerung_5_normal': stoerung5Normal,
      'stoerung_5_bergkunde': stoerung5Bergkunde,
      'stoerung_anfahrt_pauschale': stoerungAnfahrtPauschale,
      'stoerung_anfahrt_km_grenze': stoerungAnfahrtKmGrenze,
      'stoerung_anfahrt_km_satz': stoerungAnfahrtKmSatz,
      'stoerung_wochenende_zuschlag': stoerungWochenendeZuschlag,
    };
  }

  static double _d(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    return double.tryParse(value.toString()) ?? defaultValue;
  }
}
