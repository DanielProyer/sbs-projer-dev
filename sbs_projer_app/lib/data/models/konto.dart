class Konto {
  final String id;
  final String userId;
  final int kontonummer;
  final String bezeichnung;
  final String? beschreibung;
  final String? kategorie;
  final int? kontenklasse;
  final bool istAktiv;
  final DateTime? createdAt;

  Konto({
    required this.id,
    required this.userId,
    required this.kontonummer,
    required this.bezeichnung,
    this.beschreibung,
    this.kategorie,
    this.kontenklasse,
    this.istAktiv = true,
    this.createdAt,
  });

  factory Konto.fromJson(Map<String, dynamic> json) {
    return Konto(
      id: json['id'],
      userId: json['user_id'],
      kontonummer: json['kontonummer'],
      bezeichnung: json['bezeichnung'],
      beschreibung: json['beschreibung'],
      kategorie: json['kategorie'],
      kontenklasse: json['kontenklasse'],
      istAktiv: json['ist_aktiv'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'kontonummer': kontonummer,
      'bezeichnung': bezeichnung,
      'beschreibung': beschreibung,
      'kategorie': kategorie,
      'ist_aktiv': istAktiv,
    };
  }
}
