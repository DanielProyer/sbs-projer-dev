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
      'typ': typ,
      'anlass': anlass,
      'titel': titel,
      'notizen': notizen,
      'status': status,
    };
  }
}
