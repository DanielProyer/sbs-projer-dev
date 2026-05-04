class Biersorte {
  final String id;
  final String userId;
  final String name;
  final String kategorie; // eigen, fremd, orion, wein
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Biersorte({
    required this.id,
    required this.userId,
    required this.name,
    required this.kategorie,
    this.createdAt,
    this.updatedAt,
  });

  factory Biersorte.fromJson(Map<String, dynamic> json) {
    return Biersorte(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      kategorie: json['kategorie'],
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
      'name': name,
      'kategorie': kategorie,
    };
  }
}
