/// Supabase-DTO für eine Zeit-/Spesen-Zeile eines Events (E4).
class EventAufwand {
  final String id;
  final String userId;
  final String eventId;
  final DateTime datum;
  final String kategorie; // anfahrt | inbetriebnahme | pikett | spesen
  final String? notiz;
  final double stunden;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventAufwand({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.datum,
    required this.kategorie,
    this.notiz,
    required this.stunden,
    this.createdAt,
    this.updatedAt,
  });

  static double _toDouble(dynamic v) =>
      v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

  factory EventAufwand.fromJson(Map<String, dynamic> json) {
    return EventAufwand(
      id: json['id'],
      userId: json['user_id'],
      eventId: json['event_id'],
      datum: DateTime.parse(json['datum']),
      kategorie: json['kategorie'],
      notiz: json['notiz'],
      stunden: _toDouble(json['stunden']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_id': eventId,
      'datum': datum.toIso8601String().substring(0, 10),
      'kategorie': kategorie,
      'notiz': notiz,
      'stunden': stunden,
    };
  }
}
