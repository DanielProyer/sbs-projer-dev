/// Supabase-DTO für einen Änderungsvorschlag aus Google/Website
/// (Tabelle `betrieb_vorschlaege`, Migration 160).
///
/// Google und Website schreiben NIE direkt in den Betrieb — eine still
/// überschriebene Öffnungszeit wäre schlimmer als gar keine, weil sie
/// gepflegt aussieht, ohne es zu sein. Alles läuft über diese Prüfliste.
///
/// [altWert]/[neuWert] sind das per Supabase dekodierte jsonb — die Form
/// hängt von [feld] ab (siehe `core/util/vorschlag_anzeige.dart`):
/// - `ruhetage`: `List<String>` mit Wochentags-Kürzeln ('Mo'..'So')
/// - `oeffnungszeiten`: `Map<String, List<{'von','bis'}>>` je Wochentag
/// - `ferien`: `List<{'von','bis'}>` (ISO-Datum) — eine oder mehrere Perioden
/// - `saison`: `Map` mit einzelnen der Schlüssel `sommer_start_datum`,
///   `sommer_ende_datum`, `winter_start_datum`, `winter_ende_datum`
/// - `status`: `Map` mit `status` (Google-`businessStatus`) — reiner Hinweis,
///   wird nie automatisch übernommen
class BetriebVorschlagDto {
  final String id;
  final String betriebId;
  final String feld;
  final dynamic altWert;
  final dynamic neuWert;
  final String quelle;
  final double? konfidenz;
  final DateTime gefundenAm;
  final String status;
  final String userId;

  BetriebVorschlagDto({
    required this.id,
    required this.betriebId,
    required this.feld,
    this.altWert,
    required this.neuWert,
    required this.quelle,
    this.konfidenz,
    required this.gefundenAm,
    this.status = 'offen',
    required this.userId,
  });

  factory BetriebVorschlagDto.fromJson(Map<String, dynamic> json) {
    return BetriebVorschlagDto(
      id: json['id'],
      betriebId: json['betrieb_id'],
      feld: json['feld'],
      altWert: json['alt_wert'],
      neuWert: json['neu_wert'],
      quelle: json['quelle'],
      konfidenz: json['konfidenz'] != null
          ? double.tryParse(json['konfidenz'].toString())
          : null,
      gefundenAm: DateTime.parse(json['gefunden_am']),
      status: json['status'] ?? 'offen',
      userId: json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'betrieb_id': betriebId,
      'feld': feld,
      'alt_wert': altWert,
      'neu_wert': neuWert,
      'quelle': quelle,
      'konfidenz': konfidenz,
      'gefunden_am': gefundenAm.toIso8601String(),
      'status': status,
      'user_id': userId,
    };
  }
}
