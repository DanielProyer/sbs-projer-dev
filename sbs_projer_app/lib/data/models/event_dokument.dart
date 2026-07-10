/// Supabase-DTO für ein abgelegtes PDF-Dokument eines Event-Jahres.
class EventDokument {
  final String id;
  final String userId;
  final String eventId;
  final String bezeichnung;
  final String dateiPfad;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventDokument({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.bezeichnung,
    required this.dateiPfad,
    this.createdAt,
    this.updatedAt,
  });

  factory EventDokument.fromJson(Map<String, dynamic> json) {
    return EventDokument(
      id: json['id'],
      userId: json['user_id'],
      eventId: json['event_id'],
      bezeichnung: json['bezeichnung'],
      dateiPfad: json['datei_pfad'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_id': eventId,
      'bezeichnung': bezeichnung,
      'datei_pfad': dateiPfad,
    };
  }
}
