/// Supabase-DTO für eine einzelne Betriebsferien-Periode.
///
/// Ersetzt die fünf festen Spaltenpaare (ferien_start/ferien_ende …
/// ferien5_start/ferien5_ende) auf `betriebe` durch beliebig viele Zeilen —
/// so bleibt die Historie erhalten, statt dass neue Ferien alte verdrängen.
class BetriebFerienDto {
  final String id;
  final String userId;
  final String betriebId;
  final DateTime von;
  final DateTime bis;
  final String quelle;
  final DateTime? bestaetigtAm;
  final String? notiz;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BetriebFerienDto({
    required this.id,
    required this.userId,
    required this.betriebId,
    required this.von,
    required this.bis,
    this.quelle = 'kunde',
    this.bestaetigtAm,
    this.notiz,
    this.createdAt,
    this.updatedAt,
  });

  factory BetriebFerienDto.fromJson(Map<String, dynamic> json) {
    return BetriebFerienDto(
      id: json['id'],
      userId: json['user_id'],
      betriebId: json['betrieb_id'],
      von: DateTime.parse(json['von']),
      bis: DateTime.parse(json['bis']),
      quelle: json['quelle'] ?? 'kunde',
      bestaetigtAm: json['bestaetigt_am'] != null
          ? DateTime.parse(json['bestaetigt_am'])
          : null,
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
      'betrieb_id': betriebId,
      'von': von.toIso8601String().split('T').first,
      'bis': bis.toIso8601String().split('T').first,
      'quelle': quelle,
      'bestaetigt_am': bestaetigtAm?.toIso8601String(),
      'notiz': notiz,
    };
  }
}
