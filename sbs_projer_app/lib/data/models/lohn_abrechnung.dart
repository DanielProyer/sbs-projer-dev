class LohnAbrechnung {
  final String id;
  final String userId;
  final int jahr;
  final int monat;
  final DateTime datum;
  final double bruttolohn;
  // AN-Abzüge
  final double ahvIvEoAn;
  final double alvAn;
  final double nbuAn;
  final double bvgAn;
  final double ktgAn;
  final double nettolohn;
  // AG-Beiträge
  final double ahvIvEoAg;
  final double alvAg;
  final double buAg;
  final double fakAg;
  final double bvgAg;
  final double ktgAg;
  // Status
  final bool istGebucht;
  final bool istAusbezahlt;
  final DateTime? createdAt;

  LohnAbrechnung({
    required this.id,
    required this.userId,
    required this.jahr,
    required this.monat,
    required this.datum,
    required this.bruttolohn,
    this.ahvIvEoAn = 0,
    this.alvAn = 0,
    this.nbuAn = 0,
    this.bvgAn = 0,
    this.ktgAn = 0,
    this.nettolohn = 0,
    this.ahvIvEoAg = 0,
    this.alvAg = 0,
    this.buAg = 0,
    this.fakAg = 0,
    this.bvgAg = 0,
    this.ktgAg = 0,
    this.istGebucht = false,
    this.istAusbezahlt = false,
    this.createdAt,
  });

  double get totalAnAbzuege => ahvIvEoAn + alvAn + nbuAn + bvgAn + ktgAn;

  double get totalAgBeitraege =>
      ahvIvEoAg + alvAg + buAg + fakAg + bvgAg + ktgAg;

  String get datumFormatiert =>
      '${datum.day.toString().padLeft(2, '0')}.${datum.month.toString().padLeft(2, '0')}.${datum.year}';

  factory LohnAbrechnung.fromJson(Map<String, dynamic> json) {
    return LohnAbrechnung(
      id: json['id'],
      userId: json['user_id'],
      jahr: json['jahr'],
      monat: json['monat'],
      datum: DateTime.parse(json['datum']),
      bruttolohn: _d(json['bruttolohn']),
      ahvIvEoAn: _d(json['ahv_iv_eo_an']),
      alvAn: _d(json['alv_an']),
      nbuAn: _d(json['nbu_an']),
      bvgAn: _d(json['bvg_an']),
      ktgAn: _d(json['ktg_an']),
      nettolohn: _d(json['nettolohn']),
      ahvIvEoAg: _d(json['ahv_iv_eo_ag']),
      alvAg: _d(json['alv_ag']),
      buAg: _d(json['bu_ag']),
      fakAg: _d(json['fak_ag']),
      bvgAg: _d(json['bvg_ag']),
      ktgAg: _d(json['ktg_ag']),
      istGebucht: json['ist_gebucht'] ?? false,
      istAusbezahlt: json['ist_ausbezahlt'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'jahr': jahr,
      'monat': monat,
      'datum': datum.toIso8601String().split('T').first,
      'bruttolohn': bruttolohn,
      'ahv_iv_eo_an': ahvIvEoAn,
      'alv_an': alvAn,
      'nbu_an': nbuAn,
      'bvg_an': bvgAn,
      'ktg_an': ktgAn,
      'nettolohn': nettolohn,
      'ahv_iv_eo_ag': ahvIvEoAg,
      'alv_ag': alvAg,
      'bu_ag': buAg,
      'fak_ag': fakAg,
      'bvg_ag': bvgAg,
      'ktg_ag': ktgAg,
      'ist_gebucht': istGebucht,
      'ist_ausbezahlt': istAusbezahlt,
    };
  }

  static double _d(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }
}
