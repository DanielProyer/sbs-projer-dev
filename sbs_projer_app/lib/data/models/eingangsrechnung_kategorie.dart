/// DTO der Config-Tabelle `eingangsrechnung_kategorie` (global, kein user_id).
class EingangsrechnungKategorie {
  final String code;
  final String bezeichnung;
  final int? defaultAufwandskonto;
  final int? defaultVorsteuerKonto;
  final int reihenfolge;
  final bool istAktiv;

  const EingangsrechnungKategorie({
    required this.code,
    required this.bezeichnung,
    this.defaultAufwandskonto,
    this.defaultVorsteuerKonto,
    this.reihenfolge = 0,
    this.istAktiv = true,
  });

  factory EingangsrechnungKategorie.fromJson(Map<String, dynamic> json) =>
      EingangsrechnungKategorie(
        code: json['code'] as String,
        bezeichnung: json['bezeichnung'] as String,
        defaultAufwandskonto: _toInt(json['default_aufwandskonto']),
        defaultVorsteuerKonto: _toInt(json['default_vorsteuer_konto']),
        reihenfolge: _toInt(json['reihenfolge']) ?? 0,
        istAktiv: json['ist_aktiv'] ?? true,
      );

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
