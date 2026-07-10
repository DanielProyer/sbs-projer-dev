/// Supabase-DTO für eine Schankanlage an einem Event-Stand.
class EventStandAnlage {
  final String id;
  final String userId;
  final String standId;
  final String typ;
  final int anzahl;
  final int sortierung;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventStandAnlage({
    required this.id,
    required this.userId,
    required this.standId,
    required this.typ,
    this.anzahl = 1,
    this.sortierung = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory EventStandAnlage.fromJson(Map<String, dynamic> json) {
    return EventStandAnlage(
      id: json['id'],
      userId: json['user_id'],
      standId: json['stand_id'],
      typ: json['typ'],
      anzahl: json['anzahl'] ?? 1,
      sortierung: json['sortierung'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'stand_id': standId,
      'typ': typ,
      'anzahl': anzahl,
      'sortierung': sortierung,
    };
  }

  static const typen = ['oberthekengeraet', 'hollandbuffet', 'ausschankwagen', 'sonstige'];

  static String typLabel(String typ) => switch (typ) {
        'oberthekengeraet' => 'Oberthekengerät',
        'hollandbuffet' => 'Hollandbuffet',
        'ausschankwagen' => 'Ausschankwagen',
        'sonstige' => 'Sonstige',
        _ => typ,
      };

  static String typKurz(String typ) => switch (typ) {
        'oberthekengeraet' => 'OT',
        'hollandbuffet' => 'Hollandbuffet',
        'ausschankwagen' => 'Ausschankwagen',
        'sonstige' => 'Sonstige',
        _ => typ,
      };
}
