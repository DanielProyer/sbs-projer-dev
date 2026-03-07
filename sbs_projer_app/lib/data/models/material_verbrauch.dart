class MaterialVerbrauch {
  final String id;
  final String userId;
  final String lagerId;
  final String serviceTyp;
  final String serviceId;
  final double menge;
  final String einheit;
  final double? preisEinkauf;
  final DateTime? verbrauchtAm;
  final String? notizen;
  final DateTime? createdAt;

  MaterialVerbrauch({
    required this.id,
    required this.userId,
    required this.lagerId,
    required this.serviceTyp,
    required this.serviceId,
    required this.menge,
    required this.einheit,
    this.preisEinkauf,
    this.verbrauchtAm,
    this.notizen,
    this.createdAt,
  });

  factory MaterialVerbrauch.fromJson(Map<String, dynamic> json) {
    return MaterialVerbrauch(
      id: json['id'],
      userId: json['user_id'],
      lagerId: json['lager_id'],
      serviceTyp: json['service_typ'],
      serviceId: json['service_id'],
      menge: double.tryParse(json['menge'].toString()) ?? 0,
      einheit: json['einheit'],
      preisEinkauf: json['preis_einkauf'] != null
          ? double.tryParse(json['preis_einkauf'].toString())
          : null,
      verbrauchtAm: json['verbraucht_am'] != null
          ? DateTime.parse(json['verbraucht_am'])
          : null,
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'lager_id': lagerId,
      'service_typ': serviceTyp,
      'service_id': serviceId,
      'menge': menge,
      'einheit': einheit,
      'preis_einkauf': preisEinkauf,
      'notizen': notizen,
    };
  }
}
