class BetriebRechnungsadresse {
  final String id;
  final String userId;
  final String betriebId;
  final String? firma;

  /// Objekt-/Betriebsbezeichnung — die Zeile, an der bei Sammelzahlern
  /// (Weisse Arena, Davos Klosters, Goodfast, SV) erkennbar bleibt, für
  /// welchen Betrieb die Rechnung gilt. Hiess bis Migration 167 `nachname`.
  final String objekt;

  /// Kostenstelle/Referenz des Empfängers, eigene Adresszeile.
  final String? kostenstelle;

  /// Freie Zusatzzeile: Abteilung oder Eingangskanal.
  final String? zusatz;

  /// Postfach — ersetzt im Druck die Strassenzeile.
  final String? postfach;

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
    required this.objekt,
    this.kostenstelle,
    this.zusatz,
    this.postfach,
    this.strasse = '',
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
      objekt: json['objekt'] ?? json['nachname'] ?? '',
      kostenstelle: json['kostenstelle'],
      zusatz: json['zusatz'],
      postfach: json['postfach'],
      strasse: json['strasse'] ?? '',
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
      'objekt': objekt,
      'kostenstelle': kostenstelle,
      'zusatz': zusatz,
      'postfach': postfach,
      'strasse': strasse,
      'nr': nr,
      'plz': plz,
      'ort': ort,
      'email': email,
      'notizen': notizen,
    };
  }

  /// Adress-Snapshot für die pro-Rechnung-Override (ohne id/Betrieb/Zeitstempel).
  Map<String, dynamic> toAdressSnapshot() => {
        'firma': firma,
        'objekt': objekt,
        'kostenstelle': kostenstelle,
        'zusatz': zusatz,
        'postfach': postfach,
        'strasse': strasse,
        'nr': nr,
        'plz': plz,
        'ort': ort,
        'email': email,
      };

  /// Baut eine Adresse aus einem pro-Rechnung-Snapshot (siehe [toAdressSnapshot]).
  /// `nachname` wird als Alt-Key weiterhin gelesen (vor Migration 167 erzeugte
  /// Snapshots).
  factory BetriebRechnungsadresse.fromAdressSnapshot(Map<String, dynamic> m,
      {String betriebId = ''}) {
    return BetriebRechnungsadresse(
      id: '',
      userId: '',
      betriebId: betriebId,
      firma: m['firma'] as String?,
      objekt: (m['objekt'] as String?) ?? (m['nachname'] as String?) ?? '',
      kostenstelle: m['kostenstelle'] as String?,
      zusatz: m['zusatz'] as String?,
      postfach: m['postfach'] as String?,
      strasse: (m['strasse'] as String?) ?? '',
      nr: m['nr'] as String?,
      plz: (m['plz'] as String?) ?? '',
      ort: (m['ort'] as String?) ?? '',
      email: m['email'] as String?,
    );
  }

  String get vollstaendigeAdresse {
    final parts = <String>[];
    if (firma != null && firma!.isNotEmpty) parts.add(firma!);
    if (postfach != null && postfach!.isNotEmpty) {
      parts.add(postfach!);
    } else if (strasse.isNotEmpty) {
      parts.add('$strasse${nr != null ? " $nr" : ""}');
    }
    parts.add('$plz $ort');
    return parts.join(', ');
  }
}
