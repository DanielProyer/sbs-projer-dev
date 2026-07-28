/// Ergebnis der OCR-Analyse eines Kassenzettels via Claude Haiku.
class BelegScanResult {
  final String geschaeft;
  final DateTime datum;
  final List<BelegPosition> positionen;
  final double totalBrutto;
  final double konfidenz;
  final String? zahlungsmethode; // 'twint', 'bar', 'karte' oder null

  /// Drehung im Uhrzeigersinn (0/90/180/270), damit der Belegtext aufrecht
  /// steht — vom Modell am gelesenen Text beurteilt. Verlässlicher als die
  /// EXIF-Angabe der Kamera, die bei flach von oben aufgenommenen Belegen
  /// beliebig ausfällt (gemeldet Daniel 28.07.2026).
  final int bildDrehung;

  BelegScanResult({
    required this.geschaeft,
    required this.datum,
    required this.positionen,
    required this.totalBrutto,
    required this.konfidenz,
    this.zahlungsmethode,
    this.bildDrehung = 0,
  });

  bool get istMischkauf => positionen.length > 1;

  factory BelegScanResult.fromJson(Map<String, dynamic> json) {
    final positionen = (json['positionen'] as List)
        .map((p) => BelegPosition.fromJson(p as Map<String, dynamic>))
        .toList();
    return BelegScanResult(
      geschaeft: json['geschaeft'] as String? ?? 'Unbekannt',
      datum: DateTime.parse(json['datum'] as String),
      positionen: _mergeRundung(positionen),
      totalBrutto: _d(json['total_brutto']),
      konfidenz: _d(json['konfidenz']),
      zahlungsmethode: json['zahlungsmethode'] as String?,
      bildDrehung: _drehung(json['bild_drehung']),
    );
  }

  /// Rundungsdifferenzen (≤ 0.05 CHF) in die grösste Position mergen.
  static List<BelegPosition> _mergeRundung(List<BelegPosition> positionen) {
    if (positionen.length < 2) return positionen;

    final rundungen = positionen.where((p) => p.betragBrutto.abs() <= 0.05).toList();
    if (rundungen.isEmpty) return positionen;

    final rest = positionen.where((p) => p.betragBrutto.abs() > 0.05).toList();
    if (rest.isEmpty) return positionen;

    rest.sort((a, b) => b.betragBrutto.compareTo(a.betragBrutto));
    final target = rest.first;
    double extra = 0;
    for (final r in rundungen) {
      extra += r.betragBrutto;
    }

    rest[0] = BelegPosition(
      mwstSatz: target.mwstSatz,
      betragBrutto: target.betragBrutto + extra,
      beschreibung: target.beschreibung,
      kategorie: target.kategorie,
    );
    return rest;
  }

  static double _d(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  /// Nur 90er-Schritte zulassen — alles andere wäre ein Modell-Ausrutscher
  /// und würde den Beleg schief speichern.
  static int _drehung(dynamic value) {
    final grad = int.tryParse(value?.toString() ?? '') ?? 0;
    return const [0, 90, 180, 270].contains(grad) ? grad : 0;
  }
}

/// Eine Position auf dem Beleg (pro MwSt-Satz/Kategorie).
class BelegPosition {
  final double mwstSatz;
  final double betragBrutto;
  final String beschreibung;
  /// 'benzin', 'material', 'berufskleider', 'parkgebuehren', 'entsorgung'
  /// oder 'essen' (Auffangwert für Verpflegung/Übriges).
  final String kategorie;

  BelegPosition({
    required this.mwstSatz,
    required this.betragBrutto,
    required this.beschreibung,
    required this.kategorie,
  });

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
