/// Supabase-DTO für einen Pikett-Einsatz während eines Events.
class EventEinsatz {
  final String id;
  final String userId;
  final String eventId;
  final String? standId;
  final DateTime zeitpunkt;
  final String beschreibung;
  final String? material;
  final String? materialId;
  final double? materialMenge;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventEinsatz({
    required this.id,
    required this.userId,
    required this.eventId,
    this.standId,
    required this.zeitpunkt,
    required this.beschreibung,
    this.material,
    this.materialId,
    this.materialMenge,
    this.createdAt,
    this.updatedAt,
  });

  factory EventEinsatz.fromJson(Map<String, dynamic> json) {
    return EventEinsatz(
      id: json['id'],
      userId: json['user_id'],
      eventId: json['event_id'],
      standId: json['stand_id'],
      zeitpunkt: DateTime.parse(json['zeitpunkt']),
      beschreibung: json['beschreibung'],
      material: json['material'],
      materialId: json['material_id'],
      materialMenge: json['material_menge'] != null ? (json['material_menge'] as num).toDouble() : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_id': eventId,
      'stand_id': standId,
      'zeitpunkt': zeitpunkt.toIso8601String(),
      'beschreibung': beschreibung,
      'material': material,
      'material_id': materialId,
      'material_menge': materialMenge,
    };
  }
}
