class Rechnung {
  final String id;
  final String userId;
  final String? rechnungsnummer;
  final String rechnungstyp;
  final String? betriebId;
  final String? heinekenPoNummer;
  final DateTime? heinekenMonat;
  final DateTime rechnungsdatum;
  final DateTime faelligkeitsdatum;
  final double betragNetto;
  final double mwstBetrag;
  final double betragBrutto;
  final String zahlungsstatus;
  final String? versandart;
  final DateTime? versendetAm;
  final DateTime? zahlungEingegangenAm;
  final double? zahlungBetrag;
  final int mahnungStufe;
  final DateTime? letzteMahnungAm;
  final DateTime? erinnerungAm;
  final DateTime? mahnung1Am;
  final DateTime? mahnung2Am;
  final String? pdfUrl;
  final String? qrReferenz;
  /// Optionale, pro Rechnung abweichende Rechnungsadresse (Override/Snapshot).
  /// null = es gilt die Betriebs-Rechnungsadresse. Keys: firma, vorname,
  /// nachname, strasse, nr, plz, ort, email.
  final Map<String, dynamic>? rechnungsadresse;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Rechnung({
    required this.id,
    required this.userId,
    this.rechnungsnummer,
    required this.rechnungstyp,
    this.betriebId,
    this.heinekenPoNummer,
    this.heinekenMonat,
    required this.rechnungsdatum,
    required this.faelligkeitsdatum,
    this.betragNetto = 0,
    this.mwstBetrag = 0,
    this.betragBrutto = 0,
    this.zahlungsstatus = 'offen',
    this.versandart,
    this.versendetAm,
    this.zahlungEingegangenAm,
    this.zahlungBetrag,
    this.mahnungStufe = 0,
    this.letzteMahnungAm,
    this.erinnerungAm,
    this.mahnung1Am,
    this.mahnung2Am,
    this.pdfUrl,
    this.qrReferenz,
    this.rechnungsadresse,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory Rechnung.fromJson(Map<String, dynamic> json) {
    return Rechnung(
      id: json['id'],
      userId: json['user_id'],
      rechnungsnummer: json['rechnungsnummer'],
      rechnungstyp: json['rechnungstyp'],
      betriebId: json['betrieb_id'],
      heinekenPoNummer: json['heineken_po_nummer'],
      heinekenMonat: json['heineken_monat'] != null
          ? DateTime.parse(json['heineken_monat'])
          : null,
      rechnungsdatum: DateTime.parse(json['rechnungsdatum']),
      faelligkeitsdatum: DateTime.parse(json['faelligkeitsdatum']),
      betragNetto: _d(json['betrag_netto'], 0),
      mwstBetrag: _d(json['mwst_betrag'], 0),
      betragBrutto: _d(json['betrag_brutto'], 0),
      zahlungsstatus: json['zahlungsstatus'] ?? 'offen',
      versandart: json['versandart'],
      versendetAm: json['versendet_am'] != null
          ? DateTime.parse(json['versendet_am'])
          : null,
      zahlungEingegangenAm: json['zahlung_eingegangen_am'] != null
          ? DateTime.parse(json['zahlung_eingegangen_am'])
          : null,
      zahlungBetrag: _toDouble(json['zahlung_betrag']),
      mahnungStufe: json['mahnung_stufe'] ?? 0,
      letzteMahnungAm: json['letzte_mahnung_am'] != null
          ? DateTime.parse(json['letzte_mahnung_am'])
          : null,
      erinnerungAm: json['erinnerung_am'] != null
          ? DateTime.parse(json['erinnerung_am'])
          : null,
      mahnung1Am: json['mahnung_1_am'] != null
          ? DateTime.parse(json['mahnung_1_am'])
          : null,
      mahnung2Am: json['mahnung_2_am'] != null
          ? DateTime.parse(json['mahnung_2_am'])
          : null,
      pdfUrl: json['pdf_url'],
      qrReferenz: json['qr_referenz'],
      rechnungsadresse: json['rechnungsadresse'] is Map
          ? Map<String, dynamic>.from(json['rechnungsadresse'])
          : null,
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'rechnungsnummer': rechnungsnummer,
      'rechnungstyp': rechnungstyp,
      'betrieb_id': betriebId,
      'heineken_po_nummer': heinekenPoNummer,
      'heineken_monat': heinekenMonat?.toIso8601String().split('T').first,
      'rechnungsdatum': rechnungsdatum.toIso8601String().split('T').first,
      'faelligkeitsdatum': faelligkeitsdatum.toIso8601String().split('T').first,
      'betrag_netto': betragNetto,
      'mwst_betrag': mwstBetrag,
      'betrag_brutto': betragBrutto,
      'zahlungsstatus': zahlungsstatus,
      'versandart': versandart,
      'versendet_am': versendetAm?.toIso8601String().split('T').first,
      'zahlung_eingegangen_am': zahlungEingegangenAm?.toIso8601String().split('T').first,
      'zahlung_betrag': zahlungBetrag,
      'mahnung_stufe': mahnungStufe,
      'letzte_mahnung_am': letzteMahnungAm?.toIso8601String().split('T').first,
      'erinnerung_am': erinnerungAm?.toIso8601String().split('T').first,
      'mahnung_1_am': mahnung1Am?.toIso8601String().split('T').first,
      'mahnung_2_am': mahnung2Am?.toIso8601String().split('T').first,
      'pdf_url': pdfUrl,
      'qr_referenz': qrReferenz,
      'rechnungsadresse': rechnungsadresse,
      'notizen': notizen,
    };
  }

  /// Erzeugt eine Kopie mit einzeln überschreibbaren Feldern.
  /// Aktuell genutzt, um für die PDF-Generierung ein abweichendes
  /// Fälligkeitsdatum zu setzen, ohne die DB-Rechnung zu verändern.
  Rechnung copyWith({
    DateTime? rechnungsdatum,
    DateTime? faelligkeitsdatum,
  }) {
    return Rechnung(
      id: id,
      userId: userId,
      rechnungsnummer: rechnungsnummer,
      rechnungstyp: rechnungstyp,
      betriebId: betriebId,
      heinekenPoNummer: heinekenPoNummer,
      heinekenMonat: heinekenMonat,
      rechnungsdatum: rechnungsdatum ?? this.rechnungsdatum,
      faelligkeitsdatum: faelligkeitsdatum ?? this.faelligkeitsdatum,
      betragNetto: betragNetto,
      mwstBetrag: mwstBetrag,
      betragBrutto: betragBrutto,
      zahlungsstatus: zahlungsstatus,
      versandart: versandart,
      versendetAm: versendetAm,
      zahlungEingegangenAm: zahlungEingegangenAm,
      zahlungBetrag: zahlungBetrag,
      mahnungStufe: mahnungStufe,
      letzteMahnungAm: letzteMahnungAm,
      erinnerungAm: erinnerungAm,
      mahnung1Am: mahnung1Am,
      mahnung2Am: mahnung2Am,
      pdfUrl: pdfUrl,
      qrReferenz: qrReferenz,
      rechnungsadresse: rechnungsadresse,
      notizen: notizen,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static double _d(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}
