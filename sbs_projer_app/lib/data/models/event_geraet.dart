/// Supabase-DTO für ein Technik-Gerät am Event: Anstich (Orion-Tank,
/// Mehrfachanstich) oder Durchlaufkühler. Beide in einer Tabelle — es sind
/// Geräte, an denen Leitungen hängen, mit Standort und Inbetriebnahme.
class EventGeraet {
  final String id;
  final String userId;
  final String eventId;
  final String typ;
  final String bezeichnung;
  final int? anzahlTanks; // nur mehrfachanstich (1–4)
  final String? standortNotiz;
  final double? latitude;
  final double? longitude;
  final String? positionQuelle;
  final String? positionGenauigkeit;
  final bool inBetrieb;
  final DateTime? inBetriebAm;
  final int sortierung;
  final String? notizen;
  // Kühler-Typenschilder + Sollbereich (Migration 173).
  final String? kuehlerTyp;
  final String? pumpeTyp;
  final String? typenschildKuehlerPfad;
  final String? typenschildPumpePfad;
  final Map<String, dynamic>? typenschildErkennung;
  final double? sollMinCelsius;
  final double? sollMaxCelsius;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventGeraet({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.typ,
    required this.bezeichnung,
    this.anzahlTanks,
    this.standortNotiz,
    this.latitude,
    this.longitude,
    this.positionQuelle,
    this.positionGenauigkeit,
    this.inBetrieb = false,
    this.inBetriebAm,
    this.sortierung = 0,
    this.notizen,
    this.kuehlerTyp,
    this.pumpeTyp,
    this.typenschildKuehlerPfad,
    this.typenschildPumpePfad,
    this.typenschildErkennung,
    this.sollMinCelsius,
    this.sollMaxCelsius,
    this.createdAt,
    this.updatedAt,
  });

  factory EventGeraet.fromJson(Map<String, dynamic> json) {
    return EventGeraet(
      id: json['id'],
      userId: json['user_id'],
      eventId: json['event_id'],
      typ: json['typ'],
      bezeichnung: json['bezeichnung'],
      anzahlTanks: json['anzahl_tanks'],
      standortNotiz: json['standort_notiz'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      positionQuelle: json['position_quelle'],
      positionGenauigkeit: json['position_genauigkeit'],
      inBetrieb: json['in_betrieb'] ?? false,
      inBetriebAm: json['in_betrieb_am'] != null
          ? DateTime.parse(json['in_betrieb_am'])
          : null,
      sortierung: json['sortierung'] ?? 0,
      notizen: json['notizen'],
      kuehlerTyp: json['kuehler_typ'],
      pumpeTyp: json['pumpe_typ'],
      typenschildKuehlerPfad: json['typenschild_kuehler_pfad'],
      typenschildPumpePfad: json['typenschild_pumpe_pfad'],
      typenschildErkennung:
          json['typenschild_erkennung'] as Map<String, dynamic>?,
      sollMinCelsius: (json['soll_min_celsius'] as num?)?.toDouble(),
      sollMaxCelsius: (json['soll_max_celsius'] as num?)?.toDouble(),
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
      'typ': typ,
      'bezeichnung': bezeichnung,
      'anzahl_tanks': anzahlTanks,
      'standort_notiz': standortNotiz,
      'latitude': latitude,
      'longitude': longitude,
      'position_quelle': positionQuelle,
      'position_genauigkeit': positionGenauigkeit,
      'in_betrieb': inBetrieb,
      'in_betrieb_am': inBetriebAm?.toIso8601String(),
      'sortierung': sortierung,
      'notizen': notizen,
      'kuehler_typ': kuehlerTyp,
      'pumpe_typ': pumpeTyp,
      'typenschild_kuehler_pfad': typenschildKuehlerPfad,
      'typenschild_pumpe_pfad': typenschildPumpePfad,
      'typenschild_erkennung': typenschildErkennung,
      'soll_min_celsius': sollMinCelsius,
      'soll_max_celsius': sollMaxCelsius,
    };
  }

  static const typen = [
    'orion_1000',
    'orion_500',
    'mehrfachanstich',
    'durchlaufkuehler',
  ];

  static String typLabel(String typ) => switch (typ) {
        'orion_1000' => 'Orion 1000 l',
        'orion_500' => 'Orion 500 l',
        'mehrfachanstich' => 'Mehrfachanstich',
        'durchlaufkuehler' => 'Durchlaufkühler',
        _ => typ,
      };

  /// Anstiche speisen Leitungen, Kühler kühlen sie nur.
  static bool istAnstich(String typ) => typ != 'durchlaufkuehler';
}
