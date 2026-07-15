class CamtPrueflisteEintrag {
  final String? id;
  final String txKey;
  final DateTime bookingDatum;
  final double betrag;
  final bool istGutschrift;
  final String? parteiName;

  /// IBAN der Gegenpartei aus camt — Vorbefüllung für `camt_regel.match_iban`.
  final String? parteiIban;

  /// AcctSvcrRef — wird beim Buchen aus der Prüfliste zur Belegnummer.
  final String? belegRef;

  final String? referenz;
  final String kategorie;
  final Map<String, dynamic>? vorschlag;
  final String status;
  final String? fehlertext;

  CamtPrueflisteEintrag({
    this.id,
    required this.txKey,
    required this.bookingDatum,
    required this.betrag,
    required this.istGutschrift,
    this.parteiName,
    this.parteiIban,
    this.belegRef,
    this.referenz,
    required this.kategorie,
    this.vorschlag,
    this.status = 'offen',
    this.fehlertext,
  });

  factory CamtPrueflisteEintrag.fromJson(Map<String, dynamic> j) =>
      CamtPrueflisteEintrag(
        id: j['id'],
        txKey: j['tx_key'],
        bookingDatum: DateTime.parse(j['booking_datum']),
        betrag: (j['betrag'] as num).toDouble(),
        istGutschrift: j['ist_gutschrift'],
        parteiName: j['partei_name'],
        parteiIban: j['partei_iban'],
        belegRef: j['beleg_ref'],
        referenz: j['referenz'],
        kategorie: j['kategorie'],
        vorschlag: j['vorschlag_json'] != null
            ? Map<String, dynamic>.from(j['vorschlag_json'])
            : null,
        status: j['status'],
        fehlertext: j['fehlertext'],
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'tx_key': txKey,
        'booking_datum': bookingDatum.toIso8601String().split('T').first,
        'betrag': betrag,
        'ist_gutschrift': istGutschrift,
        'partei_name': parteiName,
        'partei_iban': parteiIban,
        'beleg_ref': belegRef,
        'referenz': referenz,
        'kategorie': kategorie,
        'vorschlag_json': vorschlag,
        'status': status,
        'fehlertext': fehlertext,
      };
}
