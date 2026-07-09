/// Supabase-DTO für die Zuordnung Kontakt ↔ Event-Jahr (Rolle pro Zuordnung).
class EventKontakt {
  final String id;
  final String userId;
  final String eventId;
  final String kontaktId;
  final String rolle;
  final String? bemerkung;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventKontakt({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.kontaktId,
    required this.rolle,
    this.bemerkung,
    this.createdAt,
    this.updatedAt,
  });

  factory EventKontakt.fromJson(Map<String, dynamic> json) {
    return EventKontakt(
      id: json['id'],
      userId: json['user_id'],
      eventId: json['event_id'],
      kontaktId: json['kontakt_id'],
      rolle: json['rolle'],
      bemerkung: json['bemerkung'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_id': eventId,
      'kontakt_id': kontaktId,
      'rolle': rolle,
      'bemerkung': bemerkung,
    };
  }

  /// Rollen in fester Gruppierungs-Reihenfolge für die Anzeige.
  static const rollenReihenfolge = [
    'event_heineken', 'rsl', 'ok', 'bau', 'stand', 'monteur', 'stardrinks', 'sonstige',
  ];

  static String rolleLabel(String rolle) => switch (rolle) {
        'event_heineken' => 'Eventverantwortlicher',
        'rsl' => 'RSL',
        'ok' => 'OK',
        'bau' => 'Bau',
        'stand' => 'Stand',
        'monteur' => 'Monteur',
        'stardrinks' => 'Stardrinks',
        'sonstige' => 'Sonstige',
        _ => rolle,
      };
}
