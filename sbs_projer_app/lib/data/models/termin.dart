/// Supabase-DTO für einen Termin (Tabelle `termine`, Migration 037 + 086 +
/// 130).
///
/// Eröffnungs-/Endreinigungen werden bis zur Bestätigung rein client-seitig
/// berechnet (`autoTermineProvider` in `tour_providers.dart`) — erst wenn
/// Daniel einen Vorschlag annimmt oder einen Termin diktiert, entsteht hier
/// eine Zeile. Leitgedanke (Etappe 4): «Berechnet bleibt berechnet,
/// bestätigt wird gespeichert.»
class TerminDto {
  final String id;
  final String userId;
  final String betriebId;
  final DateTime datum;
  final String? uhrzeitVon;
  final String? uhrzeitBis;

  /// Letzter Tag (null = eintaegig). Bei [spielraum] 'woche' oder
  /// 'zwischensaison' gesetzt — Migration 199.
  final DateTime? datumBis;

  /// 'fix' = genau dann (ggf. mit Uhrzeit) | 'woche' = irgendwann in der
  /// Woche | 'zwischensaison' = jederzeit waehrend der Zwischensaison.
  ///
  /// WARUM neben [datumBis]: Aus einem Sieben-Tage-Eintrag allein laesst
  /// sich nicht ablesen, ob der Wirt die ganze Woche Zeit hat oder ob dort
  /// eine Woche lang gearbeitet wird.
  final String spielraum;

  /// 'eroeffnungsreinigung' | 'endreinigung' | 'sonstiges'
  final String typ;

  /// 'saisonstart' | 'saisonende' | 'ferien' | 'zwischensaison' | 'manuell'
  final String anlass;
  final String titel;
  final String? notizen;

  /// 'vorgeschlagen' | 'geplant' | 'erledigt' | 'abgesagt'
  final String status;

  const TerminDto({
    required this.id,
    required this.userId,
    required this.betriebId,
    required this.datum,
    this.uhrzeitVon,
    this.uhrzeitBis,
    this.datumBis,
    this.spielraum = 'fix',
    required this.typ,
    this.anlass = 'manuell',
    required this.titel,
    this.notizen,
    this.status = 'geplant',
  });

  factory TerminDto.fromJson(Map<String, dynamic> json) {
    return TerminDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      betriebId: json['betrieb_id'] as String,
      datum: DateTime.parse(json['datum'] as String),
      uhrzeitVon: json['uhrzeit_von'] as String?,
      uhrzeitBis: json['uhrzeit_bis'] as String?,
      datumBis: json['datum_bis'] == null
          ? null
          : DateTime.parse(json['datum_bis'] as String),
      spielraum: json['spielraum'] as String? ?? 'fix',
      typ: json['typ'] as String? ?? 'sonstiges',
      anlass: json['anlass'] as String? ?? 'manuell',
      titel: json['titel'] as String? ?? '',
      notizen: json['notizen'] as String?,
      status: json['status'] as String? ?? 'geplant',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'betrieb_id': betriebId,
      'datum': datum.toIso8601String().split('T').first,
      'uhrzeit_von': uhrzeitVon,
      'uhrzeit_bis': uhrzeitBis,
      'datum_bis': datumBis?.toIso8601String().split('T').first,
      'spielraum': spielraum,
      'typ': typ,
      'anlass': anlass,
      'titel': titel,
      'notizen': notizen,
      'status': status,
    };
  }
}
