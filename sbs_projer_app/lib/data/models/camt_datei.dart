class CamtDatei {
  final String id;
  final String userId;
  final String dateiname;
  final DateTime? hochgeladenAm;
  final DateTime? zeitraumVon;
  final DateTime? zeitraumBis;
  final String? iban;
  final int anzahlEintraege;
  final int anzahlGutschriften;
  final String storagePfad;

  /// Bank-Salden aus der Datei (OPBD/CLBD) — Grundlage des Bank-Wächters.
  /// `null` bei Dateien, die vor Migration 180 importiert wurden.
  final double? anfangssaldo;
  final double? schlusssaldo;

  CamtDatei({
    required this.id,
    required this.userId,
    required this.dateiname,
    this.hochgeladenAm,
    this.zeitraumVon,
    this.zeitraumBis,
    this.iban,
    this.anzahlEintraege = 0,
    this.anzahlGutschriften = 0,
    required this.storagePfad,
    this.anfangssaldo,
    this.schlusssaldo,
  });

  static DateTime? _d(dynamic v) =>
      v == null ? null : DateTime.parse(v.toString());

  factory CamtDatei.fromJson(Map<String, dynamic> j) => CamtDatei(
        id: j['id'].toString(),
        userId: j['user_id'].toString(),
        dateiname: j['dateiname'] as String,
        hochgeladenAm: _d(j['hochgeladen_am']),
        zeitraumVon: _d(j['zeitraum_von']),
        zeitraumBis: _d(j['zeitraum_bis']),
        iban: j['iban'] as String?,
        anzahlEintraege: (j['anzahl_eintraege'] ?? 0) as int,
        anzahlGutschriften: (j['anzahl_gutschriften'] ?? 0) as int,
        storagePfad: j['storage_pfad'] as String,
        anfangssaldo: j['anfangssaldo'] == null
            ? null
            : double.tryParse(j['anfangssaldo'].toString()),
        schlusssaldo: j['schlusssaldo'] == null
            ? null
            : double.tryParse(j['schlusssaldo'].toString()),
      );

  Map<String, dynamic> toInsert() => {
        'dateiname': dateiname,
        'zeitraum_von': zeitraumVon?.toIso8601String().split('T').first,
        'zeitraum_bis': zeitraumBis?.toIso8601String().split('T').first,
        'iban': iban,
        'anzahl_eintraege': anzahlEintraege,
        'anzahl_gutschriften': anzahlGutschriften,
        'storage_pfad': storagePfad,
        'anfangssaldo': anfangssaldo,
        'schlusssaldo': schlusssaldo,
      };
}
