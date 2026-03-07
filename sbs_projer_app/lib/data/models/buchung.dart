class Buchung {
  final String id;
  final String userId;
  final DateTime datum;
  final String? belegnummer;
  final String? vorlageId;
  final int sollKonto;
  final int habenKonto;
  final int? mwstKonto;
  final double betragNetto;
  final double mwstSatz;
  final double mwstBetrag;
  final double betragBrutto;
  final String beschreibung;
  final String? zahlungsweg;
  final String? belegordner;
  final String? belegTyp;
  final String? belegId;
  final int geschaeftsjahr;
  final int? monat;
  final int? quartal;
  final bool istStorniert;
  final String? stornoVonId;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Buchung({
    required this.id,
    required this.userId,
    required this.datum,
    this.belegnummer,
    this.vorlageId,
    required this.sollKonto,
    required this.habenKonto,
    this.mwstKonto,
    required this.betragNetto,
    this.mwstSatz = 0,
    this.mwstBetrag = 0,
    required this.betragBrutto,
    required this.beschreibung,
    this.zahlungsweg,
    this.belegordner,
    this.belegTyp,
    this.belegId,
    required this.geschaeftsjahr,
    this.monat,
    this.quartal,
    this.istStorniert = false,
    this.stornoVonId,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory Buchung.fromJson(Map<String, dynamic> json) {
    return Buchung(
      id: json['id'],
      userId: json['user_id'],
      datum: DateTime.parse(json['datum']),
      belegnummer: json['belegnummer'],
      vorlageId: json['vorlage_id'],
      sollKonto: json['soll_konto'],
      habenKonto: json['haben_konto'],
      mwstKonto: json['mwst_konto'],
      betragNetto: _d(json['betrag_netto']),
      mwstSatz: _d(json['mwst_satz']),
      mwstBetrag: _d(json['mwst_betrag']),
      betragBrutto: _d(json['betrag_brutto']),
      beschreibung: json['beschreibung'],
      zahlungsweg: json['zahlungsweg'],
      belegordner: json['belegordner'],
      belegTyp: json['beleg_typ'],
      belegId: json['beleg_id'],
      geschaeftsjahr: json['geschaeftsjahr'],
      monat: json['monat'],
      quartal: json['quartal'],
      istStorniert: json['ist_storniert'] ?? false,
      stornoVonId: json['storno_von_id'],
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'datum': datum.toIso8601String().split('T').first,
      'belegnummer': belegnummer,
      'vorlage_id': vorlageId,
      'soll_konto': sollKonto,
      'haben_konto': habenKonto,
      'mwst_konto': mwstKonto,
      'betrag_netto': betragNetto,
      'mwst_satz': mwstSatz,
      'mwst_betrag': mwstBetrag,
      'betrag_brutto': betragBrutto,
      'beschreibung': beschreibung,
      'zahlungsweg': zahlungsweg,
      'belegordner': belegordner,
      'beleg_typ': belegTyp,
      'beleg_id': belegId,
      'geschaeftsjahr': geschaeftsjahr,
      'ist_storniert': istStorniert,
      'storno_von_id': stornoVonId,
      'notizen': notizen,
    };
  }

  static double _d(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }
}
