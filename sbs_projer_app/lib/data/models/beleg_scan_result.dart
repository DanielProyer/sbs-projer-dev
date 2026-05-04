/// Ergebnis der OCR-Analyse eines Kassenzettels via Claude Haiku.
class BelegScanResult {
  final String geschaeft;
  final DateTime datum;
  final List<BelegPosition> positionen;
  final double totalBrutto;
  final double konfidenz;
  final String? zahlungsmethode; // 'twint', 'bar', 'karte' oder null

  BelegScanResult({
    required this.geschaeft,
    required this.datum,
    required this.positionen,
    required this.totalBrutto,
    required this.konfidenz,
    this.zahlungsmethode,
  });

  bool get istMischkauf => positionen.length > 1;

  factory BelegScanResult.fromJson(Map<String, dynamic> json) {
    final positionen = (json['positionen'] as List)
        .map((p) => BelegPosition.fromJson(p as Map<String, dynamic>))
        .toList();
    return BelegScanResult(
      geschaeft: json['geschaeft'] as String? ?? 'Unbekannt',
      datum: DateTime.parse(json['datum'] as String),
      positionen: positionen,
      totalBrutto: _d(json['total_brutto']),
      konfidenz: _d(json['konfidenz']),
      zahlungsmethode: json['zahlungsmethode'] as String?,
    );
  }

  static double _d(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }
}

/// Eine Position auf dem Beleg (pro MwSt-Satz/Kategorie).
class BelegPosition {
  final double mwstSatz;
  final double betragBrutto;
  final String beschreibung;
  final String kategorie; // 'benzin' oder 'essen'

  BelegPosition({
    required this.mwstSatz,
    required this.betragBrutto,
    required this.beschreibung,
    required this.kategorie,
  });

  bool get istBenzin => kategorie == 'benzin';

  /// Netto-Betrag berechnet aus Brutto und MwSt-Satz.
  double get betragNetto =>
      mwstSatz > 0 ? betragBrutto / (1 + mwstSatz / 100) : betragBrutto;

  /// MwSt-Betrag = Brutto - Netto.
  double get mwstBetrag => betragBrutto - betragNetto;

  factory BelegPosition.fromJson(Map<String, dynamic> json) {
    return BelegPosition(
      mwstSatz: _d(json['mwst_satz']),
      betragBrutto: _d(json['betrag_brutto']),
      beschreibung: json['beschreibung'] as String? ?? '',
      kategorie: json['kategorie'] as String? ?? 'essen',
    );
  }

  static double _d(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }
}
