class MaterialKategorie {
  final String id;
  final String userId;
  final String name;
  final String? beschreibung;
  final int sortierung;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MaterialKategorie({
    required this.id,
    required this.userId,
    required this.name,
    this.beschreibung,
    this.sortierung = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory MaterialKategorie.fromJson(Map<String, dynamic> json) {
    return MaterialKategorie(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      beschreibung: json['beschreibung'],
      sortierung: json['sortierung'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'beschreibung': beschreibung,
      'sortierung': sortierung,
    };
  }
}
