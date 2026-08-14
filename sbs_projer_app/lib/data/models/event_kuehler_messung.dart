/// Supabase-DTO für eine manuelle Kühlertemperatur-Messung am Event.
/// Mehrmals täglich erfasst, Verlauf als Grafik in der App (Migration 173).
class EventKuehlerMessung {
  final String id;
  final String userId;
  final String geraetId;
  final DateTime gemessenAm;
  final double temperatur;
  final String? notiz;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventKuehlerMessung({
    required this.id,
    required this.userId,
    required this.geraetId,
    required this.gemessenAm,
    required this.temperatur,
    this.notiz,
    this.createdAt,
    this.updatedAt,
  });

  factory EventKuehlerMessung.fromJson(Map<String, dynamic> json) {
    return EventKuehlerMessung(
      id: json['id'],
      userId: json['user_id'],
      geraetId: json['geraet_id'],
      gemessenAm: DateTime.parse(json['gemessen_am']),
      temperatur: (json['temperatur'] as num).toDouble(),
      notiz: json['notiz'],
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
      'geraet_id': geraetId,
      'gemessen_am': gemessenAm.toUtc().toIso8601String(),
      'temperatur': temperatur,
      'notiz': notiz,
    };
  }
}
