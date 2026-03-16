class Eroeffnungsreinigung {
  final String id;
  final String userId;
  final String? betriebId;
  final String stoerungsnummer;
  final DateTime datum;
  final bool istBergkunde;
  final double? preis;
  final DateTime? abrechnungsMonat;
  final bool abgerechnet;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Eroeffnungsreinigung({
    required this.id,
    required this.userId,
    this.betriebId,
    required this.stoerungsnummer,
    required this.datum,
    this.istBergkunde = false,
    this.preis,
    this.abrechnungsMonat,
    this.abgerechnet = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Eroeffnungsreinigung.fromJson(Map<String, dynamic> json) {
    return Eroeffnungsreinigung(
      id: json['id'],
      userId: json['user_id'],
      betriebId: json['betrieb_id'],
      stoerungsnummer: json['stoerungsnummer'],
      datum: DateTime.parse(json['datum']),
      istBergkunde: json['ist_bergkunde'] ?? false,
      preis: json['preis'] != null
          ? double.tryParse(json['preis'].toString())
          : null,
      abrechnungsMonat: json['abrechnungs_monat'] != null
          ? DateTime.parse(json['abrechnungs_monat'])
          : null,
      abgerechnet: json['abgerechnet'] ?? false,
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
      'stoerungsnummer': stoerungsnummer,
      'datum': datum.toIso8601String().split('T').first,
      'ist_bergkunde': istBergkunde,
      'preis': preis,
      'abrechnungs_monat':
          abrechnungsMonat?.toIso8601String().split('T').first,
      'abgerechnet': abgerechnet,
    };
  }
}
