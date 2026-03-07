class Lager {
  final String id;
  final String userId;
  final String? kategorieId;
  final String? materialId;
  final String? dboNr;
  final String name;
  final String? beschreibung;
  final String einheit;
  final double bestandAktuell;
  final double bestandMindest;
  final double bestandOptimal;
  final bool? bestandNiedrig;
  final String? lieferant;
  final String? lieferantenArtikelNr;
  final double? preisEinkauf;
  final bool istAktiv;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Lager({
    required this.id,
    required this.userId,
    this.kategorieId,
    this.materialId,
    this.dboNr,
    required this.name,
    this.beschreibung,
    this.einheit = 'Stück',
    this.bestandAktuell = 0,
    this.bestandMindest = 5,
    this.bestandOptimal = 10,
    this.bestandNiedrig,
    this.lieferant,
    this.lieferantenArtikelNr,
    this.preisEinkauf,
    this.istAktiv = true,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory Lager.fromJson(Map<String, dynamic> json) {
    return Lager(
      id: json['id'],
      userId: json['user_id'],
      kategorieId: json['kategorie_id'],
      materialId: json['material_id'],
      dboNr: json['dbo_nr'],
      name: json['name'],
      beschreibung: json['beschreibung'],
      einheit: json['einheit'] ?? 'Stück',
      bestandAktuell: _d(json['bestand_aktuell'], 0),
      bestandMindest: _d(json['bestand_mindest'], 5),
      bestandOptimal: _d(json['bestand_optimal'], 10),
      bestandNiedrig: json['bestand_niedrig'],
      lieferant: json['lieferant'],
      lieferantenArtikelNr: json['lieferanten_artikel_nr'],
      preisEinkauf: _toDouble(json['preis_einkauf']),
      istAktiv: json['ist_aktiv'] ?? true,
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'kategorie_id': kategorieId,
      'material_id': materialId,
      'dbo_nr': dboNr,
      'name': name,
      'beschreibung': beschreibung,
      'einheit': einheit,
      'bestand_aktuell': bestandAktuell,
      'bestand_mindest': bestandMindest,
      'bestand_optimal': bestandOptimal,
      'lieferant': lieferant,
      'lieferanten_artikel_nr': lieferantenArtikelNr,
      'preis_einkauf': preisEinkauf,
      'ist_aktiv': istAktiv,
      'notizen': notizen,
    };
  }

  static double _d(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}
