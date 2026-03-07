class Anlage {
  final String id;
  final String userId;
  final String betriebId;
  final String? bezeichnung;
  final String? seriennummer;
  final String typAnlage;
  final String? typSaeule;
  final int anzahlHaehne;
  final bool backpython;
  final bool booster;
  final String vorkuehler;
  final String? durchlaufkuehler;
  final DateTime? letzterWasserwechsel;
  final String? gasTyp1;
  final String? gasTyp2;
  final double? hauptdruckBar;
  final bool hatNiederdruck;
  final String? servicezeitMorgenAb;
  final String? servicezeitMorgenBis;
  final String? servicezeitNachmittagAb;
  final String? servicezeitNachmittagBis;
  final String reinigungRhythmus;
  final DateTime? letzteReinigung;
  final DateTime? naechsteReinigung;
  final String status;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Anlage({
    required this.id,
    required this.userId,
    required this.betriebId,
    this.bezeichnung,
    this.seriennummer,
    required this.typAnlage,
    this.typSaeule,
    this.anzahlHaehne = 1,
    this.backpython = false,
    this.booster = false,
    this.vorkuehler = 'keiner',
    this.durchlaufkuehler,
    this.letzterWasserwechsel,
    this.gasTyp1,
    this.gasTyp2,
    this.hauptdruckBar,
    this.hatNiederdruck = false,
    this.servicezeitMorgenAb,
    this.servicezeitMorgenBis,
    this.servicezeitNachmittagAb,
    this.servicezeitNachmittagBis,
    this.reinigungRhythmus = '4-Wochen',
    this.letzteReinigung,
    this.naechsteReinigung,
    this.status = 'aktiv',
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory Anlage.fromJson(Map<String, dynamic> json) {
    return Anlage(
      id: json['id'],
      userId: json['user_id'],
      betriebId: json['betrieb_id'],
      bezeichnung: json['bezeichnung'],
      seriennummer: json['seriennummer'],
      typAnlage: json['typ_anlage'],
      typSaeule: json['typ_saeule'],
      anzahlHaehne: json['anzahl_haehne'] ?? 1,
      backpython: json['backpython'] ?? false,
      booster: json['booster'] ?? false,
      vorkuehler: json['vorkuehler'] ?? 'keiner',
      durchlaufkuehler: json['durchlaufkuehler'],
      letzterWasserwechsel: json['letzter_wasserwechsel'] != null
          ? DateTime.parse(json['letzter_wasserwechsel'])
          : null,
      gasTyp1: json['gas_typ_1'],
      gasTyp2: json['gas_typ_2'],
      hauptdruckBar: json['hauptdruck_bar'] != null
          ? double.tryParse(json['hauptdruck_bar'].toString())
          : null,
      hatNiederdruck: json['hat_niederdruck'] ?? false,
      servicezeitMorgenAb: json['servicezeit_morgen_ab'],
      servicezeitMorgenBis: json['servicezeit_morgen_bis'],
      servicezeitNachmittagAb: json['servicezeit_nachmittag_ab'],
      servicezeitNachmittagBis: json['servicezeit_nachmittag_bis'],
      reinigungRhythmus: json['reinigung_rhythmus'] ?? '4-Wochen',
      letzteReinigung: json['letzte_reinigung'] != null
          ? DateTime.parse(json['letzte_reinigung'])
          : null,
      naechsteReinigung: json['naechste_reinigung'] != null
          ? DateTime.parse(json['naechste_reinigung'])
          : null,
      status: json['status'] ?? 'aktiv',
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'betrieb_id': betriebId,
      'bezeichnung': bezeichnung,
      'seriennummer': seriennummer,
      'typ_anlage': typAnlage,
      'typ_saeule': typSaeule,
      'anzahl_haehne': anzahlHaehne,
      'backpython': backpython,
      'booster': booster,
      'vorkuehler': vorkuehler,
      'durchlaufkuehler': durchlaufkuehler,
      'letzter_wasserwechsel': letzterWasserwechsel?.toIso8601String(),
      'gas_typ_1': gasTyp1,
      'gas_typ_2': gasTyp2,
      'hauptdruck_bar': hauptdruckBar,
      'hat_niederdruck': hatNiederdruck,
      'servicezeit_morgen_ab': servicezeitMorgenAb,
      'servicezeit_morgen_bis': servicezeitMorgenBis,
      'servicezeit_nachmittag_ab': servicezeitNachmittagAb,
      'servicezeit_nachmittag_bis': servicezeitNachmittagBis,
      'reinigung_rhythmus': reinigungRhythmus,
      'status': status,
      'notizen': notizen,
    };
  }
}
