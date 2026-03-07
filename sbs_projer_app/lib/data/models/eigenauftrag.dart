class Eigenauftrag {
  final String id;
  final String userId;
  final String anlageId;
  final String betriebId;
  final String stoerungsnummer;
  final String? referenzNr;
  final DateTime datum;
  final String? uhrzeit;
  final String? entdecktBeiServiceId;
  final String problemBeschreibung;
  final String? loesungBeschreibung;
  final String status;
  final String? preislisteId;
  final double? pauschale;
  final DateTime? abrechnungsMonat;
  final bool abgerechnet;
  final String? material1Id;
  final double? material1Menge;
  final String? material2Id;
  final double? material2Menge;
  final String? material3Id;
  final double? material3Menge;
  final String? material4Id;
  final double? material4Menge;
  final String? material5Id;
  final double? material5Menge;
  final String? notizen;
  final bool istSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Eigenauftrag({
    required this.id,
    required this.userId,
    required this.anlageId,
    required this.betriebId,
    required this.stoerungsnummer,
    this.referenzNr,
    required this.datum,
    this.uhrzeit,
    this.entdecktBeiServiceId,
    required this.problemBeschreibung,
    this.loesungBeschreibung,
    this.status = 'behoben',
    this.preislisteId,
    this.pauschale,
    this.abrechnungsMonat,
    this.abgerechnet = false,
    this.material1Id,
    this.material1Menge,
    this.material2Id,
    this.material2Menge,
    this.material3Id,
    this.material3Menge,
    this.material4Id,
    this.material4Menge,
    this.material5Id,
    this.material5Menge,
    this.notizen,
    this.istSynced = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Eigenauftrag.fromJson(Map<String, dynamic> json) {
    return Eigenauftrag(
      id: json['id'],
      userId: json['user_id'],
      anlageId: json['anlage_id'],
      betriebId: json['betrieb_id'],
      stoerungsnummer: json['stoerungsnummer'],
      referenzNr: json['referenz_nr'],
      datum: DateTime.parse(json['datum']),
      uhrzeit: json['uhrzeit'],
      entdecktBeiServiceId: json['entdeckt_bei_service_id'],
      problemBeschreibung: json['problem_beschreibung'],
      loesungBeschreibung: json['loesung_beschreibung'],
      status: json['status'] ?? 'behoben',
      preislisteId: json['preisliste_id'],
      pauschale: _toDouble(json['pauschale']),
      abrechnungsMonat: json['abrechnungs_monat'] != null
          ? DateTime.parse(json['abrechnungs_monat'])
          : null,
      abgerechnet: json['abgerechnet'] ?? false,
      material1Id: json['material_1_id'],
      material1Menge: _toDouble(json['material_1_menge']),
      material2Id: json['material_2_id'],
      material2Menge: _toDouble(json['material_2_menge']),
      material3Id: json['material_3_id'],
      material3Menge: _toDouble(json['material_3_menge']),
      material4Id: json['material_4_id'],
      material4Menge: _toDouble(json['material_4_menge']),
      material5Id: json['material_5_id'],
      material5Menge: _toDouble(json['material_5_menge']),
      notizen: json['notizen'],
      istSynced: json['ist_synced'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'anlage_id': anlageId,
      'betrieb_id': betriebId,
      'stoerungsnummer': stoerungsnummer,
      'referenz_nr': referenzNr,
      'datum': datum.toIso8601String().split('T').first,
      'uhrzeit': uhrzeit,
      'entdeckt_bei_service_id': entdecktBeiServiceId,
      'problem_beschreibung': problemBeschreibung,
      'loesung_beschreibung': loesungBeschreibung,
      'status': status,
      'preisliste_id': preislisteId,
      'pauschale': pauschale,
      'abrechnungs_monat': abrechnungsMonat?.toIso8601String().split('T').first,
      'abgerechnet': abgerechnet,
      'material_1_id': material1Id,
      'material_1_menge': material1Menge,
      'material_2_id': material2Id,
      'material_2_menge': material2Menge,
      'material_3_id': material3Id,
      'material_3_menge': material3Menge,
      'material_4_id': material4Id,
      'material_4_menge': material4Menge,
      'material_5_id': material5Id,
      'material_5_menge': material5Menge,
      'notizen': notizen,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}
