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

  /// Dekorsäule mit Eismantel. Kein Kühler — muss aber wie der Booster vor dem
  /// Service ausgeschaltet werden, sonst friert Wasser oder Lauge in der
  /// Leitung.
  final bool eissaeule;
  final String vorkuehler;
  final String? durchlaufkuehler;
  final DateTime? letzterWasserwechsel;
  final String? gasTyp1;
  final String? gasTyp2;
  final double? hauptdruckBar;
  final bool hatNiederdruck;
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
    this.eissaeule = false,
    this.vorkuehler = 'keiner',
    this.durchlaufkuehler,
    this.letzterWasserwechsel,
    this.gasTyp1,
    this.gasTyp2,
    this.hauptdruckBar,
    this.hatNiederdruck = false,
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
      eissaeule: json['eissaeule'] ?? false,
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
      'eissaeule': eissaeule,
      'vorkuehler': vorkuehler,
      'durchlaufkuehler': durchlaufkuehler,
      'letzter_wasserwechsel': letzterWasserwechsel?.toIso8601String(),
      'gas_typ_1': gasTyp1,
      'gas_typ_2': gasTyp2,
      'hauptdruck_bar': hauptdruckBar,
      'hat_niederdruck': hatNiederdruck,
      'reinigung_rhythmus': reinigungRhythmus,
      'status': status,
      'notizen': notizen,
    };
  }
}
