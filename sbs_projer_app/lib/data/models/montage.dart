class Montage {
  final String id;
  final String userId;
  final String? anlageId;
  final String betriebId;
  final String montageTyp;
  final String beschreibung;
  final String? referenzNr;
  final DateTime datum;
  final String? uhrzeitStart;
  final String? uhrzeitEnde;
  final int? dauerMinuten;
  final String status;
  final String? preislisteId;
  final double? stundensatz;
  final double? dauerStunden;
  final double? kostenArbeit;
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
  final String? material6Id;
  final double? material6Menge;
  final String? material7Id;
  final double? material7Menge;
  final String? notizen;
  final bool istSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Montage({
    required this.id,
    required this.userId,
    this.anlageId,
    required this.betriebId,
    required this.montageTyp,
    required this.beschreibung,
    this.referenzNr,
    required this.datum,
    this.uhrzeitStart,
    this.uhrzeitEnde,
    this.dauerMinuten,
    this.status = 'geplant',
    this.preislisteId,
    this.stundensatz,
    this.dauerStunden,
    this.kostenArbeit,
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
    this.material6Id,
    this.material6Menge,
    this.material7Id,
    this.material7Menge,
    this.notizen,
    this.istSynced = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Montage.fromJson(Map<String, dynamic> json) {
    return Montage(
      id: json['id'],
      userId: json['user_id'],
      anlageId: json['anlage_id'],
      betriebId: json['betrieb_id'],
      montageTyp: json['montage_typ'],
      beschreibung: json['beschreibung'],
      referenzNr: json['referenz_nr'],
      datum: DateTime.parse(json['datum']),
      uhrzeitStart: json['uhrzeit_start'],
      uhrzeitEnde: json['uhrzeit_ende'],
      dauerMinuten: json['dauer_minuten'],
      status: json['status'] ?? 'geplant',
      preislisteId: json['preisliste_id'],
      stundensatz: _toDouble(json['stundensatz']),
      dauerStunden: _toDouble(json['dauer_stunden']),
      kostenArbeit: _toDouble(json['kosten_arbeit']),
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
      material6Id: json['material_6_id'],
      material6Menge: _toDouble(json['material_6_menge']),
      material7Id: json['material_7_id'],
      material7Menge: _toDouble(json['material_7_menge']),
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
      'montage_typ': montageTyp,
      'beschreibung': beschreibung,
      'referenz_nr': referenzNr,
      'datum': datum.toIso8601String().split('T').first,
      'uhrzeit_start': uhrzeitStart,
      'uhrzeit_ende': uhrzeitEnde,
      'status': status,
      'preisliste_id': preislisteId,
      'stundensatz': stundensatz,
      'dauer_stunden': dauerStunden,
      'kosten_arbeit': kostenArbeit,
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
      'material_6_id': material6Id,
      'material_6_menge': material6Menge,
      'material_7_id': material7Id,
      'material_7_menge': material7Menge,
      'notizen': notizen,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}
