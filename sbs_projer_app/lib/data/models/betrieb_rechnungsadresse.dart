class BetriebRechnungsadresse {
  final String id;
  final String userId;
  final String betriebId;
  final String? firma;
  final String? vorname;
  final String nachname;
  final String strasse;
  final String? nr;
  final String plz;
  final String ort;
  final String? email;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BetriebRechnungsadresse({
    required this.id,
    required this.userId,
    required this.betriebId,
    this.firma,
    this.vorname,
    required this.nachname,
    required this.strasse,
    this.nr,
    required this.plz,
    required this.ort,
    this.email,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory BetriebRechnungsadresse.fromJson(Map<String, dynamic> json) {
    return BetriebRechnungsadresse(
      id: json['id'],
      userId: json['user_id'],
      betriebId: json['betrieb_id'],
      firma: json['firma'],
      vorname: json['vorname'],
      nachname: json['nachname'],
      strasse: json['strasse'],
      nr: json['nr'],
      plz: json['plz'],
      ort: json['ort'],
      email: json['email'],
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'betrieb_id': betriebId,
      'firma': firma,
      'vorname': vorname,
      'nachname': nachname,
      'strasse': strasse,
      'nr': nr,
      'plz': plz,
      'ort': ort,
      'email': email,
      'notizen': notizen,
    };
  }

  String get vollstaendigeAdresse {
    final parts = <String>[];
    if (firma != null && firma!.isNotEmpty) parts.add(firma!);
    parts.add('$strasse${nr != null ? " $nr" : ""}');
    parts.add('$plz $ort');
    return parts.join(', ');
  }
}
