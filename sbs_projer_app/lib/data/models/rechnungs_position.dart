class RechnungsPosition {
  final String id;
  final String userId;
  final String rechnungId;
  final String? serviceTyp;
  final String? serviceId;
  final int position;
  final String beschreibung;
  final double betragNetto;
  final double mwstSatz;
  final double mwstBetrag;
  final double betragBrutto;
  final DateTime? createdAt;

  RechnungsPosition({
    required this.id,
    required this.userId,
    required this.rechnungId,
    this.serviceTyp,
    this.serviceId,
    required this.position,
    required this.beschreibung,
    required this.betragNetto,
    this.mwstSatz = 8.10,
    required this.mwstBetrag,
    required this.betragBrutto,
    this.createdAt,
  });

  factory RechnungsPosition.fromJson(Map<String, dynamic> json) {
    return RechnungsPosition(
      id: json['id'],
      userId: json['user_id'],
      rechnungId: json['rechnung_id'],
      serviceTyp: json['service_typ'],
      serviceId: json['service_id'],
      position: json['position'],
      beschreibung: json['beschreibung'],
      betragNetto: _d(json['betrag_netto']),
      mwstSatz: _d(json['mwst_satz']),
      mwstBetrag: _d(json['mwst_betrag']),
      betragBrutto: _d(json['betrag_brutto']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'rechnung_id': rechnungId,
      'service_typ': serviceTyp,
      'service_id': serviceId,
      'position': position,
      'beschreibung': beschreibung,
      'betrag_netto': betragNetto,
      'mwst_satz': mwstSatz,
      'mwst_betrag': mwstBetrag,
      'betrag_brutto': betragBrutto,
    };
  }

  static double _d(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }
}
