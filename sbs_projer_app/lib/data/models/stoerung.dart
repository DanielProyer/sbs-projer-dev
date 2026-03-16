class Stoerung {
  final String id;
  final String userId;
  final String? anlageId;
  final String? betriebId;
  final String stoerungsnummer;
  final String? referenzNr;
  final DateTime datum;
  final String? uhrzeitStart;
  final String? uhrzeitEnde;
  final int? dauerMinuten;
  final String? anlageTyp;
  final String problemBeschreibung;
  final String? loesungBeschreibung;
  final bool istPikettEinsatz;
  final String status;
  final int? stoerungBereich;
  final String? preislisteId;
  final bool istBergkunde;
  final int anfahrtKm;
  final bool istWochenende;
  final double? komplexitaetZuschlag;
  final double? preisBasis;
  final double? preisAnfahrt;
  final double? preisWochenende;
  final double? preisNetto;
  final double? mwstSatz;
  final double? preisMwst;
  final double? preisBrutto;
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
  final DateTime? abrechnungsMonat;
  final bool abgerechnet;
  final String? notizen;
  final bool istSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Stoerung({
    required this.id,
    required this.userId,
    this.anlageId,
    this.betriebId,
    required this.stoerungsnummer,
    this.referenzNr,
    required this.datum,
    this.uhrzeitStart,
    this.uhrzeitEnde,
    this.dauerMinuten,
    this.anlageTyp,
    required this.problemBeschreibung,
    this.loesungBeschreibung,
    this.istPikettEinsatz = false,
    this.status = 'offen',
    this.stoerungBereich,
    this.preislisteId,
    this.istBergkunde = false,
    this.anfahrtKm = 0,
    this.istWochenende = false,
    this.komplexitaetZuschlag,
    this.preisBasis,
    this.preisAnfahrt,
    this.preisWochenende,
    this.preisNetto,
    this.mwstSatz,
    this.preisMwst,
    this.preisBrutto,
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
    this.abrechnungsMonat,
    this.abgerechnet = false,
    this.notizen,
    this.istSynced = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Stoerung.fromJson(Map<String, dynamic> json) {
    return Stoerung(
      id: json['id'],
      userId: json['user_id'],
      anlageId: json['anlage_id'],
      betriebId: json['betrieb_id'],
      stoerungsnummer: json['stoerungsnummer'],
      referenzNr: json['referenz_nr'],
      datum: DateTime.parse(json['datum']),
      uhrzeitStart: json['uhrzeit_start'],
      uhrzeitEnde: json['uhrzeit_ende'],
      dauerMinuten: json['dauer_minuten'],
      anlageTyp: json['anlage_typ'],
      problemBeschreibung: json['problem_beschreibung'],
      loesungBeschreibung: json['loesung_beschreibung'],
      istPikettEinsatz: json['ist_pikett_einsatz'] ?? false,
      status: json['status'] ?? 'offen',
      stoerungBereich: json['stoerung_bereich'],
      preislisteId: json['preisliste_id'],
      istBergkunde: json['ist_bergkunde'] ?? false,
      anfahrtKm: json['anfahrt_km'] ?? 0,
      istWochenende: json['ist_wochenende'] ?? false,
      komplexitaetZuschlag: _toDouble(json['komplexitaet_zuschlag']),
      preisBasis: _toDouble(json['preis_basis']),
      preisAnfahrt: _toDouble(json['preis_anfahrt']),
      preisWochenende: _toDouble(json['preis_wochenende']),
      preisNetto: _toDouble(json['preis_netto']),
      mwstSatz: _toDouble(json['mwst_satz']),
      preisMwst: _toDouble(json['preis_mwst']),
      preisBrutto: _toDouble(json['preis_brutto']),
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
      abrechnungsMonat: json['abrechnungs_monat'] != null
          ? DateTime.parse(json['abrechnungs_monat'])
          : null,
      abgerechnet: json['abgerechnet'] ?? false,
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
      'uhrzeit_start': uhrzeitStart,
      'uhrzeit_ende': uhrzeitEnde,
      'anlage_typ': anlageTyp,
      'problem_beschreibung': problemBeschreibung,
      'loesung_beschreibung': loesungBeschreibung,
      'ist_pikett_einsatz': istPikettEinsatz,
      'status': status,
      'stoerung_bereich': stoerungBereich,
      'preisliste_id': preislisteId,
      'ist_bergkunde': istBergkunde,
      'anfahrt_km': anfahrtKm,
      'ist_wochenende': istWochenende,
      'komplexitaet_zuschlag': komplexitaetZuschlag,
      'preis_basis': preisBasis,
      'preis_anfahrt': preisAnfahrt,
      'preis_wochenende': preisWochenende,
      'preis_netto': preisNetto,
      'mwst_satz': mwstSatz,
      'preis_mwst': preisMwst,
      'preis_brutto': preisBrutto,
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
      'abrechnungs_monat': abrechnungsMonat?.toIso8601String().split('T').first,
      'abgerechnet': abgerechnet,
      'notizen': notizen,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}
