double? _dn(dynamic v) => v == null ? null : double.tryParse(v.toString());

class Steuerjahr {
  final String? id;
  final int jahr;
  final String status; // offen | eingereicht | veranlagt | ermessen
  final DateTime? eingereichtAm;
  final DateTime? veranlagtAm;
  final double? steuerbarerGewinn;
  final double? steuerbaresKapital;
  final double? verlustvortragVerrechnet;
  final double? bundProvisorisch;
  final double? bundDefinitiv;
  final double? kantonProvisorisch;
  final double? kantonDefinitiv;
  final String? notizen;

  const Steuerjahr({
    this.id,
    required this.jahr,
    this.status = 'offen',
    this.eingereichtAm,
    this.veranlagtAm,
    this.steuerbarerGewinn,
    this.steuerbaresKapital,
    this.verlustvortragVerrechnet,
    this.bundProvisorisch,
    this.bundDefinitiv,
    this.kantonProvisorisch,
    this.kantonDefinitiv,
    this.notizen,
  });

  factory Steuerjahr.fromJson(Map<String, dynamic> j) => Steuerjahr(
        id: j['id'],
        jahr: j['jahr'],
        status: j['status'] ?? 'offen',
        eingereichtAm: j['eingereicht_am'] != null
            ? DateTime.parse(j['eingereicht_am'])
            : null,
        veranlagtAm:
            j['veranlagt_am'] != null ? DateTime.parse(j['veranlagt_am']) : null,
        steuerbarerGewinn: _dn(j['steuerbarer_gewinn']),
        steuerbaresKapital: _dn(j['steuerbares_kapital']),
        verlustvortragVerrechnet: _dn(j['verlustvortrag_verrechnet']),
        bundProvisorisch: _dn(j['bund_provisorisch']),
        bundDefinitiv: _dn(j['bund_definitiv']),
        kantonProvisorisch: _dn(j['kanton_provisorisch']),
        kantonDefinitiv: _dn(j['kanton_definitiv']),
        notizen: j['notizen'],
      );

  /// Sentinel: unterscheidet «Feld nicht angegeben» von «ausdrücklich auf
  /// null setzen». Ohne ihn liesse sich z.B. `bundDefinitiv` nie wieder
  /// leeren, weil `null` bei `??` immer den alten Wert durchreicht.
  static const _unset = Object();

  Steuerjahr copyWith({
    Object? id = _unset,
    int? jahr,
    String? status,
    Object? eingereichtAm = _unset,
    Object? veranlagtAm = _unset,
    Object? steuerbarerGewinn = _unset,
    Object? steuerbaresKapital = _unset,
    Object? verlustvortragVerrechnet = _unset,
    Object? bundProvisorisch = _unset,
    Object? bundDefinitiv = _unset,
    Object? kantonProvisorisch = _unset,
    Object? kantonDefinitiv = _unset,
    Object? notizen = _unset,
  }) =>
      Steuerjahr(
        id: identical(id, _unset) ? this.id : id as String?,
        jahr: jahr ?? this.jahr,
        status: status ?? this.status,
        eingereichtAm: identical(eingereichtAm, _unset)
            ? this.eingereichtAm
            : eingereichtAm as DateTime?,
        veranlagtAm: identical(veranlagtAm, _unset)
            ? this.veranlagtAm
            : veranlagtAm as DateTime?,
        steuerbarerGewinn: identical(steuerbarerGewinn, _unset)
            ? this.steuerbarerGewinn
            : steuerbarerGewinn as double?,
        steuerbaresKapital: identical(steuerbaresKapital, _unset)
            ? this.steuerbaresKapital
            : steuerbaresKapital as double?,
        verlustvortragVerrechnet: identical(verlustvortragVerrechnet, _unset)
            ? this.verlustvortragVerrechnet
            : verlustvortragVerrechnet as double?,
        bundProvisorisch: identical(bundProvisorisch, _unset)
            ? this.bundProvisorisch
            : bundProvisorisch as double?,
        bundDefinitiv: identical(bundDefinitiv, _unset)
            ? this.bundDefinitiv
            : bundDefinitiv as double?,
        kantonProvisorisch: identical(kantonProvisorisch, _unset)
            ? this.kantonProvisorisch
            : kantonProvisorisch as double?,
        kantonDefinitiv: identical(kantonDefinitiv, _unset)
            ? this.kantonDefinitiv
            : kantonDefinitiv as double?,
        notizen: identical(notizen, _unset) ? this.notizen : notizen as String?,
      );

  /// Ohne `id`/`user_id`: die ID vergibt die DB, `user_id` setzt das
  /// Repository — beides gehört nicht in die Nutzlast.
  Map<String, dynamic> toJson() => {
        'jahr': jahr,
        'status': status,
        'eingereicht_am': eingereichtAm?.toIso8601String().split('T').first,
        'veranlagt_am': veranlagtAm?.toIso8601String().split('T').first,
        'steuerbarer_gewinn': steuerbarerGewinn,
        'steuerbares_kapital': steuerbaresKapital,
        'verlustvortrag_verrechnet': verlustvortragVerrechnet,
        'bund_provisorisch': bundProvisorisch,
        'bund_definitiv': bundDefinitiv,
        'kanton_provisorisch': kantonProvisorisch,
        'kanton_definitiv': kantonDefinitiv,
        'notizen': notizen,
      };

  static const statusLabels = {
    'offen': 'offen',
    'eingereicht': 'eingereicht',
    'veranlagt': 'veranlagt',
    'ermessen': 'Ermessen',
  };
}
