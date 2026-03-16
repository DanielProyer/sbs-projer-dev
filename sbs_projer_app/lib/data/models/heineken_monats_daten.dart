/// Repräsentiert eine einzelne Position in der Heineken-Monatsrechnung.
class HeinekenPosition {
  final DateTime datum;
  final String? stoerNr;
  final String? bereich;
  final String kunde;
  final double betrag;

  HeinekenPosition({
    required this.datum,
    this.stoerNr,
    this.bereich,
    required this.kunde,
    required this.betrag,
  });
}

/// Aggregierte Monatsdaten für eine Heineken-Monatsrechnung.
class HeinekenMonatsDaten {
  final DateTime monat;
  final List<HeinekenPosition> stoerungen;
  final List<HeinekenPosition> eigenauftraege;
  final List<HeinekenPosition> eroeffnungen;
  final List<HeinekenPosition> montagen;
  final List<HeinekenPosition> pikettDienste;
  final List<HeinekenPosition> berghaeuserAnfahrt;
  final List<HeinekenPosition> diverses;
  final List<HeinekenPosition> gratisreinigungen;

  // Raw DB rows for rapport PDF generation
  final List<Map<String, dynamic>> stoerungRows;
  final List<Map<String, dynamic>> eigenauftragRows;
  final List<Map<String, dynamic>> eroeffnungRows;
  final List<Map<String, dynamic>> montageRows;
  final List<Map<String, dynamic>> pikettRows;
  final List<Map<String, dynamic>> bergkundenRows;
  final Map<String, Map<String, dynamic>> betriebMap;
  final Map<String, String> materialNames;

  HeinekenMonatsDaten({
    required this.monat,
    this.stoerungen = const [],
    this.eigenauftraege = const [],
    this.eroeffnungen = const [],
    this.montagen = const [],
    this.pikettDienste = const [],
    this.berghaeuserAnfahrt = const [],
    this.diverses = const [],
    this.gratisreinigungen = const [],
    this.stoerungRows = const [],
    this.eigenauftragRows = const [],
    this.eroeffnungRows = const [],
    this.montageRows = const [],
    this.pikettRows = const [],
    this.bergkundenRows = const [],
    this.betriebMap = const {},
    this.materialNames = const {},
  });

  double get totalStoerungen =>
      stoerungen.fold(0.0, (s, p) => s + p.betrag);
  double get totalEigenauftraege =>
      eigenauftraege.fold(0.0, (s, p) => s + p.betrag);
  double get totalEroeffnungen =>
      eroeffnungen.fold(0.0, (s, p) => s + p.betrag);
  double get totalMontagen =>
      montagen.fold(0.0, (s, p) => s + p.betrag);
  double get totalPikett =>
      pikettDienste.fold(0.0, (s, p) => s + p.betrag);
  double get totalBerghaeuserAnfahrt =>
      berghaeuserAnfahrt.fold(0.0, (s, p) => s + p.betrag);
  double get totalDiverses =>
      diverses.fold(0.0, (s, p) => s + p.betrag);
  double get totalGratisreinigungen =>
      gratisreinigungen.fold(0.0, (s, p) => s + p.betrag);

  double get totalNetto =>
      totalStoerungen +
      totalEigenauftraege +
      totalEroeffnungen +
      totalMontagen +
      totalPikett +
      totalBerghaeuserAnfahrt +
      totalDiverses +
      totalGratisreinigungen;

  double get mwstBetrag => _round2(totalNetto * 0.081);
  double get totalBrutto => _round2(totalNetto + mwstBetrag);

  /// Alle 8 Kategorien als geordnete Liste.
  List<(String, List<HeinekenPosition>, double)> get kategorien => [
        ('Störungen', stoerungen, totalStoerungen),
        ('Eigene Aufträge', eigenauftraege, totalEigenauftraege),
        ('Eröffnungen / Endreinigungen', eroeffnungen, totalEroeffnungen),
        ('Montagen', montagen, totalMontagen),
        ('Pikett', pikettDienste, totalPikett),
        ('Berghäuser Anfahrtspauschalen', berghaeuserAnfahrt,
            totalBerghaeuserAnfahrt),
        ('Diverses', diverses, totalDiverses),
        ('Gratisreinigungen + Valora', gratisreinigungen,
            totalGratisreinigungen),
      ];

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}
