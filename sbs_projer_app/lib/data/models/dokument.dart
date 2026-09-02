double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

class Dokument {
  final String id;
  final String userId;
  final String bereich;
  final String typ;
  final String? kategorie;
  final int? jahr;
  final DateTime? dokumentDatum;
  final double? betrag;
  final String? referenz;
  final String titel;
  final String? notizen;
  final String dateiname;
  final String dateityp;
  final int? groesseBytes;
  final int? seiten;
  final String storagePfad;
  final String? buchungId;
  final DateTime? createdAt;

  const Dokument({
    required this.id,
    required this.userId,
    required this.bereich,
    required this.typ,
    this.kategorie,
    this.jahr,
    this.dokumentDatum,
    this.betrag,
    this.referenz,
    required this.titel,
    this.notizen,
    required this.dateiname,
    required this.dateityp,
    this.groesseBytes,
    this.seiten,
    required this.storagePfad,
    this.buchungId,
    this.createdAt,
  });

  factory Dokument.fromJson(Map<String, dynamic> j) => Dokument(
        id: j['id'],
        userId: j['user_id'],
        bereich: j['bereich'],
        typ: j['typ'],
        kategorie: j['kategorie'],
        jahr: j['jahr'],
        dokumentDatum: j['dokument_datum'] != null
            ? DateTime.parse(j['dokument_datum'])
            : null,
        betrag: j['betrag'] != null ? _d(j['betrag']) : null,
        referenz: j['referenz'],
        titel: j['titel'],
        notizen: j['notizen'],
        dateiname: j['dateiname'],
        dateityp: j['dateityp'],
        groesseBytes: j['groesse_bytes'],
        seiten: j['seiten'],
        storagePfad: j['storage_pfad'],
        buchungId: j['buchung_id'],
        createdAt:
            j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
      );

  bool get istPdf => dateityp == 'application/pdf';
}
