class BuchungsBeleg {
  final String id;
  final String userId;
  final String buchungId;
  final String dateiname;
  final String dateityp;
  final String storagePfad;
  final String belegQuelle;
  final String? beschreibung;
  final DateTime? createdAt;

  BuchungsBeleg({
    required this.id,
    required this.userId,
    required this.buchungId,
    required this.dateiname,
    required this.dateityp,
    required this.storagePfad,
    this.belegQuelle = 'manuell',
    this.beschreibung,
    this.createdAt,
  });

  factory BuchungsBeleg.fromJson(Map<String, dynamic> json) {
    return BuchungsBeleg(
      id: json['id'],
      userId: json['user_id'],
      buchungId: json['buchung_id'],
      dateiname: json['dateiname'],
      dateityp: json['dateityp'],
      storagePfad: json['storage_pfad'],
      belegQuelle: json['beleg_quelle'] ?? 'manuell',
      beschreibung: json['beschreibung'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'buchung_id': buchungId,
      'dateiname': dateiname,
      'dateityp': dateityp,
      'storage_pfad': storagePfad,
      'beleg_quelle': belegQuelle,
      'beschreibung': beschreibung,
    };
  }
}
