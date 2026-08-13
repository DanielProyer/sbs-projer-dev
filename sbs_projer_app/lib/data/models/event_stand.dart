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
  final double? latitude;
  final double? longitude;

  /// 'karte' = am PC geplant, 'gps' = im Feld gemessen (siehe
  /// core/util/stand_position.dart). null = keine Position erfasst.
  final String? positionQuelle;
  final DateTime? positionErfasstAm;

  /// 'genau' | 'mittel' | 'ungefaehr' (siehe core/util/stand_position.dart).
  final String? positionGenauigkeit;
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
    this.latitude,
    this.longitude,
    this.positionQuelle,
    this.positionErfasstAm,
    this.positionGenauigkeit,
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
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      positionQuelle: json['position_quelle'],
      positionErfasstAm: json['position_erfasst_am'] != null
          ? DateTime.parse(json['position_erfasst_am'])
          : null,
      positionGenauigkeit: json['position_genauigkeit'],
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
      'latitude': latitude,
      'longitude': longitude,
      'position_quelle': positionQuelle,
      'position_erfasst_am': positionErfasstAm?.toIso8601String(),
      'position_genauigkeit': positionGenauigkeit,
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
