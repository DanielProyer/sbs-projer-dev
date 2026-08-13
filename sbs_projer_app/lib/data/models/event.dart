/// Supabase-DTO für ein Event-Jahr (z. B. «Lumnezia 2025»).
/// Referenziert den Veranstaltungs-Betrieb (zapfsysteme enthält 'Veranstaltungen').
class Event {
  final String id;
  final String userId;
  final String betriebId;
  final int jahr;
  final DateTime? terminVon;
  final DateTime? terminBis;
  final String? notizen;

  /// Storage-Pfad des Lageplan-Bilds (Bucket event-dokumente).
  final String? lageplanPfad;

  /// Bildmasse + Passpunkte als JSON (siehe core/util/georeferenz.dart).
  final Map<String, dynamic>? lageplanPunkte;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Event({
    required this.id,
    required this.userId,
    required this.betriebId,
    required this.jahr,
    this.terminVon,
    this.terminBis,
    this.notizen,
    this.lageplanPfad,
    this.lageplanPunkte,
    this.createdAt,
    this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      userId: json['user_id'],
      betriebId: json['betrieb_id'],
      jahr: json['jahr'],
      terminVon: json['termin_von'] != null ? DateTime.parse(json['termin_von']) : null,
      terminBis: json['termin_bis'] != null ? DateTime.parse(json['termin_bis']) : null,
      notizen: json['notizen'],
      lageplanPfad: json['lageplan_pfad'],
      lageplanPunkte: json['lageplan_punkte'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'betrieb_id': betriebId,
      'jahr': jahr,
      'termin_von': terminVon?.toIso8601String().split('T').first,
      'termin_bis': terminBis?.toIso8601String().split('T').first,
      'notizen': notizen,
      'lageplan_pfad': lageplanPfad,
      'lageplan_punkte': lageplanPunkte,
    };
  }
}
