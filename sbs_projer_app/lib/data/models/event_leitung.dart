/// Supabase-DTO für eine Bierleitung am Event. `nummer` ist die physisch
/// angeschriebene Beschriftung (am Anstich UND am Zapfhahn), eindeutig je
/// Anstich. Ziel (Stand/Gerätezeile) ist nullable — es wird beim
/// Anschliessen gesetzt, nicht beim Erzeugen.
class EventLeitung {
  final String id;
  final String userId;
  final String eventId;
  final String nummer;
  final String quelleId;
  final String? kuehlerId;
  final String? standId;
  final String? standAnlageId;
  final bool inBetrieb;
  final DateTime? inBetriebAm;
  final int sortierung;
  final String? notiz;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventLeitung({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.nummer,
    required this.quelleId,
    this.kuehlerId,
    this.standId,
    this.standAnlageId,
    this.inBetrieb = false,
    this.inBetriebAm,
    this.sortierung = 0,
    this.notiz,
    this.createdAt,
    this.updatedAt,
  });

  factory EventLeitung.fromJson(Map<String, dynamic> json) {
    return EventLeitung(
      id: json['id'],
      userId: json['user_id'],
      eventId: json['event_id'],
      nummer: json['nummer'],
      quelleId: json['quelle_id'],
      kuehlerId: json['kuehler_id'],
      standId: json['stand_id'],
      standAnlageId: json['stand_anlage_id'],
      inBetrieb: json['in_betrieb'] ?? false,
      inBetriebAm: json['in_betrieb_am'] != null
          ? DateTime.parse(json['in_betrieb_am'])
          : null,
      sortierung: json['sortierung'] ?? 0,
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
      'event_id': eventId,
      'nummer': nummer,
      'quelle_id': quelleId,
      'kuehler_id': kuehlerId,
      'stand_id': standId,
      'stand_anlage_id': standAnlageId,
      'in_betrieb': inBetrieb,
      'in_betrieb_am': inBetriebAm?.toIso8601String(),
      'sortierung': sortierung,
      'notiz': notiz,
    };
  }
}
