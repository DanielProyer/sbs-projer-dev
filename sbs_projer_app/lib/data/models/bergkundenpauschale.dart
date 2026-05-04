class Bergkundenpauschale {
  final String id;
  final String userId;
  final String betriebId;
  final String? reinigungId;
  final DateTime datum;
  final double betrag;
  final String? notizen;
  final bool abgerechnet;
  final DateTime? abrechnungsMonat;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Bergkundenpauschale({
    required this.id,
    required this.userId,
    required this.betriebId,
    this.reinigungId,
    required this.datum,
    this.betrag = 180.0,
    this.notizen,
    this.abgerechnet = false,
    this.abrechnungsMonat,
    this.createdAt,
    this.updatedAt,
  });

  factory Bergkundenpauschale.fromJson(Map<String, dynamic> json) {
    return Bergkundenpauschale(
      id: json['id'],
      userId: json['user_id'],
      betriebId: json['betrieb_id'],
      reinigungId: json['reinigung_id'],
      datum: DateTime.parse(json['datum']),
      betrag: _d(json['betrag'], 180.0),
      notizen: json['notizen'],
      abgerechnet: json['abgerechnet'] ?? false,
      abrechnungsMonat: json['abrechnungs_monat'] != null
          ? DateTime.parse(json['abrechnungs_monat'])
          : null,
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
      'id': id,
      'user_id': userId,
      'betrieb_id': betriebId,
      'reinigung_id': reinigungId,
      'datum': datum.toIso8601String().split('T').first,
      'betrag': betrag,
      'notizen': notizen,
      'abgerechnet': abgerechnet,
      'abrechnungs_monat':
          abrechnungsMonat?.toIso8601String().split('T').first,
    };
  }

  static double _d(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    return double.tryParse(value.toString()) ?? defaultValue;
  }
}
