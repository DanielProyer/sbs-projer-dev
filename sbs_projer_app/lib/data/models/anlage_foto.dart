class AnlageFoto {
  final String id;
  final String userId;
  final String anlageId;
  final int fotoNummer;
  final String fotoUrl;
  final String? beschreibung;
  final DateTime? createdAt;

  AnlageFoto({
    required this.id,
    required this.userId,
    required this.anlageId,
    required this.fotoNummer,
    required this.fotoUrl,
    this.beschreibung,
    this.createdAt,
  });

  factory AnlageFoto.fromJson(Map<String, dynamic> json) {
    return AnlageFoto(
      id: json['id'],
      userId: json['user_id'],
      anlageId: json['anlage_id'],
      fotoNummer: json['foto_nummer'],
      fotoUrl: json['foto_url'],
      beschreibung: json['beschreibung'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'anlage_id': anlageId,
      'foto_nummer': fotoNummer,
      'foto_url': fotoUrl,
      'beschreibung': beschreibung,
    };
  }
}
