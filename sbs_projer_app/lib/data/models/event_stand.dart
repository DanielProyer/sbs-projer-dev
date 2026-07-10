import 'package:sbs_projer_app/data/models/event_stand_anlage.dart';

/// Supabase-DTO für einen Stand innerhalb eines Event-Jahres.
class EventStand {
  final String id;
  final String userId;
  final String eventId;
  final String name;
  final String? standnummer;
  final int sortierung;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventStand({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.name,
    this.standnummer,
    this.sortierung = 0,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory EventStand.fromJson(Map<String, dynamic> json) {
    return EventStand(
      id: json['id'],
      userId: json['user_id'],
      eventId: json['event_id'],
      name: json['name'],
      standnummer: json['standnummer'],
      sortierung: json['sortierung'] ?? 0,
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_id': eventId,
      'name': name,
      'standnummer': standnummer,
      'sortierung': sortierung,
      'notizen': notizen,
    };
  }

  /// Kurz-Zusammenfassung der Anlagen für die Stand-Karte, z. B. "7× OT · 3× Hollandbuffet".
  static String anlagenText(List<({String typ, int anzahl})> anlagen) {
    if (anlagen.isEmpty) return 'Keine Anlagen';
    final zusammen = <String, int>{};
    for (final a in anlagen) {
      zusammen[a.typ] = (zusammen[a.typ] ?? 0) + a.anzahl;
    }
    return zusammen.entries
        .map((e) => '${e.value}× ${EventStandAnlage.typKurz(e.key)}')
        .join(' · ');
  }
}
