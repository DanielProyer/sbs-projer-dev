class Bierleitung {
  final String id;
  final String userId;
  final String anlageId;
  final int leitungsNummer;
  final String? biersorte;
  final String? hahnTyp;
  final double? niederdruckBar;
  final bool hatFobStop;
  final bool istGekoppelt;

  Bierleitung({
    required this.id,
    required this.userId,
    required this.anlageId,
    required this.leitungsNummer,
    this.biersorte,
    this.hahnTyp,
    this.niederdruckBar,
    this.hatFobStop = false,
    this.istGekoppelt = false,
  });

  factory Bierleitung.fromJson(Map<String, dynamic> json) {
    return Bierleitung(
      id: json['id'],
      userId: json['user_id'],
      anlageId: json['anlage_id'],
      leitungsNummer: json['leitungs_nummer'],
      biersorte: json['biersorte'],
      hahnTyp: json['hahn_typ'],
      niederdruckBar: json['niederdruck_bar'] != null
          ? double.tryParse(json['niederdruck_bar'].toString())
          : null,
      hatFobStop: json['hat_fob_stop'] ?? false,
      istGekoppelt: json['ist_gekoppelt'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'anlage_id': anlageId,
      'leitungs_nummer': leitungsNummer,
      'biersorte': biersorte,
      'hahn_typ': hahnTyp,
      'niederdruck_bar': niederdruckBar,
      'hat_fob_stop': hatFobStop,
      'ist_gekoppelt': istGekoppelt,
    };
  }
}
