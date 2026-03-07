class BuchungsVorlage {
  final String id;
  final String userId;
  final String geschaeftsfallId;
  final String bezeichnung;
  final int sollKonto;
  final int habenKonto;
  final int? mwstKonto;
  final double? mwstSatz;
  final String? zahlungsweg;
  final String? belegordner;
  final String? autoTrigger;
  final bool istAktiv;
  final String? notizen;
  final DateTime? createdAt;

  BuchungsVorlage({
    required this.id,
    required this.userId,
    required this.geschaeftsfallId,
    required this.bezeichnung,
    required this.sollKonto,
    required this.habenKonto,
    this.mwstKonto,
    this.mwstSatz,
    this.zahlungsweg,
    this.belegordner,
    this.autoTrigger,
    this.istAktiv = true,
    this.notizen,
    this.createdAt,
  });

  factory BuchungsVorlage.fromJson(Map<String, dynamic> json) {
    return BuchungsVorlage(
      id: json['id'],
      userId: json['user_id'],
      geschaeftsfallId: json['geschaeftsfall_id'],
      bezeichnung: json['bezeichnung'],
      sollKonto: json['soll_konto'],
      habenKonto: json['haben_konto'],
      mwstKonto: json['mwst_konto'],
      mwstSatz: json['mwst_satz'] != null
          ? double.tryParse(json['mwst_satz'].toString())
          : null,
      zahlungsweg: json['zahlungsweg'],
      belegordner: json['belegordner'],
      autoTrigger: json['auto_trigger'],
      istAktiv: json['ist_aktiv'] ?? true,
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'geschaeftsfall_id': geschaeftsfallId,
      'bezeichnung': bezeichnung,
      'soll_konto': sollKonto,
      'haben_konto': habenKonto,
      'mwst_konto': mwstKonto,
      'mwst_satz': mwstSatz,
      'zahlungsweg': zahlungsweg,
      'belegordner': belegordner,
      'auto_trigger': autoTrigger,
      'ist_aktiv': istAktiv,
      'notizen': notizen,
    };
  }
}
